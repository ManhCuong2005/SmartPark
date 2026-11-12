-- LOCAL TEST DATABASE ONLY. Never run this fixture in Supabase Cloud.
\set ON_ERROR_STOP on
select set_config('smartpark.test.owner', :'demo_owner', false);
select set_config('smartpark.test.customer', :'demo_customer', false);
select set_config('smartpark.test.staff', :'demo_staff', false);

begin;
do $$
declare
  owner_uid uuid := (select id from public.profiles where email=current_setting('smartpark.test.owner'));
  customer_uid uuid := (select id from public.profiles where email=current_setting('smartpark.test.customer'));
  staff_uid uuid := (select id from public.profiles where email=current_setting('smartpark.test.staff'));
begin
  perform public.test_assert((select role='owner' from public.profiles where id=owner_uid),'seed retains owner role');
  perform public.test_assert((select count(*)=8 from public.parking_lots where owner_id=owner_uid),'8 demo lots');
  perform public.test_assert((select count(*)=320 from public.parking_slots s join public.parking_lots l on l.id=s.lot_id where l.owner_id=owner_uid),'320 slots');
  perform public.test_assert((select count(*)=16 from public.parking_slots s join public.parking_lots l on l.id=s.lot_id where l.owner_id=owner_uid and not s.enabled),'16 unavailable slots');
  perform public.test_assert((select count(*)=24 from public.vehicles where user_id=customer_uid),'24 vehicles');
  perform public.test_assert((select count(*)=792 from public.bookings where customer_id=customer_uid),'792 bookings');
  perform public.test_assert((select count(*)=736 from public.bookings where customer_id=customer_uid and status='completed'),'736 completed');
  perform public.test_assert((select count(*)=8 from public.bookings where customer_id=customer_uid and status='parked'),'8 parked');
  perform public.test_assert((select count(*)=16 from public.bookings where customer_id=customer_uid and status='confirmed'),'16 confirmed');
  perform public.test_assert((select count(*)=32 from public.bookings where customer_id=customer_uid and status='cancelled'),'32 cancelled');
  perform public.test_assert((select count(*)=736 from public.payments p join public.bookings b on b.id=p.booking_id where b.customer_id=customer_uid),'736 payments');
  perform public.test_assert((select count(*)=1480 from public.parking_events e join public.bookings b on b.id=e.booking_id where b.customer_id=customer_uid),'1480 audit events');
  perform public.test_assert(not exists(select 1 from public.bookings b join public.payments p on p.booking_id=b.id where b.customer_id=customer_uid and (b.status<>'completed' or b.amount<>p.amount or b.checked_out_at<>p.paid_at)),'payment matches completed ticket');
  perform public.test_assert(not exists(select 1 from public.bookings b where b.customer_id=customer_uid and b.status='completed' and b.amount<>
    case when ceil(extract(epoch from (b.checked_out_at-b.checked_in_at))/60)<=b.free_minutes then 0
    else ceil(ceil(extract(epoch from (b.checked_out_at-b.checked_in_at))/60)/60.0)::integer*b.hourly_rate end),'fees match server rounding');
  perform public.test_assert((select count(*)>=1 from public.payments p join public.bookings b on b.id=p.booking_id where b.customer_id=customer_uid and p.amount=0),'free-minute example');
  perform public.test_assert(not exists(select 1 from public.bookings b join public.vehicles v on v.id=b.vehicle_id join public.parking_slots s on s.id=b.slot_id
    where b.customer_id=customer_uid and (b.customer_id<>v.user_id or b.plate<>v.plate or b.lot_id<>s.lot_id)),'consistent ownership, plates and slots');
  perform public.test_assert(not exists(select 1 from public.bookings b join public.bookings c on b.vehicle_id=c.vehicle_id and b.id<c.id
    where b.customer_id=customer_uid and b.status in ('completed','parked') and c.status in ('completed','parked')
    and tstzrange(b.checked_in_at,coalesce(b.checked_out_at,b.ends_at),'[)') && tstzrange(c.checked_in_at,coalesce(c.checked_out_at,c.ends_at),'[)')),'historical and live vehicle visits do not overlap');
  perform public.test_assert((select count(*)=8 from public.lot_staff s join public.parking_lots l on l.id=s.lot_id where l.owner_id=owner_uid and s.user_id=staff_uid),'assigned staff');
end $$;

-- An unrelated signed-in user discovers lots, but cannot read private tickets.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.bookings),'stranger cannot see seeded QR tickets');
select public.test_assert((select count(*)=0 from public.payments),'stranger cannot see seeded payments');
select public.test_assert((select count(*)>=8 from public.parking_lots where name like '[DEMO]%'),'customers can discover demo lots');
reset role;

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where email=current_setting('smartpark.test.customer')),true);
set local role authenticated;
select public.test_assert(jsonb_array_length(public.park_snapshot()->'bookings')=792,'customer snapshot loads complete demo');
reset role;

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where email=current_setting('smartpark.test.staff')),true);
set local role authenticated;
do $$
declare b public.bookings;
begin
  select * into b from public.bookings where status='parked' order by id limit 1;
  perform public.test_assert(b.id is not null,'staff can see a parked demo vehicle');
  perform public.apply_operation(gen_random_uuid(),'staff.check_out',jsonb_build_object(
    'booking_id',b.id,'expected_version',b.version,'qr_token',b.qr_token,'plate',b.plate,'occurred_at',now()));
  perform public.test_assert((select status='completed' from public.bookings where id=b.id),'seeded parked ticket checks out');
  select * into b from public.bookings where status='confirmed' and starts_at<now() and ends_at>now() order by id limit 1;
  perform public.test_assert(b.id is not null and b.qr_token ~ '^[a-f0-9]{64}$','usable demo QR token');
  perform public.apply_operation(gen_random_uuid(),'staff.check_in',jsonb_build_object(
    'booking_id',b.id,'expected_version',b.version,'qr_token',b.qr_token,'plate',b.plate,'occurred_at',now()));
  perform public.test_assert((select status='parked' from public.bookings where id=b.id),'seeded confirmed ticket checks in');
end $$;
reset role;

-- Mutations below must survive the next seed execution.
update public.parking_slots set enabled=false where id=(select s.id from public.parking_slots s
  join public.parking_lots l on l.id=s.lot_id where l.owner_id=(select id from public.profiles where email=current_setting('smartpark.test.owner')) and s.code='A020' limit 1);
update public.parking_lots set car_rate=car_rate+1000,version=version+1
where owner_id=(select id from public.profiles where email=current_setting('smartpark.test.owner'));
update public.lot_staff set active=false where user_id=(select id from public.profiles where email=current_setting('smartpark.test.staff'));
update public.notifications set read=true where user_id=(select id from public.profiles where email=current_setting('smartpark.test.customer'));
commit;
