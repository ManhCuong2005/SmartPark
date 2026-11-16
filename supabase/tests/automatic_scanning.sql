\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('13000000-0000-0000-0000-000000000001','auto-customer@test.invalid'),
 ('13000000-0000-0000-0000-000000000002','auto-poor@test.invalid'),
 ('13000000-0000-0000-0000-000000000003','auto-staff@test.invalid'),
 ('13000000-0000-0000-0000-000000000004','auto-owner@test.invalid');
update public.profiles set role='owner' where id='13000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('23000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000004','Automatic test',10,10),
 ('23000000-0000-0000-0000-000000000002','13000000-0000-0000-0000-000000000004','Wrong lot',10,10);
insert into public.lot_staff(lot_id,user_id) values
 ('23000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000003'),
 ('23000000-0000-0000-0000-000000000002','13000000-0000-0000-0000-000000000003');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('53000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001','Car','43A93111','car'),
 ('53000000-0000-0000-0000-000000000002','13000000-0000-0000-0000-000000000002','Poor','43A93222','car');
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('13000000-0000-0000-0000-000000000001',100000,'auto-credit',now());

select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'booking.reserve',jsonb_build_object(
   'id',gen_random_uuid(),'vehicle_id','53000000-0000-0000-0000-000000000002',
   'lot_id','23000000-0000-0000-0000-000000000001','starts_at',now(),'ends_at',now()+interval '1 hour'));
  raise exception 'Unfunded pay-later booking accepted';
 exception when raise_exception then if sqlerrm<>'PAY_LATER_BALANCE_REQUIRED' then raise; end if; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',
   '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93111"}');
  raise exception 'Customer controlled a kiosk';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare payload jsonb:=jsonb_build_object('id','63000000-0000-0000-0000-000000000001',
 'vehicle_id','53000000-0000-0000-0000-000000000001','lot_id','23000000-0000-0000-0000-000000000001',
 'starts_at',now(),'ends_at',now()+interval '1 hour');
begin
 perform public.apply_operation('73000000-0000-0000-0000-000000000001','booking.reserve',payload);
 perform public.apply_operation('73000000-0000-0000-0000-000000000001','booking.reserve',payload);
 perform public.test_assert(public.wallet_topup_balance()=100000,'pay later does not debit at booking');
end $$;
reset role;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare payload jsonb:='{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93111"}'; result jsonb;
begin
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',payload||'{"lot_id":"23000000-0000-0000-0000-000000000002"}');
  raise exception 'Wrong-lot admission accepted';
 exception when raise_exception then if sqlerrm<>'VALID_TICKET_REQUIRED' then raise; end if; end;
 result:=public.apply_operation('73000000-0000-0000-0000-000000000002','kiosk.scan',payload);
 perform public.test_assert(result->>'action'='entered','first scan enters');
 perform public.test_assert(public.apply_operation('73000000-0000-0000-0000-000000000002','kiosk.scan',payload)=result,'lost entry acknowledgement replays entry');
 result:=public.apply_operation(gen_random_uuid(),'kiosk.scan',payload);
 perform public.test_assert(result->>'action'='duplicate','standing vehicle cannot become an immediate exit');
end $$;
reset role;

-- Move the recorded arrival back in this disposable fixture; production uses server time.
update public.bookings set checked_in_at=now()-interval '61 minutes',starts_at=now()-interval '61 minutes'
 where id='63000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000003','booking.extend.deferred',jsonb_build_object(
 'booking_id','63000000-0000-0000-0000-000000000001','expected_version',2,'ends_at',now()+interval '2 hours'));
select public.test_assert(public.wallet_topup_balance()=100000,'extension records time without debit');
reset role;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare payload jsonb:='{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93111"}'; result jsonb;
begin
 result:=public.apply_operation('73000000-0000-0000-0000-000000000004','kiosk.scan',payload);
 perform public.test_assert(result->>'action'='exited','second passage exits');
 perform public.test_assert((result->'booking'->>'amount')::integer=30000,'actual 61 minutes rounds to two hours');
 perform public.test_assert(public.apply_operation('73000000-0000-0000-0000-000000000004','kiosk.scan',payload)=result,'checkout replay is identical');
 perform public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',payload)->>'action'='duplicate','different scan ID cannot debit completed visit twice');
