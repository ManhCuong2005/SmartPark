\set ON_ERROR_STOP on
begin;
select public.test_assert(smartpark_private.parking_fee(now(),now(),15000)=15000,'immediate checkout charges minimum one hour');
select public.test_assert(smartpark_private.parking_fee(now(),now()+interval '45 seconds',15000)=15000,'45 second visit is charged');
select public.test_assert(smartpark_private.parking_fee(now(),now()+interval '1 hour',15000)=15000,'exact hour is one unit');
select public.test_assert(smartpark_private.parking_fee(now(),now()+interval '1 hour 1 millisecond',15000)=30000,'fraction after hour rounds up');
update public.lot_staff set active=true where user_id='10000000-0000-0000-0000-000000000003';
insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,status,checked_in_at,hourly_rate,free_minutes)
values('64000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
 '50000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',
 '30000000-0000-0000-0000-000000000001','43A12345',now()-interval '45 seconds',now()+interval '1 hour',
 'parked',now()-interval '45 seconds',15000,15);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare payload jsonb; operation uuid:=gen_random_uuid(); result jsonb; begin
 payload:=jsonb_build_object('booking_id','64000000-0000-0000-0000-000000000001','expected_version',1,
  'qr_token',(select qr_token from public.bookings where id='64000000-0000-0000-0000-000000000001'),
  'plate','43A12345','occurred_at',now());
 result:=public.apply_operation(operation,'staff.check_out',payload);
 perform public.test_assert((result->>'amount')::integer=15000,'legacy grace on existing ticket does not waive the new fee');
 perform public.test_assert(public.apply_operation(operation,'staff.check_out',payload)=result,'checkout retry does not duplicate collection');
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.test_assert((select count(*)=1 and sum(amount)=15000 from public.payments
 where booking_id='64000000-0000-0000-0000-000000000001'),'owner sees exactly one paid checkout');
select public.test_assert((select sum((p->>'amount')::integer)=15000
 from jsonb_array_elements(public.park_snapshot()->'payments') p
 where p->>'booking_id'='64000000-0000-0000-0000-000000000001'),'admin snapshot contains collected revenue');
reset role;
rollback;
