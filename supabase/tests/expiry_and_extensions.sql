\set ON_ERROR_STOP on
begin;
update public.lot_staff set active=true where user_id='10000000-0000-0000-0000-000000000003';
insert into public.parking_slots(id,lot_id,code) values
 ('36000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','E001'),
 ('36000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','E002'),
 ('36000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','E003');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('56000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Expired','43A66661','car'),
 ('56000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Parked','43A66662','car'),
 ('56000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','Next','43A66663','car'),
 ('56000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','Other expired','43A66664','car');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,status,checked_in_at,hourly_rate,free_minutes) values
 ('66000000-0000-0000-0000-000000000011','10000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000001','43A66661',now()-interval '2 hours',now(),'confirmed',null,15000,0),
 ('66000000-0000-0000-0000-000000000012','10000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000002','43A66662',now()-interval '1 hour',now()+interval '9 minutes','parked',now()-interval '1 hour',15000,0),
 ('66000000-0000-0000-0000-000000000013','10000000-0000-0000-0000-000000000002','56000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000002','43A66663',now()+interval '30 minutes',now()+interval '90 minutes','confirmed',null,15000,0),
 ('66000000-0000-0000-0000-000000000014','10000000-0000-0000-0000-000000000002','56000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000003','43A66664',now()-interval '2 hours',now()-interval '1 minute','confirmed',null,15000,0);
insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
 select customer_id,'46000000-0000-0000-0000-000000000011','booking.create','{"id":"66000000-0000-0000-0000-000000000011"}',to_jsonb(b)
 from public.bookings b where id='66000000-0000-0000-0000-000000000011';
insert into public.notifications(user_id,booking_id,title,body)
 values('10000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000011','Created','Created');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.register_push_device('extension-test-device-token-1234567890');
reset role;
update public.bookings set ends_at=now()+interval '11 minutes' where id='66000000-0000-0000-0000-000000000012';
set local role authenticated;
select public.park_snapshot();
select public.test_assert(not exists(select 1 from public.notifications where category='pickup_soon' and booking_id='66000000-0000-0000-0000-000000000012'),'no pickup reminder before the 10-minute window');
reset role;
update public.bookings set ends_at=now()+interval '9 minutes' where id='66000000-0000-0000-0000-000000000012';
set local role authenticated;
select public.park_snapshot();
select public.test_assert(not exists(select 1 from public.bookings where id='66000000-0000-0000-0000-000000000011'),'unused ticket is physically removed at ends_at');
select public.test_assert((select count(*)=1 from public.notifications where category='pickup_soon' and booking_id='66000000-0000-0000-0000-000000000012' and body like '%gia hạn%'),'10-minute reminder explains extension');
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.extend',jsonb_build_object('booking_id','66000000-0000-0000-0000-000000000012','expected_version',1,'ends_at',now()+interval '1 hour'));
  raise exception 'Expected overlapping extension to fail';
 exception when exclusion_violation then perform public.test_assert(sqlerrm='SLOT_TIME_CONFLICT','extension respects the next reservation'); end;
end $$;
reset role;
select public.test_assert((select status='confirmed' from public.bookings where id='66000000-0000-0000-0000-000000000014'),'request-time cleanup respects user scope');
select public.test_assert((select result->>'deleted'='true' and not(result ? 'qr_token') from public.operation_receipts where operation_id='46000000-0000-0000-0000-000000000011'),'receipt loses QR and retains retry tombstone');
update public.bookings set status='cancelled' where id='66000000-0000-0000-0000-000000000013';
set local role authenticated;
do $$ declare payload jsonb; result jsonb; operation uuid:=gen_random_uuid(); begin
 payload:=jsonb_build_object('booking_id','66000000-0000-0000-0000-000000000012','expected_version',1,'ends_at',now()+interval '1 hour');
 result:=public.apply_operation(operation,'booking.extend',payload);
 perform public.test_assert((result->>'ends_at')::timestamptz=now()+interval '1 hour' and (result->>'version')::integer=2,'extension saves the new planned end');
 perform public.test_assert(public.apply_operation(operation,'booking.extend',payload)=result,'extension retry returns original receipt');
 result:=public.apply_operation('46000000-0000-0000-0000-000000000011','booking.create','{"id":"66000000-0000-0000-0000-000000000011"}');
 perform public.test_assert(result->>'deleted'='true','retry cannot resurrect a deleted reservation');
end $$;
reset role;
set local role service_role;
do $$ declare jobs jsonb; begin
 jobs:=public.claim_push_jobs();
 perform public.test_assert(not exists(select 1 from jsonb_array_elements(jobs) j where j->>'category'='pickup_soon'),'old reminder is cancelled after extension');
end $$;
reset role;
update public.bookings set ends_at=now()+interval '8 minutes' where id='66000000-0000-0000-0000-000000000012';
select smartpark_private.process_deadlines();
select smartpark_private.process_deadlines();
select public.test_assert((select count(*)=2 from public.notifications where category='pickup_soon' and booking_id='66000000-0000-0000-0000-000000000012'),'a new end gets a new reminder, each only once');
select public.test_assert(not exists(select 1 from public.bookings where id='66000000-0000-0000-0000-000000000014'),'cron purges other abandoned tickets while apps are closed');
update public.bookings set ends_at=now()-interval '1 minute' where id='66000000-0000-0000-0000-000000000012';
select smartpark_private.process_deadlines();
select public.test_assert((select status='parked' from public.bookings where id='66000000-0000-0000-0000-000000000012'),'overdue parked vehicle is never deleted');
select public.test_assert((select count(*)=1 from public.payments),'extension and purge never fabricate payments');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'staff.check_in','{"booking_id":"66000000-0000-0000-0000-000000000011","expected_version":1,"qr_token":"old","plate":"43A66661"}');
  raise exception 'Deleted QR must fail';
 exception when raise_exception then if sqlerrm<>'TICKET_NOT_FOUND' then raise; end if; end;
end $$;
reset role;
rollback;
