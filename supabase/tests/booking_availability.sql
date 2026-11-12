\set ON_ERROR_STOP on
begin;
insert into public.parking_lots(id,owner_id,name) values
 ('23000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','Other lot');
insert into public.parking_slots(id,lot_id,code) values
 ('33000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','A011');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('53000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','Other customer','99E122268','car');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('43000000-0000-0000-0000-000000000001','booking.create',jsonb_build_object(
 'id','63000000-0000-0000-0000-000000000001','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','30000000-0000-0000-0000-000000000001','starts_at',now()+interval '1 hour','ends_at',now()+interval '2 hours'));
do $$ declare result jsonb; begin
 result:=public.booking_availability('23000000-0000-0000-0000-000000000001',now()+interval '90 minutes',now()+interval '3 hours','50000000-0000-0000-0000-000000000001');
 perform public.test_assert(result->'vehicle_conflict'->>'id'='63000000-0000-0000-0000-000000000001',
  'a free slot in another lot still reports the selected vehicle schedule');
 perform public.test_assert((result->'slots'->0->>'occupied')::boolean=false,'vehicle conflict must not falsely label the other lot slot occupied');
 perform public.test_assert(not (result->'vehicle_conflict' ? 'qr_token'),'conflict summary never contains QR capability');
 perform public.test_assert(public.booking_availability('23000000-0000-0000-0000-000000000001',now()+interval '150 minutes',now()+interval '4 hours','50000000-0000-0000-0000-000000000001')->'vehicle_conflict' <> 'null'::jsonb,
  'vehicle conflict includes the one-hour hold after the previous end');
 perform public.test_assert(public.booking_availability('23000000-0000-0000-0000-000000000001',now()+interval '3 hours',now()+interval '4 hours','50000000-0000-0000-0000-000000000001')->'vehicle_conflict' = 'null'::jsonb,
  'touching the end of the hold is available');
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.create',jsonb_build_object(
   'id',gen_random_uuid(),'vehicle_id','50000000-0000-0000-0000-000000000001','slot_id','33000000-0000-0000-0000-000000000001',
   'starts_at',now()+interval '90 minutes','ends_at',now()+interval '3 hours'));
  raise exception 'Expected vehicle conflict';
 exception when exclusion_violation then
  perform public.test_assert(sqlerrm='VEHICLE_TIME_CONFLICT','write reports vehicle conflict rather than falsely blaming another customer');
 end;
 begin
  perform public.booking_availability('23000000-0000-0000-0000-000000000001',now(),now()+interval '1 hour','53000000-0000-0000-0000-000000000001');
  raise exception 'Must not inspect another customer vehicle';
 exception when raise_exception then if sqlerrm<>'VEHICLE_NOT_FOUND' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ declare result jsonb; payload jsonb; command uuid:=gen_random_uuid(); begin
 result:=public.booking_availability('20000000-0000-0000-0000-000000000001',now()+interval '90 minutes',now()+interval '3 hours','53000000-0000-0000-0000-000000000001');
 perform public.test_assert(result->'vehicle_conflict'='null'::jsonb,'a different customer sees no private vehicle conflict');
 perform public.test_assert((result->'slots'->0->>'occupied')::boolean,'a truly reserved slot is disabled before confirming');
 perform public.test_assert(not (result::text like '%63000000-0000-0000-0000-000000000001%'),'slot availability never leaks other customer booking IDs');
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.create',jsonb_build_object(
   'id',gen_random_uuid(),'vehicle_id','53000000-0000-0000-0000-000000000001','slot_id','30000000-0000-0000-0000-000000000001',
   'starts_at',now()+interval '90 minutes','ends_at',now()+interval '3 hours'));
  raise exception 'Expected slot conflict';
 exception when exclusion_violation then
  perform public.test_assert(sqlerrm='SLOT_TIME_CONFLICT','write distinguishes an occupied slot from a vehicle conflict');
 end;
 payload:=jsonb_build_object('id','63000000-0000-0000-0000-000000000002','vehicle_id','53000000-0000-0000-0000-000000000001',
  'slot_id','30000000-0000-0000-0000-000000000002','starts_at',now()+interval '90 minutes','ends_at',now()+interval '3 hours');
 result:=public.apply_operation(command,'booking.create',payload);
 perform public.test_assert(public.apply_operation(command,'booking.create',payload)=result,'lost acknowledgement retries return receipt before conflicting with their own booking');
end $$;
reset role;
set local role anon;
do $$ begin
 begin
  perform public.booking_availability('20000000-0000-0000-0000-000000000001',now(),now()+interval '1 hour');
  raise exception 'Anonymous access should fail';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
