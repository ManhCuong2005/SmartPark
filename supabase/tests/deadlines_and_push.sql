\set ON_ERROR_STOP on
begin;
-- Reuse the committed behavioral fixtures, then roll back all deadline tests.
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('51000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','No show','43A11111','car'),
 ('51000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Pickup soon','43A22222','car'),
 ('51000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','Overdue','43A33333','car'),
 ('51000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','Other customer','43A44444','car');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.register_push_device('test-customer-one-token-1234567890');
do $$ begin
 begin perform public.claim_push_jobs(); raise exception 'Customer must not claim pushes';
 exception when insufficient_privilege then null; end;
 begin perform smartpark_private.process_deadlines(); raise exception 'Customer must not run global maintenance';
 exception when insufficient_privilege then null; end;
 begin perform public.apply_operation_core(gen_random_uuid(),'notifications.read','{}'); raise exception 'Core endpoint must be private';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,status,checked_in_at,hourly_rate,free_minutes) values
 ('61000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','43A11111',now()-interval '150 minutes',now()-interval '70 minutes','confirmed',null,15000,0),
 ('61000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','43A22222',now()-interval '9 minutes',now()+interval '20 minutes','parked',now()-interval '9 minutes',15000,0),
 ('61000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002','43A33333',now()-interval '3 hours',now()-interval '2 hours','parked',now()-interval '3 hours',15000,0),
 ('61000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002','43A44444',now()-interval '90 minutes',now()-interval '60 minutes','confirmed',null,15000,0);
set local role authenticated;
select public.park_snapshot();
select public.park_snapshot();
select public.test_assert((select status='expired' and version=2 and amount=0 and checked_out_at is null from public.bookings where id='61000000-0000-0000-0000-000000000001'),'no-show ends without fabricated checkout or fee');
select public.test_assert((select count(*)=2 from public.bookings where status='parked'),'parked vehicle never automatically completes');
select public.test_assert((select count(*)=3 from public.notifications where category is not null),'deadline notifications are deduplicated');
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'vehicle.save','{"id":"51000000-0000-0000-0000-000000000002","label":"X","plate":"43A99999","kind":"car","expected_version":1}');
  raise exception 'Expected vehicle guard';
 exception when raise_exception then if sqlerrm<>'VEHICLE_IN_USE' then raise; end if; end;
 -- The expired vehicle can now be changed. No artificial payment is inserted.
 perform public.apply_operation(gen_random_uuid(),'vehicle.save','{"id":"51000000-0000-0000-0000-000000000001","label":"X","plate":"43A88888","kind":"car","expected_version":1}');
end $$;
reset role;
select public.test_assert((select status='confirmed' from public.bookings where id='61000000-0000-0000-0000-000000000004'),'request fallback respects actor scope');
select public.test_assert((select count(*)=1 from public.payments),'no-show does not create revenue');
select public.test_assert((select count(*)=3 from public.push_jobs),'one push job per device and notification');
-- Check-out before delivery cancels the obsolete reminder.
update public.bookings set status='completed',checked_out_at=now() where id='61000000-0000-0000-0000-000000000002';
set local role service_role;
do $$ declare jobs jsonb; j jsonb; begin
 jobs:=public.claim_push_jobs();
 perform public.test_assert(jsonb_array_length(jobs)=2,'obsolete pickup reminder is not dispatched');
 for j in select * from jsonb_array_elements(jobs) loop
   perform public.finish_push_job((j->>'id')::uuid,gen_random_uuid(),'sent');
   perform public.finish_push_job((j->>'id')::uuid,(j->>'lease_id')::uuid,'retry','FCM unavailable');
 end loop;
end $$;
reset role;
select public.test_assert((select count(*)=2 from public.push_jobs where state='pending' and attempts=1 and next_attempt>now()),'transient FCM errors back off without losing jobs');
select public.test_assert((select count(*)=1 from public.push_jobs where state='cancelled'),'closed ticket reminder cancelled');
update public.push_jobs set next_attempt=now();
-- Transfer a token to another logged-in account; old account jobs cannot leak.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.register_push_device('test-customer-one-token-1234567890');
reset role;
set local role service_role;
select public.test_assert(jsonb_array_length(public.claim_push_jobs())=0,'account switch cancels old recipient deliveries');
reset role;
select smartpark_private.process_deadlines();
select public.test_assert((select status='expired' from public.bookings where id='61000000-0000-0000-0000-000000000004'),'cron handles deadlines while every app is closed');
rollback;
