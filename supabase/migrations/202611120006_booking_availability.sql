-- Apply once after 005. No booking, payment or customer data is deleted.
begin;

create function smartpark_private.vehicle_booking_conflict(p_vehicle uuid,p_start timestamptz,p_end timestamptz)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',b.id,'status',b.status,'starts_at',b.starts_at,'ends_at',b.ends_at,
  'lot_name',l.name,'slot_code',s.code)
 from public.bookings b join public.parking_lots l on l.id=b.lot_id
 join public.parking_slots s on s.id=b.slot_id
 where b.vehicle_id=p_vehicle and b.customer_id=auth.uid() and (
  (b.status='confirmed' and b.ends_at+interval '1 hour'>now()
   and tstzrange(b.starts_at,b.ends_at+interval '1 hour','[)') && tstzrange(p_start,p_end,'[)'))
  or (b.status='parked' and (p_start<=now()
   or tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(p_start,p_end,'[)'))))
 order by (b.status='parked') desc,b.starts_at,b.id limit 1
$$;

-- Preserve slot_availability's 3-argument contract for existing clients. The new
-- customer flow receives slot occupancy and its own vehicle conflict together.
create function public.booking_availability(p_lot_id uuid,p_start timestamptz,p_end timestamptz,p_vehicle_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare slots jsonb; conflict jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 slots:=public.slot_availability(p_lot_id,p_start,p_end);
 if p_vehicle_id is not null then
  if not exists(select 1 from public.vehicles where id=p_vehicle_id and user_id=auth.uid() and not deleted)
   then raise exception 'VEHICLE_NOT_FOUND'; end if;
  conflict:=smartpark_private.vehicle_booking_conflict(p_vehicle_id,p_start,p_end+interval '1 hour');
 end if;
 return jsonb_build_object('slots',slots,'vehicle_conflict',conflict);
end $$;

-- Reuse the existing atomic command core and locks. Distinguish the selected
-- vehicle's schedule from the selected slot's schedule before the core writes.
create or replace function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare slot_id uuid; vehicle_id uuid; requested_start timestamptz; requested_end timestamptz;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind in ('booking.create','vehicle.save') then
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 end if;
 -- A retry must return its existing receipt before it checks the booking that
 -- this very operation created. The core also rejects a reused ID/payload.
 if exists(select 1 from public.operation_receipts where actor_id=auth.uid() and operation_id=p_operation_id) then
  return public.apply_operation_core(p_operation_id,p_kind,p_payload);
 end if;
 if p_kind='booking.create' then
  slot_id:=(p_payload->>'slot_id')::uuid;
  vehicle_id:=(p_payload->>'vehicle_id')::uuid;
 elsif p_kind in ('booking.cancel','staff.check_in','staff.check_out') then
  select b.slot_id,b.vehicle_id into slot_id,vehicle_id from public.bookings b where b.id=(p_payload->>'booking_id')::uuid;
 end if;
 if vehicle_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(vehicle_id::text,2));
 end if;
 if slot_id is not null then
  perform 1 from public.parking_slots s where s.id=slot_id for update;
  perform smartpark_private.expire_no_shows(null,slot_id);
 else
  perform public.refresh_booking_deadlines();
 end if;
 if p_kind='booking.create' then
  if not exists(select 1 from public.vehicles where id=vehicle_id and user_id=auth.uid() and not deleted)
   then raise exception 'VEHICLE_NOT_FOUND'; end if;
  requested_start:=(p_payload->>'starts_at')::timestamptz;
  requested_end:=(p_payload->>'ends_at')::timestamptz;
  if requested_start is null or requested_end is null or requested_end<=requested_start
    or requested_start<now()-interval '5 minutes' or requested_end-requested_start>interval '7 days'
   then raise exception 'INVALID_TIME'; end if;
  if smartpark_private.booking_conflicts(null,vehicle_id,requested_start,requested_end+interval '1 hour')
   then raise exception 'VEHICLE_TIME_CONFLICT' using errcode='23P01'; end if;
  if smartpark_private.booking_conflicts(slot_id,null,requested_start,requested_end+interval '1 hour')
   then raise exception 'SLOT_TIME_CONFLICT' using errcode='23P01'; end if;
 end if;
 return public.apply_operation_core(p_operation_id,p_kind,p_payload);
end $$;

revoke execute on function smartpark_private.vehicle_booking_conflict(uuid,timestamptz,timestamptz) from public,anon,authenticated;
revoke execute on function public.booking_availability(uuid,timestamptz,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.booking_availability(uuid,timestamptz,timestamptz,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
