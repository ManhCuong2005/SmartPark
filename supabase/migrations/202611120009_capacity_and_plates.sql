begin;
alter table public.parking_lots add column car_capacity integer not null default 0 check(car_capacity between 0 and 100000),
 add column motorcycle_capacity integer not null default 0 check(motorcycle_capacity between 0 and 100000),
 add column availability_revision bigint not null default 1;
-- Owner-approved conversion: the old enabled capacity is available to EACH kind.
update public.parking_lots l set car_capacity=(select count(*) from public.parking_slots s where s.lot_id=l.id and s.enabled),
 motorcycle_capacity=(select count(*) from public.parking_slots s where s.lot_id=l.id and s.enabled);
alter table public.bookings add column vehicle_kind text check(vehicle_kind in ('car','motorcycle'));
update public.bookings b set vehicle_kind=v.kind from public.vehicles v where v.id=b.vehicle_id;
do $$ begin
 if exists(select 1 from public.bookings where status in ('confirmed','parked') and
  (vehicle_kind is null or plate is null or plate !~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$')) then
  raise exception 'LEGACY_TICKETS_REQUIRE_REVIEW: repair missing vehicle kind/plate from verified source before migration';
 end if;
end $$;
alter table public.bookings alter column slot_id drop not null;
-- Slot IDs and QR tokens on historical rows remain archival data only.
drop trigger smartpark_slot_availability on public.bookings;
create function smartpark_private.signal_capacity() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.parking_lots set availability_revision=availability_revision+1 where id=coalesce(new.lot_id,old.lot_id);
 return coalesce(new,old);
end $$;
create trigger smartpark_capacity after insert or update or delete on public.bookings
 for each row execute function smartpark_private.signal_capacity();

create function smartpark_private.plate(p_value text) returns text language sql immutable set search_path='' as $$
 select regexp_replace(upper(coalesce(p_value,'')),'[^A-Z0-9]','','g')
$$;
create function smartpark_private.capacity_used(p_lot uuid,p_kind text,p_start timestamptz,p_end timestamptz,p_exclude uuid default null)
returns integer language sql stable set search_path='' as $$
 with periods as (
  select greatest(starts_at,p_start) a,least(case when status='parked' and ends_at<=now() then 'infinity'::timestamptz else ends_at end,p_end) z
  from public.bookings where lot_id=p_lot and vehicle_kind=p_kind and id is distinct from p_exclude
   and status in ('confirmed','parked') and starts_at<p_end
   and (ends_at>greatest(p_start,now()) or status='parked')
 ), edges as (select a t,1 d from periods where z>a union all select z,-1 from periods where z>a),
 counts as (select sum(sum(d)) over(order by t) n from edges group by t)
 select coalesce(max(n),0)::integer from counts
$$;
create function smartpark_private.plate_busy(p_plate text,p_start timestamptz,p_end timestamptz,p_exclude uuid default null)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.bookings b where b.plate=p_plate and b.id is distinct from p_exclude
  and b.status in ('confirmed','parked') and b.starts_at<p_end
  and (b.ends_at>greatest(p_start,now()) or (b.status='parked' and b.ends_at<=now())))
$$;

create or replace function smartpark_private.expire_no_shows(p_scope uuid default null,p_slot uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare l record; b public.bookings;
begin
 for l in select lot.id,lot.name from public.parking_lots lot where exists(
  select 1 from public.bookings t where t.lot_id=lot.id and t.status in ('confirmed','expired')
   and t.checked_in_at is null and t.ends_at<=now() and (p_slot is null or t.slot_id=p_slot)
   and (p_scope is null or t.customer_id=p_scope or lot.owner_id=p_scope or exists(
    select 1 from public.lot_staff s where s.lot_id=lot.id and s.user_id=p_scope and s.active)))
  order by lot.id for update of lot skip locked
 loop
  for b in select t.* from public.bookings t where t.lot_id=l.id and t.status in ('confirmed','expired')
   and t.checked_in_at is null and t.ends_at<=now() and (p_slot is null or t.slot_id=p_slot)
   and not exists(select 1 from public.parking_events e where e.booking_id=t.id)
   and not exists(select 1 from public.payments p where p.booking_id=t.id)
   and (p_scope is null or t.customer_id=p_scope or exists(select 1 from public.parking_lots x where x.id=t.lot_id and x.owner_id=p_scope)
    or exists(select 1 from public.lot_staff s where s.lot_id=t.lot_id and s.user_id=p_scope and s.active))
   for update of t skip locked
  loop
   update public.operation_receipts set result=jsonb_build_object('id',b.id,'status','expired','deleted',true)
    where kind='booking.create' and result->>'id'=b.id::text;
   update public.notifications set booking_id=null where booking_id=b.id;
   insert into public.notifications(user_id,category,dedupe_key,title,body)
    values(b.customer_id,'booking_expired','booking_expired:'||b.id,'Vé đã hết hạn',l.name||': vé chưa check-in đã bị xóa khi đến giờ ra dự kiến.')
    on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
   delete from public.bookings where id=b.id;
  end loop;
 end loop;
end $$;

create or replace function public.booking_availability(p_lot_id uuid,p_start timestamptz,p_end timestamptz,p_vehicle_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare l public.parking_lots; v public.vehicles; counts jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '7 days' then raise exception 'INVALID_TIME'; end if;
 select * into l from public.parking_lots where id=p_lot_id and (enabled or public.works_lot(id));
 if not found then raise exception 'LOT_UNAVAILABLE'; end if;
 if p_vehicle_id is not null then
  select * into v from public.vehicles where id=p_vehicle_id and user_id=auth.uid() and not deleted;
  if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
 end if;
 select jsonb_agg(jsonb_build_object('kind',k.kind,'capacity',k.capacity,'remaining',
  greatest(0,k.capacity-smartpark_private.capacity_used(l.id,k.kind,p_start,p_end)))) into counts
  from (values ('car',l.car_capacity),('motorcycle',l.motorcycle_capacity)) k(kind,capacity);
 return jsonb_build_object('capacities',counts,'vehicle_conflict',case when v.id is not null and
  smartpark_private.plate_busy(v.plate,p_start,p_end) then jsonb_build_object('plate',v.plate) else null end);
end $$;

drop function public.manage_lot(uuid,text,text,boolean,integer,double precision,double precision,integer);
create function public.manage_lot(p_id uuid,p_name text,p_area text,p_enabled boolean,p_car_capacity integer,p_motorcycle_capacity integer,
 p_latitude double precision default null,p_longitude double precision default null,p_expected_version integer default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare l public.parking_lots; needed integer; k record;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and role='owner') then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_car_capacity is null or p_motorcycle_capacity is null or p_car_capacity not between 0 and 100000 or p_motorcycle_capacity not between 0 and 100000 then raise exception 'INVALID_CAPACITY'; end if;
 select * into l from public.parking_lots where id=p_id for update;
 if found then
  if l.owner_id<>auth.uid() then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if l.version is distinct from p_expected_version then raise exception 'VERSION_CONFLICT'; end if;
  for k in select * from (values ('car',p_car_capacity),('motorcycle',p_motorcycle_capacity)) t(kind,capacity) loop
   needed:=smartpark_private.capacity_used(p_id,k.kind,now(),'infinity');
   if k.capacity<needed then raise exception 'CAPACITY_CONFLICT' using detail=k.kind||': cần tối thiểu '||needed||' chỗ cho vé còn hiệu lực'; end if;
  end loop;
  update public.parking_lots set name=p_name,area=p_area,enabled=p_enabled,car_capacity=p_car_capacity,motorcycle_capacity=p_motorcycle_capacity,
   latitude=p_latitude,longitude=p_longitude,version=version+1 where id=p_id;
 else
  insert into public.parking_lots(id,owner_id,name,area,enabled,car_capacity,motorcycle_capacity,latitude,longitude)
   values(p_id,auth.uid(),p_name,p_area,p_enabled,p_car_capacity,p_motorcycle_capacity,p_latitude,p_longitude);
 end if;
 return p_id;
end $$;

create function public.resolve_plate(p_lot_id uuid,p_plate text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b public.bookings; normalized text:=smartpark_private.plate(p_plate); matches integer;
begin
 if not public.works_lot(p_lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if normalized !~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$' then raise exception 'INVALID_PLATE'; end if;
 perform public.refresh_booking_deadlines();
 select count(*) into matches from public.bookings where lot_id=p_lot_id and plate=normalized and status='parked';
 if matches>1 then raise exception 'PLATE_AMBIGUOUS'; end if;
 if matches=0 and (select count(*) from public.bookings where lot_id=p_lot_id and plate=normalized and status='confirmed'
  and starts_at<=now()+interval '15 minutes' and ends_at>now())>1 then raise exception 'PLATE_AMBIGUOUS'; end if;
 select * into b from public.bookings where lot_id=p_lot_id and plate=normalized
  and (status='parked' or (status='confirmed' and starts_at<=now()+interval '15 minutes' and ends_at>now()))
  order by (status='parked') desc,starts_at,id limit 1;
 if not found then raise exception 'VALID_TICKET_REQUIRED'; end if;
 return to_jsonb(b)-'qr_token';
end $$;

create or replace function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; b public.bookings; v public.vehicles; l public.parking_lots;
 result jsonb; lot_id uuid; normalized text; from_at timestamptz; until_at timestamptz; observed timestamptz; cap integer; fee integer;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind='staff.lookup' then return public.resolve_plate((p_payload->>'lot_id')::uuid,p_payload->>'plate'); end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 if p_kind not in ('booking.create','booking.cancel','booking.extend','staff.check_in','staff.check_out') then
  return public.apply_operation_core(p_operation_id,p_kind,p_payload);
 end if;
 -- Vehicle edits already serialize on this actor lock. Always lock plate before lot before ticket.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
 if p_kind='booking.create' then
  select * into v from public.vehicles where id=(p_payload->>'vehicle_id')::uuid and user_id=actor and not deleted;
  if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
  lot_id:=(p_payload->>'lot_id')::uuid; normalized:=v.plate;
 else
  select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  if (p_kind='booking.extend' and b.customer_id<>actor) or
   (p_kind='booking.cancel' and b.customer_id<>actor and not public.owns_lot(b.lot_id)) or
   (p_kind like 'staff.%' and not public.works_lot(b.lot_id)) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  lot_id:=b.lot_id; normalized:=b.plate;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(normalized,3));
 select * into l from public.parking_lots where id=lot_id for update;
 if not found then raise exception 'LOT_UNAVAILABLE'; end if;
 if p_kind='booking.create' then
  if not l.enabled then raise exception 'LOT_UNAVAILABLE'; end if;
  from_at:=(p_payload->>'starts_at')::timestamptz; until_at:=(p_payload->>'ends_at')::timestamptz;
  if from_at is null or until_at is null or from_at<now()-interval '5 minutes' or until_at<=now() or until_at<=from_at or until_at-from_at>interval '7 days' then raise exception 'INVALID_TIME'; end if;
  if smartpark_private.plate_busy(normalized,from_at,until_at) then raise exception 'VEHICLE_TIME_CONFLICT' using errcode='23P01'; end if;
  cap:=case v.kind when 'car' then l.car_capacity else l.motorcycle_capacity end;
  if smartpark_private.capacity_used(l.id,v.kind,from_at,until_at)>=cap then raise exception 'CAPACITY_FULL'; end if;
  insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes)
   values((p_payload->>'id')::uuid,actor,v.id,l.id,v.plate,v.kind,from_at,until_at,
    case v.kind when 'car' then l.car_rate else l.motorcycle_rate end,0) returning * into b;
 else
  select * into b from public.bookings where id=b.id for update;
  if p_kind like 'staff.%' and smartpark_private.plate(p_payload->>'plate') is distinct from b.plate then raise exception 'PLATE_MISMATCH'; end if;
  -- Different scan/command IDs are also harmless after a transition, even if the client version is stale.
  if (p_kind='staff.check_in' and b.status='parked') or (p_kind='staff.check_out' and b.status='completed') then
   result:=to_jsonb(b)-'qr_token';
  else
   if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
   if p_kind='booking.cancel' then
    if b.status<>'confirmed' or (b.customer_id=actor and now()>=b.starts_at) then raise exception 'INVALID_STATE'; end if;
    update public.bookings set status='cancelled',version=version+1 where id=b.id returning * into b;
   elsif p_kind='booking.extend' then
    if b.status<>'parked' then raise exception 'INVALID_STATE'; end if;
    until_at:=(p_payload->>'ends_at')::timestamptz;
    if until_at is null or until_at<=greatest(now(),b.ends_at) or until_at>now()+interval '7 days' then raise exception 'INVALID_TIME'; end if;
    cap:=case b.vehicle_kind when 'car' then l.car_capacity else l.motorcycle_capacity end;
    if smartpark_private.capacity_used(l.id,b.vehicle_kind,greatest(now(),b.ends_at),until_at,b.id)>=cap then raise exception 'CAPACITY_FULL'; end if;
    if smartpark_private.plate_busy(b.plate,greatest(now(),b.ends_at),until_at,b.id) then raise exception 'VEHICLE_TIME_CONFLICT'; end if;
    update public.bookings set ends_at=until_at,version=version+1 where id=b.id returning * into b;
   else
    observed:=(p_payload->>'occurred_at')::timestamptz;
    if observed is null or observed>now()+interval '5 minutes' or observed<now()-interval '24 hours' then raise exception 'CLOCK_REVIEW_REQUIRED'; end if;
    if p_kind='staff.check_in' then
     if b.status<>'confirmed' or now()<b.starts_at-interval '15 minutes' or now()>=b.ends_at
      or observed<b.starts_at-interval '15 minutes' or observed>=b.ends_at then raise exception 'VALID_TICKET_REQUIRED'; end if;
     cap:=case b.vehicle_kind when 'car' then l.car_capacity else l.motorcycle_capacity end;
     if (select count(*) from public.bookings t where t.lot_id=l.id and t.vehicle_kind=b.vehicle_kind and t.status='parked')>=cap
      or smartpark_private.capacity_used(l.id,b.vehicle_kind,least(now(),observed,b.starts_at),b.ends_at,b.id)>=cap then raise exception 'CAPACITY_FULL'; end if;
     if exists(select 1 from public.bookings where plate=b.plate and status='parked' and id<>b.id) then raise exception 'VEHICLE_TIME_CONFLICT'; end if;
     update public.bookings set status='parked',checked_in_at=observed,starts_at=least(starts_at,observed),version=version+1 where id=b.id returning * into b;
    else
     if b.status<>'parked' or observed<b.checked_in_at then raise exception 'INVALID_STATE'; end if;
     fee:=smartpark_private.parking_fee(b.checked_in_at,observed,b.hourly_rate);
     update public.bookings set status='completed',checked_out_at=observed,amount=fee,version=version+1 where id=b.id returning * into b;
     insert into public.payments(booking_id,amount,received_by,paid_at) values(b.id,fee,actor,observed);
    end if;
    insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at)
     values(p_operation_id,b.id,actor,substring(p_kind from 7),b.plate,observed);
   end if;
  end if;
 end if;
 if result is null then
  result:=to_jsonb(b)-'qr_token';
  insert into public.notifications(user_id,booking_id,title,body) values(b.customer_id,b.id,
   case p_kind when 'booking.create' then 'Đặt chỗ thành công' when 'booking.extend' then 'Gia hạn thành công'
    when 'booking.cancel' then 'Đã hủy vé' when 'staff.check_in' then 'Xe đã vào bãi' else 'Xe đã ra bãi' end,l.name||' · '||b.plate);
 end if;
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values(actor,p_operation_id,p_kind,p_payload,result);
 return result;
end $$;

-- The invoker snapshot can call this privacy-safe count helper through a guarded public projection.
create function public.capacity_snapshot() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('lot_id',l.id,'kind',k.kind,'capacity',k.cap,'remaining',
  greatest(0,k.cap-smartpark_private.capacity_used(l.id,k.kind,now(),now()+interval '1 microsecond')))),'[]'::jsonb)
 from public.parking_lots l cross join lateral (values ('car',l.car_capacity),('motorcycle',l.motorcycle_capacity)) k(kind,cap)
 where auth.uid() is not null and (l.enabled or public.works_lot(l.id))
