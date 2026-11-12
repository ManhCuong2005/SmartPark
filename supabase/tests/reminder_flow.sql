\set ON_ERROR_STOP on
-- Actual customer/staff RPC chain on disposable PostgreSQL; no Cloud writes.
begin;
update public.lot_staff set active=true
 where user_id='10000000-0000-0000-0000-000000000003'
 and lot_id='20000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.register_push_device('flow-test-customer-device-token-123456789');
select public.apply_operation('46000000-0000-0000-0000-000000000001','booking.create',jsonb_build_object(
 'id','66000000-0000-0000-0000-000000000001','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','30000000-0000-0000-0000-000000000001','starts_at',now()+interval '2 minutes',
 'ends_at',now()+interval '20 minutes'));
select public.test_assert(not exists(select 1 from public.notifications
 where booking_id='66000000-0000-0000-0000-000000000001' and category='pickup_soon'),
 'unvisited reservation never receives a parked pickup reminder');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('46000000-0000-0000-0000-000000000002','staff.check_in',jsonb_build_object(
 'booking_id','66000000-0000-0000-0000-000000000001','expected_version',1,
 'qr_token',(select qr_token from public.bookings where id='66000000-0000-0000-0000-000000000001'),
 'plate','43A12345','occurred_at',now()));
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.park_snapshot();
select public.park_snapshot();
select public.test_assert((select count(*)=1 from public.notifications
 where booking_id='66000000-0000-0000-0000-000000000001' and category='pickup_soon'),
 'actual check-in inside reminder window creates exactly one inbox reminder');
select public.apply_operation('46000000-0000-0000-0000-000000000003','notifications.read','{}');
select public.test_assert((select read from public.notifications
 where booking_id='66000000-0000-0000-0000-000000000001' and category='pickup_soon'),
 'customer can read the generated reminder');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('46000000-0000-0000-0000-000000000004','staff.check_out',jsonb_build_object(
 'booking_id','66000000-0000-0000-0000-000000000001','expected_version',2,
 'qr_token',(select qr_token from public.bookings where id='66000000-0000-0000-0000-000000000001'),
 'plate','43A12345','occurred_at',now()+interval '1 minute'));
reset role;
select public.test_assert((select b.status='completed' and b.amount=p.amount
 from public.bookings b join public.payments p on p.booking_id=b.id
 where b.id='66000000-0000-0000-0000-000000000001'),
 'real checkout creates a matching server-computed payment');
set local role service_role;
do $$ declare jobs jsonb; begin
 jobs:=public.claim_push_jobs();
 perform public.test_assert(not exists(select 1 from jsonb_array_elements(jobs) j
   where j->>'category'='pickup_soon'),'completed real flow suppresses undelivered pickup push');
end $$;
reset role;
select public.test_assert((select j.state='cancelled' from public.push_jobs j
 join public.notifications n on n.id=j.notification_id
 where n.booking_id='66000000-0000-0000-0000-000000000001' and n.category='pickup_soon'),
 'obsolete push is cancelled without removing the read inbox history');
rollback;
