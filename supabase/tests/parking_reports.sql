\set ON_ERROR_STOP on
begin;
create function public.assert_reject(p_sql text,p_error text) returns void language plpgsql as $$
begin
 begin execute p_sql;
 exception when others then
  if sqlerrm=p_error then return; end if;
  raise;
 end;
 raise exception 'Expected rejection: %',p_error;
end $$;
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('22000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','Report lot',2,2);
insert into public.lot_staff(lot_id,user_id) values('22000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,status,checked_in_at,hourly_rate,free_minutes)
 values('62000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',
 '22000000-0000-0000-0000-000000000001','43A10101','car',now()-interval '10 minutes',now()+interval '9 minutes','parked',now()-interval '10 minutes',15000,0);
select smartpark_private.process_deadlines();
select smartpark_private.process_deadlines();
select public.test_assert((select count(*)=1 from public.notifications where booking_id='62000000-0000-0000-0000-000000000001' and category='pickup_soon'),'new ticket reminder deduplicated');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000001','booking.extend',jsonb_build_object('booking_id','62000000-0000-0000-0000-000000000001','expected_version',1,'ends_at',now()+interval '1 hour'));
reset role;
select smartpark_private.process_deadlines();
select public.test_assert((select ends_at>now()+interval '50 minutes' from public.bookings where id='62000000-0000-0000-0000-000000000001'),'extension reschedules deadline');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000002','report.create',
 '{"id":"63000000-0000-0000-0000-000000000001","lot_id":"22000000-0000-0000-0000-000000000001","plate":"43a-101.01","description":"Đỗ chắn lối đi"}');
select public.apply_operation('73000000-0000-0000-0000-000000000002','report.create',
 '{"id":"63000000-0000-0000-0000-000000000001","lot_id":"22000000-0000-0000-0000-000000000001","plate":"43a-101.01","description":"Đỗ chắn lối đi"}');
select public.test_assert((select count(*)=1 from public.report_events),'lost-ACK report creates one history event');
select public.test_assert((select count(*)=0 from public.profiles where id='10000000-0000-0000-0000-000000000001'),'reporter cannot read vehicle owner PII');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'report.request_move','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":1}')$q$,'FORBIDDEN');
select public.assert_reject($q$select public.resolve_plate('22000000-0000-0000-0000-000000000001','43A10101')$q$,'FORBIDDEN');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'booking.extend','{"booking_id":"62000000-0000-0000-0000-000000000001","expected_version":2}')$q$,'FORBIDDEN');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'staff.check_out','{"booking_id":"62000000-0000-0000-0000-000000000001"}')$q$,'FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.parking_reports),'other owner sees no report');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'report.assign','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":1,"staff_id":"10000000-0000-0000-0000-000000000003"}')$q$,'FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.parking_reports),'unassigned staff sees no report');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'report.progress','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":1,"status":"resolved"}')$q$,'FORBIDDEN');
select public.test_assert((select count(*)=0 from public.profiles where id='10000000-0000-0000-0000-000000000001'),'staff ticket lookup exposes no owner profile');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000003','report.request_move','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":1}');
select public.apply_operation('73000000-0000-0000-0000-000000000003','report.request_move','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":1}');
select public.apply_operation('73000000-0000-0000-0000-000000000004','report.assign','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":2,"staff_id":"10000000-0000-0000-0000-000000000003"}');
reset role;
select public.test_assert((select count(*)=1 from public.notifications where category='move_requested'),'move request notified once');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.test_assert((select count(*)=1 from public.parking_reports),'assigned staff reads report');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'report.request_move','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":3}')$q$,'FORBIDDEN');
select public.apply_operation('73000000-0000-0000-0000-000000000005','report.progress','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":3,"status":"in_progress"}');
select public.apply_operation('73000000-0000-0000-0000-000000000006','report.progress','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":4,"status":"resolved"}');
select public.assert_reject($q$select public.apply_operation(gen_random_uuid(),'report.progress','{"report_id":"63000000-0000-0000-0000-000000000001","expected_version":5,"status":"in_progress"}')$q$,'INVALID_STATE');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.test_assert(jsonb_array_length(public.park_snapshot()->'reports')=1,'reporter can read resolved report');
select public.test_assert(jsonb_array_length(public.park_snapshot()->'report_events')=5,'reporter reads processing history');
reset role;
-- Expiry without a historical slot; repeated maintenance deletes once and preserves parked ticket.
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes)
 values('62000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000002',
 '22000000-0000-0000-0000-000000000001','43A20202','car',now()-interval '2 hours',now()-interval '1 hour',15000,0);
select smartpark_private.process_deadlines();
select smartpark_private.process_deadlines();
select public.test_assert(not exists(select 1 from public.bookings where id='62000000-0000-0000-0000-000000000002'),'slot-free unused ticket deleted');
select public.test_assert((select count(*)=1 from public.notifications where dedupe_key='booking_expired:62000000-0000-0000-0000-000000000002'),'expiry returned capacity once');
select public.test_assert(exists(select 1 from public.bookings where id='62000000-0000-0000-0000-000000000001'),'parked ticket preserved');
rollback;
