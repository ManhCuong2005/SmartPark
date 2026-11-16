-- Automatic kiosk scans use server time and an atomic wallet checkout.
begin;

alter table public.bookings add column paid_until timestamptz;
update public.bookings set paid_until=ends_at where prepaid;

create function smartpark_private.track_prepaid_period() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.prepaid and new.status<>'completed' and (not old.prepaid or new.amount>old.amount) then
  new.paid_until:=new.ends_at;
 end if;
 return new;
end $$;
create trigger smartpark_prepaid_period before update on public.bookings
 for each row execute function smartpark_private.track_prepaid_period();

create function smartpark_private.wallet_balance(p_customer uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce((select sum(amount) from public.wallet_topups where customer_id=p_customer and paid_at is not null),0)
 -coalesce((select sum(p.amount) from public.payments p join public.bookings b on b.id=p.booking_id
  where b.customer_id=p_customer and p.method in ('wallet','qr','wallet_refund')),0)
$$;

create function smartpark_private.wallet_checkout(p_operation_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); b public.bookings; previous public.operation_receipts;
 fee integer:=0; result jsonb; observed timestamptz:=now();
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>'staff.check_out' or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid;
 if not found then raise exception 'TICKET_NOT_FOUND'; end if;
 if not public.works_lot(b.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 -- All debits share the customer lock used by prepayment, before plate/lot/ticket.
 perform pg_advisory_xact_lock(hashtextextended(b.customer_id::text,1));
 perform pg_advisory_xact_lock(hashtextextended(b.plate,3));
 perform 1 from public.parking_lots where id=b.lot_id for update;
 select * into b from public.bookings where id=b.id for update;
 if smartpark_private.plate(p_payload->>'plate') is distinct from b.plate then raise exception 'PLATE_MISMATCH'; end if;
 if b.status<>'completed' then
  if b.status<>'parked' then raise exception 'INVALID_STATE'; end if;
  if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  if observed<b.checked_in_at then raise exception 'CLOCK_REVIEW_REQUIRED'; end if;
  if b.prepaid then
   if b.paid_until is null then raise exception 'PAYMENT_REVIEW_REQUIRED'; end if;
   if observed>b.paid_until then fee:=smartpark_private.parking_fee(b.paid_until,observed,b.hourly_rate); end if;
  else
   fee:=smartpark_private.parking_fee(b.checked_in_at,observed,b.hourly_rate);
  end if;
  if smartpark_private.wallet_balance(b.customer_id)<fee then
   if observed>b.ends_at then raise exception 'OVERDUE_INSUFFICIENT_BALANCE'; end if;
   raise exception 'INSUFFICIENT_BALANCE';
  end if;
  if fee>0 then
   insert into public.payments(booking_id,amount,method,received_by,operation_id)
    values(b.id,fee,'wallet',actor,p_operation_id);
  end if;
  -- Do not extend paid_until when collecting the final balance.
  update public.bookings set status='completed',checked_out_at=observed,
   amount=case when prepaid then amount+fee else fee end,version=version+1
   where id=b.id returning * into b;
  insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at)
   values(p_operation_id,b.id,actor,'check_out',b.plate,observed);
  insert into public.notifications(user_id,booking_id,title,body)
   values(b.customer_id,b.id,'Xe đã ra bãi','Đã thanh toán. Phí thu thêm khi ra: '||fee||'đ.');
 end if;
 result:=to_jsonb(b)-'qr_token';
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
  values(actor,p_operation_id,'staff.check_out',p_payload,result);
 return result;
end $$;

create function smartpark_private.scan_plate(p_operation_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid:=(p_payload->>'lot_id')::uuid;
 normalized text:=smartpark_private.plate(p_payload->>'plate'); b public.bookings;
 previous public.operation_receipts; matches integer; scan_result jsonb; command jsonb; direction text;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if not public.works_lot(target) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if normalized !~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$' then raise exception 'INVALID_PLATE'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>'kiosk.scan' or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 select * into b from public.bookings where lot_id=target and plate=normalized
  and (status='parked' or (status='confirmed' and starts_at<=now() and ends_at>now())
   or (status='completed' and checked_out_at>now()-interval '30 seconds'))
  order by (status='parked') desc,(status='confirmed') desc,starts_at limit 1;
 if not found then raise exception 'VALID_TICKET_REQUIRED'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b.customer_id::text,1));
 perform pg_advisory_xact_lock(hashtextextended(normalized,3));
 perform 1 from public.parking_lots where id=target for update;
 if not found then raise exception 'LOT_UNAVAILABLE'; end if;
 -- Re-read after locks; another camera may have processed this same vehicle.
 select count(*) into matches from public.bookings where lot_id=target and plate=normalized
  and (status='parked' or (status='confirmed' and starts_at<=now() and ends_at>now()));
 if matches>1 then raise exception 'PLATE_AMBIGUOUS'; end if;
 select * into b from public.bookings where id=b.id for update;
 if (b.status='parked' and b.checked_in_at>now()-interval '30 seconds')
  or (b.status='completed' and b.checked_out_at>now()-interval '30 seconds') then
  scan_result:=jsonb_build_object('action','duplicate','booking',to_jsonb(b)-'qr_token');
  insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
   values(actor,p_operation_id,'kiosk.scan',p_payload,scan_result);
  return scan_result;
 end if;
 command:=jsonb_build_object('booking_id',b.id,'plate',normalized,'expected_version',b.version,'occurred_at',now());
 if b.status='confirmed' and b.starts_at<=now() and b.ends_at>now() then
  if not exists(select 1 from public.parking_lots where id=target and enabled) then raise exception 'LOT_UNAVAILABLE'; end if;
  direction:='entered';
  scan_result:=public.apply_capacity_operation(p_operation_id,'staff.check_in',command);
 elsif b.status='parked' then
  direction:='exited';
  scan_result:=smartpark_private.wallet_checkout(p_operation_id,command);
 else raise exception 'VALID_TICKET_REQUIRED'; end if;
 scan_result:=jsonb_build_object('action',direction,'booking',scan_result);
 update public.operation_receipts set kind='kiosk.scan',payload=p_payload,result=scan_result
  where actor_id=actor and operation_id=p_operation_id;
 return scan_result;
