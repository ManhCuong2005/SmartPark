-- Committed fixtures for two independent sessions in the disposable test DB.
\set ON_ERROR_STOP on
insert into auth.users(id,email) values
 ('14000000-0000-0000-0000-000000000001','scan-race-customer@test.invalid'),
 ('14000000-0000-0000-0000-000000000003','scan-race-staff@test.invalid'),
 ('14000000-0000-0000-0000-000000000004','scan-race-owner@test.invalid');
update public.profiles set role='owner' where id='14000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('24000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000004','Race one',10,10),
 ('24000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000004','Race two',10,10);
insert into public.lot_staff(lot_id,user_id) values
 ('24000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000003'),
 ('24000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000003');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('54000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000001','One','43A94111','car'),
 ('54000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000001','Two','43A94222','car');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,status,starts_at,ends_at,checked_in_at,hourly_rate,free_minutes) values
 ('64000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000001','54000000-0000-0000-0000-000000000001',
 '24000000-0000-0000-0000-000000000001','43A94111','car','parked',now()-interval '30 minutes',now()+interval '1 hour',now()-interval '30 minutes',15000,0),
 ('64000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000001','54000000-0000-0000-0000-000000000002',
 '24000000-0000-0000-0000-000000000002','43A94222','car','parked',now()-interval '30 minutes',now()+interval '1 hour',now()-interval '30 minutes',15000,0);
insert into public.wallet_topups(customer_id,amount,payment_link_id,paid_at) values
 ('14000000-0000-0000-0000-000000000001',15000,'auto-race-credit',now());
