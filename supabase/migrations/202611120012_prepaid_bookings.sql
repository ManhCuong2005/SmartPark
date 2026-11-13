-- Prepay new reservations; keep cash checkout for existing tickets.
begin;
alter table public.bookings add column prepaid boolean not null default false;
alter table public.payments drop constraint payments_booking_id_key;
alter table public.payments drop constraint payments_method_check;
alter table public.payments drop constraint payments_amount_check;
alter table public.payments add column operation_id uuid unique;
alter table public.payments add constraint payments_method_check
 check(method in ('cash','wallet','qr','wallet_refund'));
alter table public.payments add constraint payments_amount_check
 check((method='wallet_refund' and amount<0) or (method<>'wallet_refund' and amount>=0));
create unique index payments_cash_booking on public.payments(booking_id) where method='cash';
create unique index payments_refund_booking on public.payments(booking_id) where method='wallet_refund';

alter table public.wallet_topups add column booking_kind text
 check(booking_kind in ('booking.pay','booking.extend.pay'));
alter table public.wallet_topups add column booking_payload jsonb;
alter table public.wallet_topups add column booking_operation_id uuid;
alter table public.wallet_topups add column booking_result jsonb;
alter table public.wallet_topups add column booking_error text;
alter table public.wallet_topups add constraint wallet_topups_booking_request_check check(
 (booking_kind is null and booking_payload is null and booking_operation_id is null) or
 (booking_kind is not null and booking_payload is not null and jsonb_typeof(booking_payload)='object' and booking_operation_id is not null));
create unique index wallet_topups_booking_operation
 on public.wallet_topups(customer_id,booking_operation_id) where booking_operation_id is not null;

-- Payments are the debit/refund ledger. Only authenticated owners of the
-- underlying ticket can read these rows through the existing RLS policy.
create or replace function public.wallet_topup_balance() returns bigint
language sql stable security invoker set search_path='' as $$
 select coalesce((select sum(t.amount) from public.wallet_topups t
  where t.customer_id=auth.uid() and t.paid_at is not null),0)
 - coalesce((select sum(p.amount) from public.payments p join public.bookings b on b.id=p.booking_id
  where b.customer_id=auth.uid() and p.method in ('wallet','qr','wallet_refund')),0)
$$;

create function public.booking_payment_quote(p_kind text,p_payload jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); b public.bookings; v public.vehicles; l public.parking_lots;
 from_at timestamptz; until_at timestamptz; fee integer; cap integer;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind='booking.pay' then
  select * into v from public.vehicles where id=(p_payload->>'vehicle_id')::uuid and user_id=actor and not deleted;
  if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
  select * into l from public.parking_lots where id=(p_payload->>'lot_id')::uuid and enabled;
  if not found then raise exception 'LOT_UNAVAILABLE'; end if;
  from_at:=(p_payload->>'starts_at')::timestamptz; until_at:=(p_payload->>'ends_at')::timestamptz;
  if from_at is null or until_at is null or from_at<now()-interval '5 minutes' or until_at<=now()
   or until_at<=from_at or until_at-from_at>interval '7 days' then raise exception 'INVALID_TIME'; end if;
  b.plate:=v.plate; b.vehicle_kind:=v.kind;
  b.hourly_rate:=case v.kind when 'car' then l.car_rate else l.motorcycle_rate end;
 elsif p_kind='booking.extend.pay' then
  select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid and customer_id=actor;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  if b.status<>'parked' or not b.prepaid then raise exception 'INVALID_STATE'; end if;
  if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  select * into l from public.parking_lots where id=b.lot_id;
  from_at:=b.ends_at; until_at:=(p_payload->>'ends_at')::timestamptz;
  if until_at is null or until_at<=greatest(now(),from_at) or until_at>now()+interval '7 days' then raise exception 'INVALID_TIME'; end if;
 else raise exception 'UNKNOWN_OPERATION'; end if;
 cap:=case b.vehicle_kind when 'car' then l.car_capacity else l.motorcycle_capacity end;
 if smartpark_private.capacity_used(l.id,b.vehicle_kind,greatest(now(),from_at),until_at,b.id)>=cap then raise exception 'CAPACITY_FULL'; end if;
 if smartpark_private.plate_busy(b.plate,greatest(now(),from_at),until_at,b.id) then raise exception 'VEHICLE_TIME_CONFLICT'; end if;
 fee:=smartpark_private.parking_fee(from_at,until_at,b.hourly_rate);
 return jsonb_build_object('amount',fee,'lot_id',l.id,'plate',b.plate);
