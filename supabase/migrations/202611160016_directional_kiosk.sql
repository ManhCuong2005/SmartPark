-- Each unattended camera has a server-bound lot and direction.
begin;
create table smartpark_private.kiosk_sessions (
 id uuid primary key,
 actor_id uuid not null references public.profiles(id),
 lot_id uuid not null references public.parking_lots(id),
 direction text not null check(direction in ('entry','exit')),
 created_at timestamptz not null default now()
);
alter table smartpark_private.kiosk_sessions enable row level security;
revoke all on smartpark_private.kiosk_sessions from public,anon,authenticated;

create or replace function smartpark_private.scan_plate(p_operation_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid:=(p_payload->>'lot_id')::uuid;
 normalized text:=smartpark_private.plate(p_payload->>'plate'); b public.bookings;
 previous public.operation_receipts; matches integer; scan_result jsonb; command jsonb;
 mode text; action text;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if not public.works_lot(target) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select direction into mode from smartpark_private.kiosk_sessions
  where id=(p_payload->>'session_id')::uuid and actor_id=actor and lot_id=target;
 if not found then raise exception 'KIOSK_SESSION_REQUIRED'; end if;
 if (p_payload->>'direction') is distinct from mode then raise exception 'KIOSK_DIRECTION_MISMATCH'; end if;
 if normalized is null or normalized !~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$' then raise exception 'INVALID_PLATE'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>'kiosk.scan' or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 select * into b from public.bookings where lot_id=target and plate=normalized
  and (status='parked' or (status='confirmed' and starts_at<=now() and ends_at>now())
   or (mode='exit' and status='completed' and checked_out_at>now()-interval '30 seconds'))
  order by (status='parked') desc,(status='confirmed') desc,starts_at limit 1;
 if not found then raise exception 'VALID_TICKET_REQUIRED'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b.customer_id::text,1));
 perform pg_advisory_xact_lock(hashtextextended(normalized,3));
 perform 1 from public.parking_lots where id=target for update;
 if not found then raise exception 'LOT_UNAVAILABLE'; end if;
 select count(*) into matches from public.bookings where lot_id=target and plate=normalized
  and (status='parked' or (status='confirmed' and starts_at<=now() and ends_at>now()));
 if matches>1 then raise exception 'PLATE_AMBIGUOUS'; end if;
 select * into b from public.bookings where id=b.id for update;
 -- An entry camera observing a parked car can never turn that sighting into checkout.
 if (mode='entry' and b.status='parked')
  or (mode='exit' and b.status='completed' and b.checked_out_at>now()-interval '30 seconds') then
  scan_result:=jsonb_build_object('action','duplicate','booking',to_jsonb(b)-'qr_token');
  insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
   values(actor,p_operation_id,'kiosk.scan',p_payload,scan_result);
  return scan_result;
 end if;
 command:=jsonb_build_object('booking_id',b.id,'plate',normalized,'expected_version',b.version,'occurred_at',now());
 if mode='entry' and b.status='confirmed' and b.starts_at<=now() and b.ends_at>now() then
  if not exists(select 1 from public.parking_lots where id=target and enabled) then raise exception 'LOT_UNAVAILABLE'; end if;
  action:='entered';
  scan_result:=public.apply_capacity_operation(p_operation_id,'staff.check_in',command);
 elsif mode='exit' and b.status='parked' then
  action:='exited';
  scan_result:=smartpark_private.wallet_checkout(p_operation_id,command);
 elsif mode='exit' and b.status='confirmed' then raise exception 'ENTRY_REQUIRED';
 else raise exception 'VALID_TICKET_REQUIRED'; end if;
 scan_result:=jsonb_build_object('action',action,'booking',scan_result);
 update public.operation_receipts set kind='kiosk.scan',payload=p_payload,result=scan_result
  where actor_id=actor and operation_id=p_operation_id;
 return scan_result;
end $$;

alter function public.apply_operation(uuid,text,jsonb) rename to apply_wallet_choice_operation;
revoke execute on function public.apply_wallet_choice_operation(uuid,text,jsonb) from public,anon,authenticated;
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; mode text; previous smartpark_private.kiosk_sessions;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_operation_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'INVALID_REQUEST'; end if;
 if p_kind='kiosk.open' then
  target:=(p_payload->>'lot_id')::uuid; mode:=p_payload->>'direction';
  if not public.works_lot(target) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if mode is null or mode not in ('entry','exit') then raise exception 'INVALID_KIOSK_DIRECTION'; end if;
  insert into smartpark_private.kiosk_sessions(id,actor_id,lot_id,direction)
   values(p_operation_id,actor,target,mode) on conflict(id) do nothing;
  select * into previous from smartpark_private.kiosk_sessions where id=p_operation_id;
  if previous.actor_id<>actor or previous.lot_id<>target or previous.direction<>mode then raise exception 'OPERATION_ID_REUSED'; end if;
  return jsonb_build_object('session_id',p_operation_id,'lot_id',target,'direction',mode);
 end if;
 if p_kind='kiosk.scan' then return smartpark_private.scan_plate(p_operation_id,p_payload); end if;
 -- Retired manual check-in/out cannot bypass the camera's direction contract.
 if p_kind in ('staff.check_in','staff.check_out') then raise exception 'KIOSK_SESSION_REQUIRED'; end if;
 return public.apply_wallet_choice_operation(p_operation_id,p_kind,p_payload);
end $$;
revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
revoke execute on function public.apply_operation(uuid,text,jsonb) from public,anon;
grant execute on function public.apply_operation(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
