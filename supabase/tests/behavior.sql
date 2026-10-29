\set ON_ERROR_STOP on
begin;
create function public.test_assert(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if; end $$;
insert into auth.users(id,email,raw_user_meta_data) values
 ('10000000-0000-0000-0000-000000000001','customer1@test.invalid','{"name":"Customer One","role":"owner"}'),
 ('10000000-0000-0000-0000-000000000002','customer2@test.invalid','{}'),
 ('10000000-0000-0000-0000-000000000003','staff@test.invalid','{}'),
 ('10000000-0000-0000-0000-000000000004','owner@test.invalid','{}'),
 ('10000000-0000-0000-0000-000000000005','other-owner@test.invalid','{}');
select public.test_assert((select role='customer' from public.profiles where id='10000000-0000-0000-0000-000000000001'),'signup metadata cannot elevate role');
update public.profiles set role='owner' where id in ('10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.manage_lot('20000000-0000-0000-0000-000000000001','Test lot','Test address',true,2,16.05,108.2,0);
select public.manage_staff('20000000-0000-0000-0000-000000000001','staff@test.invalid','morning',true);
reset role;
-- deterministic IDs allow the separate concurrency test to reuse slot 2.
update public.parking_slots set id='30000000-0000-0000-0000-000000000001' where code='A001';
update public.parking_slots set id='30000000-0000-0000-0000-000000000002' where code='A002';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('40000000-0000-0000-0000-000000000001','vehicle.save',
 '{"id":"50000000-0000-0000-0000-000000000001","label":"Test car","plate":"43A12345","kind":"car","is_default":true,"expected_version":0}');
select public.apply_operation('40000000-0000-0000-0000-000000000002','booking.create',jsonb_build_object(
 'id','60000000-0000-0000-0000-000000000001','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','30000000-0000-0000-0000-000000000001','starts_at',now()+interval '2 minutes','ends_at',now()+interval '2 hours'));
-- The same operation ID must not produce a second booking.
select public.apply_operation('40000000-0000-0000-0000-000000000002','booking.create',jsonb_build_object(
 'id','60000000-0000-0000-0000-000000000001','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','30000000-0000-0000-0000-000000000001','starts_at',now()+interval '2 minutes','ends_at',now()+interval '2 hours'));
select public.test_assert((select count(*)=1 from public.bookings),'idempotent reservation');
select public.test_assert((select revision=2 from public.parking_slots where code='A001'),'public slot revision signals private reservation changes');
do $$ begin
 begin
  perform public.apply_operation('40000000-0000-0000-0000-000000000003','booking.create',jsonb_build_object(
    'id','60000000-0000-0000-0000-000000000002','vehicle_id','50000000-0000-0000-0000-000000000001',
    'slot_id','30000000-0000-0000-0000-000000000001','starts_at',now()+interval '3 minutes','ends_at',now()+interval '1 hour'));
  raise exception 'overlap should fail';
 exception when exclusion_violation then null; end;
 begin
  update public.profiles set role='owner' where id=auth.uid();
  raise exception 'role update should fail';
 exception when insufficient_privilege then null; end;
 begin
  perform public.apply_operation('40000000-0000-0000-0000-000000000005','staff.check_in',
    jsonb_build_object('booking_id','60000000-0000-0000-0000-000000000001','expected_version',1));
  raise exception 'customer checkin should fail';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.bookings),'another customer cannot read tickets or QR tokens');
select public.test_assert(jsonb_array_length(public.park_snapshot()->'lots')=1,'authenticated customers discover lots');
select public.test_assert((public.slot_availability('20000000-0000-0000-0000-000000000001',now(),now()+interval '1 hour')->0->>'occupied')::boolean,'availability reflects other customers without exposing bookings');
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare token text; begin
 select qr_token into token from public.bookings where id='60000000-0000-0000-0000-000000000001';
 begin
  perform public.apply_operation('40000000-0000-0000-0000-000000000006','staff.check_in',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',0,'qr_token',token,'plate','43A12345','occurred_at',now()));
  raise exception 'expected VERSION_CONFLICT';
 exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise; end if; end;
 begin
  perform public.apply_operation('40000000-0000-0000-0000-000000000007','staff.check_in',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',1,'qr_token',token,'plate','43A99999','occurred_at',now()));
  raise exception 'expected PLATE_MISMATCH';
 exception when raise_exception then if sqlerrm<>'PLATE_MISMATCH' then raise; end if; end;
 perform public.apply_operation('40000000-0000-0000-0000-000000000008','staff.check_in',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',1,'qr_token',token,'plate','43A12345','occurred_at',now()));
 perform public.apply_operation('40000000-0000-0000-0000-000000000008','staff.check_in',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',1,'qr_token',token,'plate','43A12345','occurred_at',now()));
 perform public.apply_operation('40000000-0000-0000-0000-000000000009','staff.check_out',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',2,'qr_token',token,'plate','43A12345','occurred_at',now()+interval '1 minute'));
 perform public.apply_operation('40000000-0000-0000-0000-000000000009','staff.check_out',jsonb_build_object(
   'booking_id','60000000-0000-0000-0000-000000000001','expected_version',2,'qr_token',token,'plate','43A12345','occurred_at',now()+interval '1 minute'));
end $$;
reset role;
select public.test_assert((select count(*)=1 and sum(amount)=15000 from public.payments),'one payment despite repeated checkout');
select public.test_assert((select count(*)=2 from public.parking_events),'one checkin and one checkout event');
select public.test_assert((select status='completed' and version=3 from public.bookings limit 1),'valid state machine');
select public.test_assert((select count(*)=11 from pg_class where relnamespace='public'::regnamespace and relkind='r' and relrowsecurity),'RLS enabled on every application table');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.payments),'unrelated owner cannot read revenue');
do $$ begin
 begin
  perform public.manage_staff('20000000-0000-0000-0000-000000000001','customer2@test.invalid','night',true);
  raise exception 'unrelated owner should fail';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Revoke staff then prove queued commands are rejected against current permissions.
update public.lot_staff set active=false;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.test_assert(not public.works_lot('20000000-0000-0000-0000-000000000001'),'revoked membership checked live');
reset role;
commit;
select 'SmartPark backend behavior assertions passed' as result;
