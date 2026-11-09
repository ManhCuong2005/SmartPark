-- Migration 003: Fix slot availability for advance booking, allow flexible late check-in, and auto-cancel no-shows after 1 hour
begin;
set local search_path=public,extensions;

-- 1. Hàm tự động dọn dẹp các vé No-show (quá hẹn 1 tiếng không đến check-in)
create or replace function public.cancel_no_shows(p_lot_id uuid default null)
returns integer language plpgsql security definer set search_path='' as $$
declare
 v_count integer;
begin
 update public.bookings
 set status = 'cancelled', version = version + 1
 where status = 'confirmed'
   and now() >= starts_at + interval '1 hour'
   and (p_lot_id is null or lot_id = p_lot_id);
   
 get diagnostics v_count = row_count;
 return v_count;
end $$;

-- 2. Tối ưu hàm slot_availability: Chỉ tính bận nếu khoảng thời gian thực tế bị trùng lắp
create or replace function public.slot_availability(p_lot_id uuid, p_start timestamptz, p_end timestamptz)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_end<=p_start or p_end-p_start>interval '7 days' then raise exception 'INVALID_TIME'; end if;
 if not exists(select 1 from public.parking_lots where id=p_lot_id and (enabled or public.works_lot(id))) then
   raise exception 'LOT_UNAVAILABLE'; end if;

 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'code',s.code,'lot_id',s.lot_id,
  'enabled',s.enabled,'occupied',not s.enabled or exists(
    select 1 from public.bookings b where b.slot_id=s.id
    and (
      (b.status='confirmed' and now() < b.starts_at + interval '1 hour' and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_start, p_end, '[)'))
      or
      (b.status='parked' and tstzrange(b.starts_at, greatest(b.ends_at, now()), '[)') && tstzrange(p_start, p_end, '[)'))
    )
  ))
  order by s.code) from public.parking_slots s where s.lot_id=p_lot_id),'[]');
end $$;