end $$;

alter function public.apply_operation(uuid,text,jsonb) rename to apply_prepaid_operation;
revoke execute on function public.apply_prepaid_operation(uuid,text,jsonb) from public,anon,authenticated;
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_operation_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'INVALID_REQUEST'; end if;
 if p_kind='kiosk.scan' then return smartpark_private.scan_plate(p_operation_id,p_payload); end if;
 if p_kind='staff.check_out' then return smartpark_private.wallet_checkout(p_operation_id,p_payload); end if;
 if p_kind not in ('booking.reserve','booking.extend.deferred') then
  return public.apply_prepaid_operation(p_operation_id,p_kind,p_payload);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 if p_kind='booking.reserve' then
  perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
  if smartpark_private.wallet_balance(actor)<100000 then raise exception 'PAY_LATER_BALANCE_REQUIRED'; end if;
 end if;
 result:=public.apply_capacity_operation(p_operation_id,
  case when p_kind='booking.reserve' then 'booking.create' else 'booking.extend' end,p_payload);
 update public.operation_receipts set kind=p_kind,payload=p_payload where actor_id=actor and operation_id=p_operation_id;
 return result;
end $$;

alter function smartpark_private.expire_no_shows(uuid,uuid) rename to expire_before_automatic;
create function smartpark_private.expire_no_shows(p_scope uuid default null,p_slot uuid default null) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform smartpark_private.expire_before_automatic(p_scope,p_slot);
 -- An acknowledged reservation must never be resurrected by a delayed retry.
 update public.operation_receipts r set result=jsonb_build_object('id',r.result->>'id','status','expired','deleted',true)
  where r.kind='booking.reserve' and r.result->>'status'='confirmed'
   and not exists(select 1 from public.bookings b where b.id=(r.result->>'id')::uuid);
end $$;

create or replace function smartpark_private.process_deadlines(p_scope uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings; lot_name text; category text; heading text; message text;
begin
 perform smartpark_private.expire_no_shows(p_scope);
 for b in select t.* from public.bookings t where t.status='parked' and t.ends_at<=now()+interval '10 minutes'
  and (p_scope is null or t.customer_id=p_scope or public.works_lot(t.lot_id))
  order by t.ends_at for update of t skip locked
 loop
  select name into lot_name from public.parking_lots where id=b.lot_id;
  if b.ends_at>now() then
   category:='pickup_soon'; heading:='Còn ít phút đến giờ lấy xe';
   message:=lot_name||': giờ ra dự kiến '||to_char(b.ends_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI DD/MM')||
    '. Bạn có thể mở vé để gia hạn nếu còn chỗ, hoặc lấy xe đúng giờ.';
  else
   category:='pickup_overdue'; heading:='Xe đã quá giờ ra dự kiến';
   message:=lot_name||': phí phát sinh tiếp tục tính đến khi xe ra. Vui lòng bảo đảm số dư đủ thanh toán.';
  end if;
  message:=message||' Phần chưa thanh toán được trừ từ số dư khi xe ra.';
  insert into public.notifications(user_id,booking_id,category,dedupe_key,title,body)
   values(b.customer_id,b.id,category,category||':'||b.id||':'||extract(epoch from b.ends_at),heading,message)
   on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
 end loop;
end $$;

revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
revoke execute on function public.apply_operation(uuid,text,jsonb) from public,anon;
grant execute on function public.apply_operation(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
