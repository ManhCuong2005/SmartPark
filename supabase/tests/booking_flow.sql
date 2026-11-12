\set ON_ERROR_STOP on
begin;
update public.lot_staff set active=true where user_id='10000000-0000-0000-0000-000000000003';
insert into public.parking_slots(id,lot_id,code) values
 ('32000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','B001'),
 ('32000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','B002'),
 ('32000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','B003'),
 ('32000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','B004');
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('52000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Parked','43A55551','car'),
 ('52000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Late','43A55552','car'),
 ('52000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','No show','43A55553','car'),
 ('52000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','Future','43A55554','car');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,status,checked_in_at,hourly_rate,free_minutes) values
 ('62000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','43A55551',now()-interval '3 hours',now()-interval '1 hour','parked',now()-interval '3 hours',15000,0),
 ('62000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000002','43A55552',now()-interval '121 minutes',now()-interval '1 minute','confirmed',null,15000,0),
 ('62000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000003','43A55553',now()-interval '3 hours',now()-interval '1 hour','confirmed',null,15000,0),
 ('62000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000004','43A55554',now()-interval '179 minutes',now()-interval '59 minutes','confirmed',null,15000,0);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert((select not (s->>'occupied')::boolean
 from jsonb_array_elements(public.slot_availability('20000000-0000-0000-0000-000000000001',now()+interval '1 day',now()+interval '26 hours')) s
 where s->>'code'='B001'),'overdue parked vehicle today does not block tomorrow');
select public.test_assert((select (s->>'occupied')::boolean
 from jsonb_array_elements(public.slot_availability('20000000-0000-0000-0000-000000000001',now(),now()+interval '2 hours')) s
 where s->>'code'='B001'),'overdue parked vehicle still blocks immediate booking');
select public.test_assert((select (s->>'occupied')::boolean
 from jsonb_array_elements(public.slot_availability('20000000-0000-0000-0000-000000000001',now(),now()+interval '2 hours')) s
 where s->>'code'='B002'),'unvisited ticket is held during the one-hour grace period');
select public.apply_operation(gen_random_uuid(),'booking.create',jsonb_build_object(
 'id','62000000-0000-0000-0000-000000000005','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','32000000-0000-0000-0000-000000000001','starts_at',now()+interval '1 day','ends_at',now()+interval '26 hours'));
-- Request-time cleanup frees another customer's no-show, even without cron.
select public.apply_operation(gen_random_uuid(),'booking.create',jsonb_build_object(
 'id','62000000-0000-0000-0000-000000000006','vehicle_id','50000000-0000-0000-0000-000000000001',
 'slot_id','32000000-0000-0000-0000-000000000003','starts_at',now(),'ends_at',now()+interval '1 hour'));
select public.park_snapshot();
select public.test_assert((select status='confirmed' from public.bookings where id='62000000-0000-0000-0000-000000000002'),
 'snapshot must not expire a late arrival within grace');
reset role;
select public.test_assert((select status='expired' and amount=0 and checked_out_at is null and version=2
 from public.bookings where id='62000000-0000-0000-0000-000000000003'),'exactly one hour after end is expired without revenue');
select smartpark_private.process_deadlines();
select smartpark_private.process_deadlines();
select public.test_assert((select status='confirmed' from public.bookings where id='62000000-0000-0000-0000-000000000004'),
 '59 minutes after end is still eligible');
select public.test_assert((select status='parked' from public.bookings where id='62000000-0000-0000-0000-000000000001'),
 'scheduler never removes a vehicle physically in the lot');
select public.test_assert((select count(*)=1 from public.notifications where booking_id='62000000-0000-0000-0000-000000000003'),
 'no-show notification is sent once across request and scheduler');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare token text; command uuid:=gen_random_uuid(); payload jsonb; result jsonb; begin
 select qr_token into token from public.bookings where id='62000000-0000-0000-0000-000000000002';
 payload:=jsonb_build_object('booking_id','62000000-0000-0000-0000-000000000002','expected_version',1,
  'qr_token',token,'plate','43A55552','occurred_at',now());
 result:=public.apply_operation(command,'staff.check_in',payload);
 perform public.test_assert(result->>'status'='parked' and (result->>'starts_at')::timestamptz=now()
  and (result->>'ends_at')::timestamptz=now()+interval '2 hours','late admission shifts safely by the original duration');
 perform public.test_assert(public.apply_operation(command,'staff.check_in',payload)=result,'late check-in remains idempotent');
 perform public.apply_operation(gen_random_uuid(),'staff.check_out',jsonb_build_object(
  'booking_id','62000000-0000-0000-0000-000000000002','expected_version',2,
  'qr_token',token,'plate','43A55552','occurred_at',now()+interval '1 minute'));
 perform public.test_assert((select amount=15000 from public.bookings where id='62000000-0000-0000-0000-000000000002'),
  'fees use actual arrival, not the missed scheduled start');
end $$;
reset role;
select public.test_assert((select amount=15000 from public.payments where booking_id='62000000-0000-0000-0000-000000000002'),
 'late checkout records the actual fee in payments');
-- A legacy next reservation may already start inside the grace period. A late
-- check-in must fail atomically if extending would collide with that booking.
update public.bookings set status='confirmed',starts_at=now()-interval '121 minutes',ends_at=now()-interval '1 minute',
 checked_in_at=null,checked_out_at=null where id='62000000-0000-0000-0000-000000000002';
insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,hourly_rate,free_minutes)
 values('62000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000002',
 '52000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001',
 '32000000-0000-0000-0000-000000000002','43A55554',now()+interval '1 hour',now()+interval '3 hours',15000,0);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'staff.check_in',jsonb_build_object(
   'booking_id','62000000-0000-0000-0000-000000000002','expected_version',3,
   'qr_token',(select qr_token from public.bookings where id='62000000-0000-0000-0000-000000000002'),
   'plate','43A55552','occurred_at',now()));
  raise exception 'Late admission must not steal a future reservation';
 exception when raise_exception then if sqlerrm<>'SLOT_UNAVAILABLE' then raise; end if; end;
end $$;
reset role;
select public.test_assert((select status='confirmed' and ends_at=now()-interval '1 minute'
 from public.bookings where id='62000000-0000-0000-0000-000000000002'),'failed extension leaves original ticket intact');
rollback;