end $$;

create function smartpark_private.pay_booking(p_operation_id uuid,p_kind text,p_payload jsonb,p_order_code bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; b public.bookings; v public.vehicles;
 quote jsonb; fee integer; result jsonb; target_lot uuid; normalized text;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind not in ('booking.pay','booking.extend.pay') then raise exception 'UNKNOWN_OPERATION'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 -- Serialize all debits for an account, then use the existing plate/lot lock order.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
 if p_kind='booking.pay' then
  select * into v from public.vehicles where id=(p_payload->>'vehicle_id')::uuid and user_id=actor and not deleted;
  if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
  target_lot:=(p_payload->>'lot_id')::uuid; normalized:=v.plate;
 else
  select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid and customer_id=actor;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  target_lot:=b.lot_id; normalized:=b.plate;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(normalized,3));
 perform 1 from public.parking_lots where id=target_lot for update;
 quote:=public.booking_payment_quote(p_kind,p_payload); fee:=(quote->>'amount')::integer;
 if fee is distinct from (p_payload->>'expected_amount')::integer then raise exception 'PRICE_CHANGED'; end if;
 if p_order_code is not null and not exists(select 1 from public.wallet_topups t
  where t.order_code=p_order_code and t.customer_id=actor and t.paid_at is not null
   and t.booking_operation_id=p_operation_id and t.booking_kind=p_kind and t.booking_payload=p_payload and t.amount=fee)
  then raise exception 'PAYMENT_REQUIRED'; end if;
 if public.wallet_topup_balance()<fee then raise exception 'INSUFFICIENT_BALANCE'; end if;
 -- Reuse the existing atomic capacity, ownership, version and plate checks.
 result:=public.apply_capacity_operation(p_operation_id,
  case p_kind when 'booking.pay' then 'booking.create' else 'booking.extend' end,p_payload-'expected_amount');
 update public.bookings set prepaid=true,amount=amount+fee where id=(result->>'id')::uuid returning * into b;
 insert into public.payments(booking_id,amount,method,received_by,operation_id)
  values(b.id,fee,case when p_order_code is null then 'wallet' else 'qr' end,actor,p_operation_id);
 result:=to_jsonb(b)-'qr_token';
 update public.operation_receipts set kind=p_kind,payload=p_payload,result=to_jsonb(b)-'qr_token'
  where actor_id=actor and operation_id=p_operation_id;
 return result;
end $$;

-- A verified payOS credit and its ticket debit commit together. If the schedule
-- changed while paying, keep the entire credit in the wallet, never lose it.
create or replace function public.settle_payos_topup(p_order_code bigint,p_payment_link_id text,p_amount integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare t public.wallet_topups; result jsonb; failure text;
 old_sub text:=current_setting('request.jwt.claim.sub',true);
 old_claims text:=current_setting('request.jwt.claims',true);
begin
 select * into t from public.wallet_topups where order_code=p_order_code for update;
 if not found or t.payment_link_id is distinct from p_payment_link_id or t.amount is distinct from p_amount then return false; end if;
 if t.paid_at is null then update public.wallet_topups set paid_at=now() where order_code=t.order_code; end if;
 if t.booking_kind is not null and t.booking_result is null and t.booking_error is null then
  perform set_config('request.jwt.claim.sub',t.customer_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.customer_id,'role','authenticated')::text,true);
  begin
   result:=smartpark_private.pay_booking(t.booking_operation_id,t.booking_kind,t.booking_payload,t.order_code);
   update public.wallet_topups set booking_result=result where order_code=t.order_code;
  exception when raise_exception or exclusion_violation or unique_violation then
   get stacked diagnostics failure=message_text;
   if sqlstate='23P01' then failure:='VEHICLE_TIME_CONFLICT';
   elsif sqlstate='23505' then failure:='23505'; end if;
   -- Unexpected database errors still fail the webhook so payOS can retry.
   if failure not in ('INVALID_TIME','INVALID_STATE','VERSION_CONFLICT','CAPACITY_FULL','VEHICLE_TIME_CONFLICT',
    'VEHICLE_NOT_FOUND','TICKET_NOT_FOUND','LOT_UNAVAILABLE','PRICE_CHANGED','INSUFFICIENT_BALANCE','23505') then raise; end if;
   update public.wallet_topups set booking_error=failure where order_code=t.order_code;
   insert into public.notifications(user_id,title,body) values(t.customer_id,'Tiền đã vào số dư gửi xe',
    'Lịch đặt vé đã thay đổi trong lúc thanh toán. Tiền được giữ trong số dư; vui lòng chọn lại lịch và thanh toán bằng số dư.');
  end;
  perform set_config('request.jwt.claim.sub',coalesce(old_sub,''),true);
  perform set_config('request.jwt.claims',coalesce(old_claims,''),true);
 end if;
 return t.paid_at is null;
