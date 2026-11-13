\set ON_ERROR_STOP on
begin;
select public.test_assert((select count(*)=0 from public.bookings where vehicle_kind is null),'legacy kinds backfilled from actual vehicles');
select public.test_assert((select car_capacity=2 and motorcycle_capacity=2 from public.parking_lots limit 1),'owner-approved capacity conversion');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.manage_lot('21000000-0000-0000-0000-000000000001','Capacity test','Test',true,1,1);
select public.manage_staff('21000000-0000-0000-0000-000000000001','staff@test.invalid','morning',true);
reset role;
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('51000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','One','43A10101','car'),
 ('51000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Two','43A20202','car'),
 ('51000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','Bike','43B130303','motorcycle');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('71000000-0000-0000-0000-000000000001','booking.create',jsonb_build_object(
 'id','61000000-0000-0000-0000-000000000001','lot_id','21000000-0000-0000-0000-000000000001',
 'vehicle_id','51000000-0000-0000-0000-000000000001','starts_at',now()-interval '1 minute','ends_at',now()+interval '30 minutes'));
select public.test_assert((public.booking_availability('21000000-0000-0000-0000-000000000001',now(),now()+interval '1 hour')->'capacities'->0->>'remaining')::int=0,'availability exposes full car capacity');
select public.apply_operation('71000000-0000-0000-0000-000000000003','booking.create',jsonb_build_object(
 'id','61000000-0000-0000-0000-000000000003','lot_id','21000000-0000-0000-0000-000000000001',
 'vehicle_id','51000000-0000-0000-0000-000000000003','starts_at',now(),'ends_at',now()+interval '1 hour'));
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.create',jsonb_build_object('id',gen_random_uuid(),
   'lot_id','21000000-0000-0000-0000-000000000001','vehicle_id','51000000-0000-0000-0000-000000000002','starts_at',now(),'ends_at',now()+interval '1 hour'));
  raise exception 'full capacity accepted';
 exception when raise_exception then if sqlerrm<>'CAPACITY_FULL' then raise; end if; end;
end $$;
-- Adjacent half-open reservations do not consume two slots.
select public.apply_operation('71000000-0000-0000-0000-000000000002','booking.create',jsonb_build_object(
 'id','61000000-0000-0000-0000-000000000002','lot_id','21000000-0000-0000-0000-000000000001',
 'vehicle_id','51000000-0000-0000-0000-000000000002','starts_at',now()+interval '30 minutes','ends_at',now()+interval '2 hours'));
reset role;
select public.test_assert(smartpark_private.capacity_used('21000000-0000-0000-0000-000000000001','car',now(),now()+interval '3 hours')=1,'peak occupancy uses simultaneous tickets');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
do $$ begin
 begin
  perform public.manage_lot('21000000-0000-0000-0000-000000000001','Capacity test','Test',true,0,1,null,null,1);
  raise exception 'conflicting capacity reduction accepted';
 exception when raise_exception then if sqlerrm<>'CAPACITY_CONFLICT' then raise; end if; end;
end $$;
select public.manage_lot('21000000-0000-0000-0000-000000000001','Capacity test','Test',true,1,1,null,null,1);
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.test_assert(public.resolve_plate('21000000-0000-0000-0000-000000000001','43a-101.01')->>'id'='61000000-0000-0000-0000-000000000001','normalized plate lookup');
select public.apply_operation('72000000-0000-0000-0000-000000000001','staff.check_in',jsonb_build_object(
 'booking_id','61000000-0000-0000-0000-000000000001','plate','43a-101.01','expected_version',1,'occurred_at',now()));
select public.apply_operation('72000000-0000-0000-0000-000000000002','staff.check_in',jsonb_build_object(
 'booking_id','61000000-0000-0000-0000-000000000001','plate','43A10101','expected_version',1,'occurred_at',now()));
select public.test_assert((select count(*)=1 from public.parking_events where booking_id='61000000-0000-0000-0000-000000000001'),'rescan creates one entry event');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.extend',jsonb_build_object('booking_id','61000000-0000-0000-0000-000000000001','expected_version',2,'ends_at',now()+interval '3 hours'));
  raise exception 'full extension accepted';
 exception when raise_exception then if sqlerrm<>'CAPACITY_FULL' then raise; end if; end;
end $$;
reset role;
update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 minute',checked_in_at=now()-interval '2 hours'
 where id='61000000-0000-0000-0000-000000000001';
select smartpark_private.process_deadlines();
select smartpark_private.process_deadlines();
select public.test_assert(smartpark_private.capacity_used('21000000-0000-0000-0000-000000000001','car',now()+interval '3 hours',now()+interval '4 hours')=1,'overdue parked vehicle retains future capacity until checkout');
select public.test_assert((select count(*)=1 from public.notifications where booking_id='61000000-0000-0000-0000-000000000001' and category='pickup_overdue'),'deadline repeat deduplicated');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('72000000-0000-0000-0000-000000000003','staff.check_out',jsonb_build_object(
 'booking_id','61000000-0000-0000-0000-000000000001','plate','43A10101','expected_version',2,'occurred_at',now()));
select public.apply_operation('72000000-0000-0000-0000-000000000004','staff.check_out',jsonb_build_object(
 'booking_id','61000000-0000-0000-0000-000000000001','plate','43A10101','expected_version',2,'occurred_at',now()));
reset role;
select public.test_assert((select count(*)=1 and min(amount)=30000 from public.payments where booking_id='61000000-0000-0000-0000-000000000001'),'repeat checkout: one actual-time payment');
rollback;
-- Fixtures for genuinely independent users/plates contesting one last slot.
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('51000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Race one','43A10101','car'),
 ('51000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Race two','43A20202','car');
update public.parking_lots set car_capacity=1 where id='20000000-0000-0000-0000-000000000001';
