-- Optional immediate extension payment; strictly more than 100k for pay-later.
begin;
create or replace function public.booking_payment_quote(p_kind text,p_payload jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); b public.bookings; v public.vehicles; l public.parking_lots;
 from_at timestamptz; until_at timestamptz; reserve_from timestamptz; fee integer; cap integer;
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
  reserve_from:=from_at;
 elsif p_kind='booking.extend.pay' then
  select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid and customer_id=actor;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  if b.status<>'parked' then raise exception 'INVALID_STATE'; end if;
  if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  select * into l from public.parking_lots where id=b.lot_id;
  from_at:=case when b.prepaid then b.paid_until else b.checked_in_at end;
  if from_at is null then raise exception 'PAYMENT_REVIEW_REQUIRED'; end if;
  until_at:=(p_payload->>'ends_at')::timestamptz;
  if until_at is null or until_at<=greatest(now(),b.ends_at) or until_at>now()+interval '7 days' then raise exception 'INVALID_TIME'; end if;
  reserve_from:=b.ends_at;
 else raise exception 'UNKNOWN_OPERATION'; end if;
 cap:=case b.vehicle_kind when 'car' then l.car_capacity else l.motorcycle_capacity end;
 if smartpark_private.capacity_used(l.id,b.vehicle_kind,greatest(now(),reserve_from),until_at,b.id)>=cap then raise exception 'CAPACITY_FULL'; end if;
 if smartpark_private.plate_busy(b.plate,greatest(now(),reserve_from),until_at,b.id) then raise exception 'VEHICLE_TIME_CONFLICT'; end if;
 fee:=smartpark_private.parking_fee(from_at,until_at,b.hourly_rate);
 return jsonb_build_object('amount',fee,'lot_id',l.id,'plate',b.plate);
end $$;

create or replace function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; result jsonb;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_operation_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'INVALID_REQUEST'; end if;
 if p_kind='kiosk.scan' then return smartpark_private.scan_plate(p_operation_id,p_payload); end if;
 if p_kind='staff.check_out' then return smartpark_private.wallet_checkout(p_operation_id,p_payload); end if;
 if p_kind not in ('booking.reserve','booking.extend.deferred','booking.extend') then
  return public.apply_prepaid_operation(p_operation_id,p_kind,p_payload);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 -- A retry of an acknowledged command above remains valid after later debits.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
 if smartpark_private.wallet_balance(actor)<=100000 then raise exception 'PAY_LATER_BALANCE_REQUIRED'; end if;
 result:=public.apply_capacity_operation(p_operation_id,
  case when p_kind='booking.reserve' then 'booking.create' else 'booking.extend' end,p_payload);
 update public.operation_receipts set kind=p_kind,payload=p_payload where actor_id=actor and operation_id=p_operation_id;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