$$;

create or replace function public.park_snapshot_rows() returns jsonb language sql volatile security invoker set search_path='' as $$
 select jsonb_build_object(
 'profiles',coalesce((select jsonb_agg(to_jsonb(t)) from public.profiles t),'[]'::jsonb),
 'lots',coalesce((select jsonb_agg(to_jsonb(t)) from public.parking_lots t),'[]'::jsonb),
 'capacities',public.capacity_snapshot(),
 'memberships',coalesce((select jsonb_agg(to_jsonb(t)) from public.lot_staff t),'[]'::jsonb),
 'vehicles',coalesce((select jsonb_agg(to_jsonb(t)) from public.vehicles t where not deleted),'[]'::jsonb),
 'bookings',coalesce((select jsonb_agg(to_jsonb(t)-'qr_token' order by created_at desc) from public.bookings t),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(to_jsonb(t)) from public.payments t),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from public.notifications t),'[]'::jsonb),
 'favorites',coalesce((select jsonb_agg(to_jsonb(t)) from public.favorites t),'[]'::jsonb),'server_time',now())
$$;
revoke execute on function public.slot_availability(uuid,timestamptz,timestamptz),public.current_slots(),public.manage_slot(uuid,boolean) from public,anon,authenticated;
revoke all on public.parking_slots from authenticated;
revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
grant execute on function public.manage_lot(uuid,text,text,boolean,integer,integer,double precision,double precision,integer),
 public.resolve_plate(uuid,text),public.capacity_snapshot() to authenticated;
revoke execute on function public.manage_lot(uuid,text,text,boolean,integer,integer,double precision,double precision,integer),public.resolve_plate(uuid,text),public.capacity_snapshot() from public,anon;
notify pgrst,'reload schema';
commit;
