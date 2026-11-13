\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('12000000-0000-0000-0000-000000000001','prepaid-customer@test.invalid'),
 ('12000000-0000-0000-0000-000000000002','prepaid-other@test.invalid'),
 ('12000000-0000-0000-0000-000000000003','prepaid-staff@test.invalid'),
 ('12000000-0000-0000-0000-000000000004','prepaid-owner@test.invalid');
update public.profiles set role='owner' where id='12000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000004','Prepaid test',1,1);
insert into public.lot_staff(lot_id,user_id) values
 ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('52000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','Car','43A81111','car'),
 ('52000000-0000-0000-0000-000000000002','12000000-0000-0000-0000-000000000002','Other','43A82222','car');
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('12000000-0000-0000-0000-000000000001',200000,'prepaid-fixture-credit',now()),
 ('12000000-0000-0000-0000-000000000002',20000,'prepaid-other-credit',now());

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$
declare payload jsonb:=jsonb_build_object('id','62000000-0000-0000-0000-000000000001',
 'lot_id','22000000-0000-0000-0000-000000000001','vehicle_id','52000000-0000-0000-0000-000000000001',
 'starts_at',now()+interval '1 hour','ends_at',now()+interval '2 hours','expected_amount',15000);
begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.create',payload);
  raise exception 'Unpaid creation accepted';
 exception when raise_exception then if sqlerrm<>'PAYMENT_REQUIRED' then raise; end if; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.pay',payload||'{"expected_amount":1}');
  raise exception 'Client-selected price accepted';
 exception when raise_exception then if sqlerrm<>'PRICE_CHANGED' then raise; end if; end;
 perform public.apply_operation('72000000-0000-0000-0000-000000000101','booking.pay',payload);
 perform public.apply_operation('72000000-0000-0000-0000-000000000101','booking.pay',payload);
 perform public.test_assert(public.wallet_topup_balance()=185000,'booking replay debits once');
 perform public.test_assert((select count(*)=1 from public.payments
  where booking_id='62000000-0000-0000-0000-000000000001'),'one payment per operation');
end $$;
reset role;

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.pay',jsonb_build_object(
   'id',gen_random_uuid(),'lot_id','22000000-0000-0000-0000-000000000001',
   'vehicle_id','52000000-0000-0000-0000-000000000002','starts_at',now()+interval '1 hour',
   'ends_at',now()+interval '2 hours','expected_amount',15000));
  raise exception 'Full lot accepted';
 exception when raise_exception then if sqlerrm<>'CAPACITY_FULL' then raise; end if; end;
 perform public.test_assert(public.wallet_topup_balance()=20000,'rejected reservation keeps funds');
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.cancel',
   '{"booking_id":"62000000-0000-0000-0000-000000000001","expected_version":1}');
  raise exception 'Foreign ticket cancelled';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('72000000-0000-0000-0000-000000000102','booking.cancel',
 '{"booking_id":"62000000-0000-0000-0000-000000000001","expected_version":1}');
select public.apply_operation('72000000-0000-0000-0000-000000000102','booking.cancel',
 '{"booking_id":"62000000-0000-0000-0000-000000000001","expected_version":1}');
select public.test_assert(public.wallet_topup_balance()=200000,'valid cancellation refunds wallet once');
select public.test_assert((select sum(amount)=0 from public.payments
 where booking_id='62000000-0000-0000-0000-000000000001'),'refund reverses revenue');
select public.apply_operation('72000000-0000-0000-0000-000000000103','booking.pay',jsonb_build_object(
 'id','62000000-0000-0000-0000-000000000002','lot_id','22000000-0000-0000-0000-000000000001',
 'vehicle_id','52000000-0000-0000-0000-000000000001','starts_at',now(),'ends_at',now()+interval '1 hour','expected_amount',15000));
reset role;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('72000000-0000-0000-0000-000000000104','staff.check_in',jsonb_build_object(
 'booking_id','62000000-0000-0000-0000-000000000002','plate','43A81111','expected_version',1,'occurred_at',now()));
reset role;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('72000000-0000-0000-0000-000000000105','booking.extend.pay',jsonb_build_object(
 'booking_id','62000000-0000-0000-0000-000000000002','expected_version',2,'ends_at',now()+interval '2 hours','expected_amount',15000));