end $$;

create function smartpark_private.prepaid_checkout(p_operation_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; b public.bookings; observed timestamptz; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>'staff.check_out' or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
 select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid;
 if not found then raise exception 'TICKET_NOT_FOUND'; end if;
 if not public.works_lot(b.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b.plate,3));
 perform 1 from public.parking_lots where id=b.lot_id for update;
 select * into b from public.bookings where id=b.id for update;
 if not b.prepaid then raise exception 'INVALID_STATE'; end if;
 if smartpark_private.plate(p_payload->>'plate') is distinct from b.plate then raise exception 'PLATE_MISMATCH'; end if;
 if b.status<>'completed' then
  if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  observed:=(p_payload->>'occurred_at')::timestamptz;
  if observed is null or observed>now()+interval '5 minutes' or observed<now()-interval '24 hours' then raise exception 'CLOCK_REVIEW_REQUIRED'; end if;
  if b.status<>'parked' or observed<b.checked_in_at then raise exception 'INVALID_STATE'; end if;
  -- No unapproved overdue tariff: keep the amount already paid, record actual exit.
  update public.bookings set status='completed',checked_out_at=observed,version=version+1 where id=b.id returning * into b;
  insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at)
   values(p_operation_id,b.id,actor,'check_out',b.plate,observed);
  insert into public.notifications(user_id,booking_id,title,body)
   values(b.customer_id,b.id,'Xe đã ra bãi','Vé đã thanh toán trước. Không thu lại tiền vé khi xe ra.');
 end if;
 result:=to_jsonb(b)-'qr_token';
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
  values(actor,p_operation_id,'staff.check_out',p_payload,result);
 return result;
end $$;

alter function public.apply_operation(uuid,text,jsonb) rename to apply_parking_operation;
revoke execute on function public.apply_parking_operation(uuid,text,jsonb) from public,anon,authenticated;
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b public.bookings; result jsonb; previous public.operation_receipts;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind in ('booking.pay','booking.extend.pay') then
  return smartpark_private.pay_booking(p_operation_id,p_kind,p_payload);
 end if;
 if p_kind='booking.create' then raise exception 'PAYMENT_REQUIRED'; end if;
 select * into b from public.bookings where id=nullif(p_payload->>'booking_id','')::uuid;
 if b.prepaid then
  if p_kind='booking.extend' then raise exception 'PAYMENT_REQUIRED'; end if;
  if p_kind='staff.check_out' then return smartpark_private.prepaid_checkout(p_operation_id,p_payload); end if;
  if p_kind='booking.cancel' then
   perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_operation_id::text,0));
   select * into previous from public.operation_receipts where actor_id=auth.uid() and operation_id=p_operation_id;
   if found then
    if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
    return previous.result;
   end if;
   result:=public.apply_parking_operation(p_operation_id,p_kind,p_payload);
   select * into b from public.bookings where id=(result->>'id')::uuid;
   if b.amount>0 then
    insert into public.payments(booking_id,amount,method,received_by,operation_id)
     values(b.id,-b.amount,'wallet_refund',auth.uid(),p_operation_id);
   end if;
   update public.bookings set amount=0 where id=b.id returning * into b;
   result:=to_jsonb(b)-'qr_token';
   update public.operation_receipts set result=to_jsonb(b)-'qr_token' where actor_id=auth.uid() and operation_id=p_operation_id;
   insert into public.notifications(user_id,booking_id,title,body)
    values(b.customer_id,b.id,'Đã hoàn tiền vào số dư gửi xe','Vé đã được hủy hợp lệ. Tiền vé được hoàn vào số dư gửi xe, không chuyển về ngân hàng.');
   return result;
  end if;
 end if;
 return public.apply_parking_operation(p_operation_id,p_kind,p_payload);