-- 2. Cập nhật hàm apply_operation:
-- - Nhánh booking.create: Cho phép đặt trước dù hiện tại ô đang có xe đỗ, miễn là không trùng khung giờ [starts_at, ends_at)
-- - Nhánh staff.check_in: Cho phép khách đến muộn sau ends_at check-in (tự động gia hạn ends_at nếu còn trống)
create or replace function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); previous public.operation_receipts; result jsonb;
 b public.bookings; v public.vehicles; s public.parking_slots; l public.parking_lots;
 item_id uuid; observed timestamptz; rate integer; minutes integer; fee integer;
 new_end timestamptz;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 perform public.cancel_no_shows();
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
   if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
   return previous.result;
 end if;
 if p_kind='booking.create' then
   item_id:=(p_payload->>'id')::uuid;
   select * into v from public.vehicles where id=(p_payload->>'vehicle_id')::uuid and user_id=actor and not deleted;
   if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
   select * into s from public.parking_slots where id=(p_payload->>'slot_id')::uuid for update;
   if not found or not s.enabled then raise exception 'SLOT_UNAVAILABLE'; end if;
   select * into l from public.parking_lots where id=s.lot_id;
   if not l.enabled then raise exception 'LOT_UNAVAILABLE'; end if;
   if (p_payload->>'starts_at')::timestamptz < now()-interval '5 minutes'
     or (p_payload->>'ends_at')::timestamptz <= (p_payload->>'starts_at')::timestamptz
     or (p_payload->>'ends_at')::timestamptz-(p_payload->>'starts_at')::timestamptz>interval '7 days'
     then raise exception 'INVALID_TIME'; end if;
   -- Kiểm tra xem ô đỗ có đang có xe đỗ trùng với khung giờ yêu cầu hay không
   if exists(
     select 1 from public.bookings cur
     where cur.slot_id=s.id and cur.status='parked'
     and tstzrange(cur.starts_at, greatest(cur.ends_at, now()), '[)') && tstzrange((p_payload->>'starts_at')::timestamptz, (p_payload->>'ends_at')::timestamptz, '[)')
   ) then raise exception 'SLOT_UNAVAILABLE'; end if;
   rate:=case when v.kind='motorcycle' then l.motorcycle_rate else l.car_rate end;
   insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,hourly_rate,free_minutes)
   values(item_id,actor,v.id,l.id,s.id,v.plate,(p_payload->>'starts_at')::timestamptz,
     (p_payload->>'ends_at')::timestamptz,rate,l.free_minutes) returning * into b;
   insert into public.notifications(user_id,title,body) values(actor,'Đặt chỗ thành công',l.name||' · '||s.code);
   result:=to_jsonb(b);
 elsif p_kind in ('booking.cancel','staff.check_in','staff.check_out') then
   select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid for update;
   if not found then raise exception 'TICKET_NOT_FOUND'; end if;
   if p_kind='booking.cancel' then
     if b.customer_id<>actor and not public.owns_lot(b.lot_id) and not (public.works_lot(b.lot_id) and now() >= b.starts_at + interval '1 hour') then
       raise exception 'FORBIDDEN' using errcode='42501';
     end if;
   else
     if not public.works_lot(b.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
     if p_payload->>'qr_token' is distinct from b.qr_token then raise exception 'INVALID_QR'; end if;
   end if;
   if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
   if p_kind='booking.cancel' then
     if b.status<>'confirmed' or (b.customer_id=actor and now()>=b.starts_at) then raise exception 'INVALID_STATE'; end if;
     update public.bookings set status='cancelled',version=version+1 where id=b.id returning * into b;
   else
     observed:=(p_payload->>'occurred_at')::timestamptz;
     if observed is null or observed>now()+interval '5 minutes' or observed<now()-interval '24 hours'
       then raise exception 'CLOCK_REVIEW_REQUIRED'; end if;
     if regexp_replace(upper(p_payload->>'plate'),'[^A-Z0-9]','','g') is distinct from b.plate then raise exception 'PLATE_MISMATCH'; end if;
     perform 1 from public.parking_slots where id=b.slot_id for update;
     if p_kind='staff.check_in' then
       -- Cho phép check-in sớm tối đa 15 phút, và cho phép trễ tối đa 1 tiếng kể từ starts_at
       if b.status<>'confirmed' or observed<b.starts_at-interval '15 minutes' or observed>b.starts_at+interval '1 hour' then
         raise exception 'INVALID_STATE';
       end if;
       if not exists(select 1 from public.parking_slots where id=b.slot_id and enabled) then raise exception 'SLOT_UNAVAILABLE'; end if;
       
       -- Nếu khách đến trễ sau ends_at nhưng trong vòng 1 tiếng, tự động gia hạn ends_at thêm 1 giờ
       if observed >= b.ends_at then
         new_end := observed + interval '1 hour';
         -- Kiểm tra không đè lên đặt chỗ tiếp theo của người khác
         if exists(
           select 1 from public.bookings other
           where other.slot_id = b.slot_id and other.id <> b.id
           and other.status in ('confirmed', 'parked')
           and tstzrange(other.starts_at, other.ends_at, '[)') && tstzrange(observed, new_end, '[)')
         ) then
           raise exception 'SLOT_UNAVAILABLE';
         end if;
         update public.bookings set status='parked', checked_in_at=observed, ends_at=new_end, version=version+1 where id=b.id returning * into b;
       else
         update public.bookings set status='parked', checked_in_at=observed, version=version+1 where id=b.id returning * into b;
       end if;
     else
       if b.status<>'parked' or observed<b.checked_in_at then raise exception 'INVALID_STATE'; end if;
       minutes:=ceil(extract(epoch from (observed-b.checked_in_at))/60);
       fee:=case when minutes<=b.free_minutes then 0 else ceil(minutes/60.0)::integer*b.hourly_rate end;
       update public.bookings set status='completed',checked_out_at=observed,amount=fee,version=version+1 where id=b.id returning * into b;
       insert into public.payments(booking_id,amount,received_by,paid_at) values(b.id,fee,actor,observed);
     end if;
     insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at)
       values(p_operation_id,b.id,actor,substring(p_kind from 7),b.plate,observed);
   end if;
   insert into public.notifications(user_id,title,body) values(b.customer_id,
      case b.status when 'cancelled' then 'Đã hủy đặt chỗ' when 'parked' then 'Xe đã vào bãi' else 'Xe đã ra bãi' end,b.plate);
   result:=to_jsonb(b);
 elsif p_kind='vehicle.save' then
   item_id:=(p_payload->>'id')::uuid;
   perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
   select * into v from public.vehicles where id=item_id for update;
   if found and v.user_id<>actor then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if found and v.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
   if found and exists(select 1 from public.bookings where vehicle_id=v.id and status in ('confirmed','parked'))
     and (v.plate<>p_payload->>'plate' or v.kind<>p_payload->>'kind' or coalesce((p_payload->>'deleted')::boolean,false)) then raise exception 'VEHICLE_IN_USE'; end if;
   if coalesce((p_payload->>'is_default')::boolean,false) then
     update public.vehicles set is_default=false,version=version+1 where user_id=actor and is_default and id<>item_id;
   end if;
   insert into public.vehicles(id,user_id,label,plate,kind,is_default,deleted)
   values(item_id,actor,p_payload->>'label',p_payload->>'plate',p_payload->>'kind',
     coalesce((p_payload->>'is_default')::boolean,false),coalesce((p_payload->>'deleted')::boolean,false))
   on conflict(id) do update set label=excluded.label,plate=excluded.plate,kind=excluded.kind,
     is_default=excluded.is_default,deleted=excluded.deleted,version=vehicles.version+1 returning * into v;
   result:=to_jsonb(v);
 elsif p_kind='favorite.set' then
   if not exists(select 1 from public.parking_lots where id=(p_payload->>'lot_id')::uuid and enabled) then raise exception 'LOT_UNAVAILABLE'; end if;
   if (p_payload->>'enabled')::boolean then
     insert into public.favorites(user_id,lot_id) values(actor,(p_payload->>'lot_id')::uuid) on conflict do nothing;
   else delete from public.favorites where user_id=actor and lot_id=(p_payload->>'lot_id')::uuid; end if;
   result:=jsonb_build_object('ok',true);
 elsif p_kind='profile.update' then
   if length(trim(coalesce(p_payload->>'name','')))=0 then raise exception 'INVALID_NAME'; end if;
   update public.profiles set name=left(trim(p_payload->>'name'),100),phone=left(coalesce(p_payload->>'phone',''),30) where id=actor;
   result:=jsonb_build_object('ok',true);
 elsif p_kind='notifications.read' then
   update public.notifications set read=true where user_id=actor;
   result:=jsonb_build_object('ok',true);
 else raise exception 'UNKNOWN_OPERATION'; end if;
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values(actor,p_operation_id,p_kind,p_payload,result);
 return result;
end $$;

grant execute on function public.cancel_no_shows(uuid) to authenticated;
grant execute on function public.slot_availability(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.apply_operation(uuid,text,jsonb) to authenticated;
commit;