select public.apply_operation('72000000-0000-0000-0000-000000000105','booking.extend.pay',jsonb_build_object(
 'booking_id','62000000-0000-0000-0000-000000000002','expected_version',2,'ends_at',now()+interval '2 hours','expected_amount',15000));
select public.test_assert(public.wallet_topup_balance()=170000,'extension replay debits once');
reset role;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('72000000-0000-0000-0000-000000000106','staff.check_out',jsonb_build_object(
 'booking_id','62000000-0000-0000-0000-000000000002','plate','43A81111','expected_version',3,'occurred_at',now()));
select public.apply_operation('72000000-0000-0000-0000-000000000107','staff.check_out',jsonb_build_object(
 'booking_id','62000000-0000-0000-0000-000000000002','plate','43A81111','expected_version',3,'occurred_at',now()));
reset role;
select public.test_assert((select amount=30000 and status='completed' from public.bookings
 where id='62000000-0000-0000-0000-000000000002'),'checkout keeps prepaid amount');
select public.test_assert((select count(*)=2 from public.payments
 where booking_id='62000000-0000-0000-0000-000000000002'),'no cash charge at checkout');

-- Provider settlement uses verified parameters only; a late capacity conflict
-- credits the wallet without creating a ticket or a revenue/debit entry.
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes) values
 ('62000000-0000-0000-0000-000000000003','12000000-0000-0000-0000-000000000002',
  '52000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','43A82222','car',
  now()+interval '1 day',now()+interval '25 hours',15000,0);
insert into public.wallet_topups(customer_id,amount,payment_link_id,booking_kind,booking_operation_id,booking_payload) values
 ('12000000-0000-0000-0000-000000000001',15000,'prepaid-qr-full','booking.pay',
  '72000000-0000-0000-0000-000000000108',jsonb_build_object(
   'id','62000000-0000-0000-0000-000000000004','lot_id','22000000-0000-0000-0000-000000000001',
   'vehicle_id','52000000-0000-0000-0000-000000000001','starts_at',now()+interval '1 day',
   'ends_at',now()+interval '25 hours','expected_amount',15000));
do $$ declare code bigint;
begin
 select order_code into code from public.wallet_topups where payment_link_id='prepaid-qr-full';
 perform public.test_assert(not public.settle_payos_topup(code,'wrong-link',15000),'wrong provider link rejected');
 perform public.test_assert(public.settle_payos_topup(code,'prepaid-qr-full',15000),'verified QR credited');
 perform public.test_assert(not public.settle_payos_topup(code,'prepaid-qr-full',15000),'QR replay is idempotent');
 perform public.test_assert((select booking_error='CAPACITY_FULL' and booking_result is null
  from public.wallet_topups where order_code=code),'full capacity keeps QR funds in wallet');
end $$;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert(public.wallet_topup_balance()=185000,'QR conflict retains full credit');
select public.test_assert(not has_function_privilege(current_user,
 'public.settle_payos_topup(bigint,text,integer)','execute'),'customer cannot verify their own payment');
reset role;

delete from public.bookings where id='62000000-0000-0000-0000-000000000003';
insert into public.wallet_topups(customer_id,amount,payment_link_id,booking_kind,booking_operation_id,booking_payload) values
 ('12000000-0000-0000-0000-000000000001',15000,'prepaid-qr-ok','booking.pay',
  '72000000-0000-0000-0000-000000000109',jsonb_build_object(
   'id','62000000-0000-0000-0000-000000000005','lot_id','22000000-0000-0000-0000-000000000001',
   'vehicle_id','52000000-0000-0000-0000-000000000001','starts_at',now()+interval '1 day',
   'ends_at',now()+interval '25 hours','expected_amount',15000));
do $$ declare code bigint;
begin
 select order_code into code from public.wallet_topups where payment_link_id='prepaid-qr-ok';
 perform public.settle_payos_topup(code,'prepaid-qr-ok',15000);
 perform public.settle_payos_topup(code,'prepaid-qr-ok',15000);
 perform public.test_assert((select booking_result->>'prepaid'='true' and booking_error is null
  from public.wallet_topups where order_code=code),'QR confirms prepaid ticket automatically');
 perform public.test_assert((select count(*)=1 and sum(amount)=15000 from public.payments
  where booking_id='62000000-0000-0000-0000-000000000005'),'QR books and debits once');
end $$;
rollback;
