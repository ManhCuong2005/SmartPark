\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('15000000-0000-0000-0000-000000000001','extension-choice@test.invalid'),
 ('15000000-0000-0000-0000-000000000004','extension-choice-owner@test.invalid');
update public.profiles set role='owner' where id='15000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('25000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000004','Payment choices',10,10);
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('55000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000001','Car','43A95111','car');
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('15000000-0000-0000-0000-000000000001',100000,'extension-choice-credit',now());
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.reserve',jsonb_build_object(
   'id',gen_random_uuid(),'vehicle_id','55000000-0000-0000-0000-000000000001',
   'lot_id','25000000-0000-0000-0000-000000000001','starts_at',now(),'ends_at',now()+interval '1 hour'));
  raise exception 'Exactly 100k accepted for pay later';
 exception when raise_exception then if sqlerrm<>'PAY_LATER_BALANCE_REQUIRED' then raise; end if; end;
end $$;
reset role;
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('15000000-0000-0000-0000-000000000001',2000,'extension-choice-extra',now());
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('75000000-0000-0000-0000-000000000001','booking.reserve',jsonb_build_object(
 'id','65000000-0000-0000-0000-000000000001','vehicle_id','55000000-0000-0000-0000-000000000001',
 'lot_id','25000000-0000-0000-0000-000000000001','starts_at',now(),'ends_at',now()+interval '1 hour'));
reset role;
update public.bookings set status='parked',checked_in_at=now()-interval '30 minutes',starts_at=now()-interval '30 minutes'
 where id='65000000-0000-0000-0000-000000000001';
-- A legitimate 2,000đ earlier debit leaves exactly 100k available.
insert into public.payments(booking_id,amount,method,received_by) values
 ('65000000-0000-0000-0000-000000000001',2000,'wallet','15000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare payload jsonb:=jsonb_build_object('booking_id','65000000-0000-0000-0000-000000000001',
 'expected_version',1,'ends_at',now()+interval '2 hours'); kind text;
begin
 foreach kind in array array['booking.extend.deferred','booking.extend'] loop
  begin
   perform public.apply_operation(gen_random_uuid(),kind,payload);
   raise exception 'Exactly 100k accepted for deferred extension';
  exception when raise_exception then if sqlerrm<>'PAY_LATER_BALANCE_REQUIRED' then raise; end if; end;
 end loop;
end $$;
reset role;
-- Make the boundary exactly 100001 without a below-minimum provider top-up.
update public.payments set amount=1999 where booking_id='65000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert(public.wallet_topup_balance()=100001,'boundary fixture is 100001');
select public.apply_operation('75000000-0000-0000-0000-000000000002','booking.extend.deferred',jsonb_build_object(
 'booking_id','65000000-0000-0000-0000-000000000001','expected_version',1,'ends_at',now()+interval '2 hours'));
select public.test_assert(public.wallet_topup_balance()=100001,'deferred extension at 100001 does not debit');
reset role;
-- Clear the fixture debit; the parked visit is still entirely unpaid.
delete from public.payments where booking_id='65000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare payload jsonb:=jsonb_build_object('booking_id','65000000-0000-0000-0000-000000000001',
 'expected_version',2,'ends_at',now()+interval '3 hours','expected_amount',60000);
begin
 perform public.test_assert((public.booking_payment_quote('booking.extend.pay',payload)->>'amount')::integer=60000,
  'pay-now includes all unpaid original time plus extension');
 perform public.apply_operation('75000000-0000-0000-0000-000000000003','booking.extend.pay',payload);
 perform public.apply_operation('75000000-0000-0000-0000-000000000003','booking.extend.pay',payload);
 perform public.test_assert(public.wallet_topup_balance()=42000,'paid extension debits once and needs no 100k minimum');
end $$;
-- A previous deferred extension receipt still replays after balance falls below 100k.
select public.apply_operation('75000000-0000-0000-0000-000000000002','booking.extend.deferred',jsonb_build_object(
 'booking_id','65000000-0000-0000-0000-000000000001','expected_version',1,'ends_at',now()+interval '2 hours'));
reset role;
select public.test_assert((select prepaid and amount=60000 and paid_until=now()+interval '3 hours' and ends_at=paid_until
 from public.bookings where id='65000000-0000-0000-0000-000000000001'),'payment updates coverage, not just planned end');
-- Later deferred time must not become free when choosing pay-now again.
update public.bookings set ends_at=now()+interval '4 hours' where id='65000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert((public.booking_payment_quote('booking.extend.pay',jsonb_build_object(
 'booking_id','65000000-0000-0000-0000-000000000001','expected_version',3,'ends_at',now()+interval '5 hours'))->>'amount')::integer=30000,
 'prepaid quote includes unpaid deferred time from paid_until');
reset role;
rollback;