end $$;

-- Paid no-shows release capacity, but financial records must remain auditable.
alter function smartpark_private.expire_no_shows(uuid,uuid) rename to expire_unpaid_no_shows;
create function smartpark_private.expire_no_shows(p_scope uuid default null,p_slot uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare l record; b public.bookings;
begin
 perform smartpark_private.expire_unpaid_no_shows(p_scope,p_slot);
 for l in select lot.id from public.parking_lots lot where exists(select 1 from public.bookings t
  where t.lot_id=lot.id and t.prepaid and t.status='confirmed' and t.ends_at<=now()
   and (p_scope is null or t.customer_id=p_scope or lot.owner_id=p_scope or exists(
    select 1 from public.lot_staff s where s.lot_id=lot.id and s.user_id=p_scope and s.active)))
  order by lot.id for update of lot skip locked
 loop
  for b in update public.bookings set status='expired',version=version+1 where lot_id=l.id and prepaid
   and status='confirmed' and checked_in_at is null and ends_at<=now() and (p_slot is null or slot_id=p_slot)
   and (p_scope is null or customer_id=p_scope or public.works_lot(l.id)) returning *
  loop
   insert into public.notifications(user_id,booking_id,category,dedupe_key,title,body)
    values(b.customer_id,b.id,'booking_expired','booking_expired:'||b.id,'Vé đã hết hạn',
     'Đã đến giờ ra dự kiến nhưng xe chưa vào bãi. Vé không còn hiệu lực; lịch sử thanh toán vẫn được lưu.')
    on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
  end loop;
 end loop;
end $$;

create or replace function smartpark_private.process_deadlines(p_scope uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings; lot_name text; category text; heading text; message text;
begin
 perform smartpark_private.expire_no_shows(p_scope);
 for b in select t.* from public.bookings t where t.status='parked' and t.ends_at<=now()+interval '10 minutes'
  and (p_scope is null or t.customer_id=p_scope or exists(
   select 1 from public.parking_lots l where l.id=t.lot_id and l.owner_id=p_scope)
   or exists(select 1 from public.lot_staff s where s.lot_id=t.lot_id and s.user_id=p_scope and s.active))
  order by t.ends_at for update of t skip locked
 loop
  select name into lot_name from public.parking_lots where id=b.lot_id;
  if b.ends_at>now() then
   category:='pickup_soon'; heading:='Còn ít phút đến giờ lấy xe';
   message:=lot_name||': giờ ra dự kiến '||to_char(b.ends_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI DD/MM')||
    '. Vui lòng ra đúng giờ hoặc mở vé để gia hạn nếu còn chỗ.';
  else
   category:='pickup_overdue'; heading:='Xe đã quá giờ ra dự kiến';
   message:=lot_name||': vui lòng lấy xe hoặc mở vé để gia hạn nếu còn chỗ.';
  end if;
  if b.prepaid then message:=message||' Phần gia hạn cần được thanh toán trước.';
  elsif b.ends_at<=now() then message:=message||' Phí vẫn tính đến khi xe ra thực tế.'; end if;
  insert into public.notifications(user_id,booking_id,category,dedupe_key,title,body)
   values(b.customer_id,b.id,category,category||':'||b.id||':'||extract(epoch from b.ends_at),heading,message)
   on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
 end loop;
end $$;

revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
revoke all on function public.settle_payos_topup(bigint,text,integer) from public,anon,authenticated;
grant execute on function public.settle_payos_topup(bigint,text,integer) to service_role;
revoke execute on function public.booking_payment_quote(text,jsonb),public.apply_operation(uuid,text,jsonb) from public,anon;
grant execute on function public.booking_payment_quote(text,jsonb),public.apply_operation(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