end $$;
reset role;
select public.test_assert((select count(*)=1 and sum(amount)=30000 from public.payments where booking_id='63000000-0000-0000-0000-000000000001'),'one wallet debit');
select public.test_assert((select count(*)=2 from public.parking_events where booking_id='63000000-0000-0000-0000-000000000001'),'exactly one entry and one exit event');
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert(public.wallet_topup_balance()=70000,'debit belongs to customer, not staff');
reset role;

-- Prepaid visit: extending the schedule must not extend the period already paid.
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,status,starts_at,ends_at,
 checked_in_at,hourly_rate,free_minutes,prepaid,paid_until,amount) values
 ('63000000-0000-0000-0000-000000000002','13000000-0000-0000-0000-000000000002',
 '53000000-0000-0000-0000-000000000002','23000000-0000-0000-0000-000000000001','43A93222','car','parked',
 now()-interval '2 hours',now()-interval '1 minute',now()-interval '2 hours',15000,0,true,now()-interval '1 minute',30000);
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('13000000-0000-0000-0000-000000000002',30000,'auto-prepaid-credit',now());
insert into public.payments(booking_id,amount,method,received_by) values
 ('63000000-0000-0000-0000-000000000002',30000,'wallet','13000000-0000-0000-0000-000000000002');
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',
   '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93222"}');
  raise exception 'Overdue vehicle exited without funds';
 exception when raise_exception then if sqlerrm<>'OVERDUE_INSUFFICIENT_BALANCE' then raise; end if; end;
end $$;
reset role;
select public.test_assert((select status='parked' and amount=30000 and checked_out_at is null from public.bookings
 where id='63000000-0000-0000-0000-000000000002'),'insufficient funds leaves visit parked and paid amount unchanged');
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000005','booking.extend.deferred',jsonb_build_object(
 'booking_id','63000000-0000-0000-0000-000000000002','expected_version',1,'ends_at',now()+interval '1 hour'));
reset role;
select public.test_assert((select paid_until=now()-interval '1 minute' and ends_at=now()+interval '1 hour'
 from public.bookings where id='63000000-0000-0000-0000-000000000002'),'deferred extension preserves paid coverage');
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('13000000-0000-0000-0000-000000000002',15000,'auto-extra-credit',now());
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation('73000000-0000-0000-0000-000000000006','kiosk.scan',
 '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93222"}');
reset role;
select public.test_assert((select status='completed' and amount=45000 and paid_until=now()-interval '1 minute'
 from public.bookings where id='63000000-0000-0000-0000-000000000002'),'checkout charges only one extra hour, not the base twice');
select public.test_assert((select count(*)=2 and sum(amount)=45000 from public.payments
 where booking_id='63000000-0000-0000-0000-000000000002'),'one original debit and one extra debit');

-- Validity window is strict for unattended admission.
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes) values
 ('63000000-0000-0000-0000-000000000003','13000000-0000-0000-0000-000000000001',
 '53000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','43A93111','car',
 now()+interval '1 hour',now()+interval '2 hours',15000,0);
update public.bookings set checked_out_at=now()-interval '1 hour' where id='63000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',
   '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93111"}');
  raise exception 'Future ticket accepted';
 exception when raise_exception then if sqlerrm<>'VALID_TICKET_REQUIRED' then raise; end if; end;
end $$;
reset role;
-- Reminder dedupe follows the extended end, and postpaid overdue is payable.
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,status,starts_at,ends_at,
 checked_in_at,hourly_rate,free_minutes) values
 ('63000000-0000-0000-0000-000000000004','13000000-0000-0000-0000-000000000002',
 '53000000-0000-0000-0000-000000000002','23000000-0000-0000-0000-000000000001','43A93222','car','parked',
 now()-interval '61 minutes',now()+interval '5 minutes',now()-interval '61 minutes',15000,0);
select smartpark_private.process_deadlines('13000000-0000-0000-0000-000000000002');
select smartpark_private.process_deadlines('13000000-0000-0000-0000-000000000002');
select public.test_assert((select count(*)=1 from public.notifications where
 booking_id='63000000-0000-0000-0000-000000000004' and category='pickup_soon'),'pickup reminder deduped');
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.apply_operation(gen_random_uuid(),'booking.extend.deferred',jsonb_build_object(
 'booking_id','63000000-0000-0000-0000-000000000004','expected_version',1,'ends_at',now()+interval '6 minutes'));
reset role;
select smartpark_private.process_deadlines('13000000-0000-0000-0000-000000000002');
select public.test_assert((select count(*)=2 from public.notifications where
 booking_id='63000000-0000-0000-0000-000000000004' and category='pickup_soon'),'extension creates a new reminder deadline');
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',
   '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93222"}');
  raise exception 'Postpaid exit accepted without balance';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_BALANCE' then raise; end if; end;
end $$;
reset role;
update public.bookings set ends_at=now()-interval '1 minute' where id='63000000-0000-0000-0000-000000000004';
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('13000000-0000-0000-0000-000000000002',30000,'auto-postpaid-overdue-credit',now());
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation(gen_random_uuid(),'kiosk.scan',jsonb_build_object(
 'lot_id','23000000-0000-0000-0000-000000000001','plate','43A93222','amount',1,'occurred_at',now()-interval '1 hour'));
reset role;
select public.test_assert((select status='completed' and amount=30000 and checked_out_at=now() from public.bookings
 where id='63000000-0000-0000-0000-000000000004'),'funded overdue exit uses server time and tariff, ignoring device fee/time');

-- Fully prepaid on-time exits need no extra wallet funds.
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('13000000-0000-0000-0000-000000000002',15000,'auto-prepaid-ontime-credit',now());
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.apply_operation(gen_random_uuid(),'booking.pay',jsonb_build_object(
 'id','63000000-0000-0000-0000-000000000005','lot_id','23000000-0000-0000-0000-000000000001',
 'vehicle_id','53000000-0000-0000-0000-000000000002','starts_at',now(),'ends_at',now()+interval '1 hour','expected_amount',15000));
select public.test_assert(public.wallet_topup_balance()=0,'entire available balance used for prepayment');
reset role;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation(gen_random_uuid(),'kiosk.scan',
 '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93222"}');
reset role;
update public.bookings set checked_in_at=now()-interval '1 minute',starts_at=now()-interval '1 minute'
 where id='63000000-0000-0000-0000-000000000005';
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select public.apply_operation(gen_random_uuid(),'kiosk.scan',
 '{"lot_id":"23000000-0000-0000-0000-000000000001","plate":"43A93222"}');
reset role;
select public.test_assert((select status='completed' and amount=15000 from public.bookings
 where id='63000000-0000-0000-0000-000000000005'),'prepaid on-time exit does not charge again');

-- Expiring a pay-later ticket also expires its original receipt.
insert into public.operation_receipts(actor_id,operation_id,kind,payload,result)
 select customer_id,'73000000-0000-0000-0000-000000000099','booking.reserve','{}',to_jsonb(b)-'qr_token'
 from public.bookings b where id='63000000-0000-0000-0000-000000000003';
update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour'
 where id='63000000-0000-0000-0000-000000000003';
select smartpark_private.expire_no_shows('13000000-0000-0000-0000-000000000001');
select public.test_assert((select result->>'status'='expired' and result->>'deleted'='true'
 from public.operation_receipts where operation_id='73000000-0000-0000-0000-000000000099'),'expired receipt cannot resurrect a deleted reservation');
rollback;
