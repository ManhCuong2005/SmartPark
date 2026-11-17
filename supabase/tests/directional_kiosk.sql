\set ON_ERROR_STOP on
begin;
select public.test_assert((select relrowsecurity from pg_class
 where oid='smartpark_private.kiosk_sessions'::regclass),'camera sessions have RLS enabled');
select public.test_assert(not has_table_privilege('authenticated',
 'smartpark_private.kiosk_sessions','SELECT,INSERT,UPDATE,DELETE'),'clients cannot access camera sessions directly');
select public.test_assert(not has_table_privilege('anon',
 'smartpark_private.kiosk_sessions','SELECT,INSERT,UPDATE,DELETE'),'anonymous clients cannot access camera sessions directly');
insert into auth.users(id,email) values
 ('17000000-0000-0000-0000-000000000001','direction-customer@test.invalid'),
 ('17000000-0000-0000-0000-000000000004','direction-owner@test.invalid');
update public.profiles set role='owner' where id='17000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('27000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000004','Directional lot',10,10),
 ('27000000-0000-0000-0000-000000000002','17000000-0000-0000-0000-000000000004','Other directional lot',10,10);
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('57000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001','Car','43A97111','car');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes) values
 ('67000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-000000000001',
 '27000000-0000-0000-0000-000000000001','43A97111','car',now(),now()+interval '1 hour',15000,0);
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000004',true);
set local role authenticated;
do $$ declare payload jsonb; result jsonb;
begin
 perform public.apply_operation('87000000-0000-0000-0000-000000000001','kiosk.open',
  '{"lot_id":"27000000-0000-0000-0000-000000000001","direction":"entry"}');
 perform public.apply_operation('87000000-0000-0000-0000-000000000002','kiosk.open',
  '{"lot_id":"27000000-0000-0000-0000-000000000001","direction":"exit"}');
 begin
  perform public.apply_operation('87000000-0000-0000-0000-000000000001','kiosk.open',
   '{"lot_id":"27000000-0000-0000-0000-000000000001","direction":"exit"}');
  raise exception 'Session changed direction';
 exception when raise_exception then if sqlerrm<>'OPERATION_ID_REUSED' then raise; end if; end;
 payload:='{"session_id":"87000000-0000-0000-0000-000000000001","lot_id":"27000000-0000-0000-0000-000000000001","direction":"entry","plate":"43A97111"}';
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',payload-'session_id');
  raise exception 'Unbound scan accepted';
 exception when raise_exception then if sqlerrm<>'KIOSK_SESSION_REQUIRED' then raise; end if; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',payload||'{"direction":"exit"}');
  raise exception 'Entry session forged exit';
 exception when raise_exception then if sqlerrm<>'KIOSK_DIRECTION_MISMATCH' then raise; end if; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',payload||'{"lot_id":"27000000-0000-0000-0000-000000000002"}');
  raise exception 'Session moved to another lot';
 exception when raise_exception then if sqlerrm<>'KIOSK_SESSION_REQUIRED' then raise; end if; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',payload||'{"session_id":"87000000-0000-0000-0000-000000000002","direction":"exit"}');
  raise exception 'Exit camera admitted unentered vehicle';
 exception when raise_exception then if sqlerrm<>'ENTRY_REQUIRED' then raise; end if; end;
 foreach result in array array['{}'::jsonb] loop
  begin
   perform public.apply_operation(gen_random_uuid(),'staff.check_in',result);
   raise exception 'Legacy manual entry bypassed camera';
  exception when raise_exception then if sqlerrm<>'KIOSK_SESSION_REQUIRED' then raise; end if; end;
  begin
   perform public.apply_operation(gen_random_uuid(),'staff.check_out',result);
   raise exception 'Legacy manual exit bypassed camera';
  exception when raise_exception then if sqlerrm<>'KIOSK_SESSION_REQUIRED' then raise; end if; end;
 end loop;
 result:=public.apply_operation('77000000-0000-0000-0000-000000000011','kiosk.scan',payload);
 perform public.test_assert(result->>'action'='entered','entry camera admits valid vehicle automatically');
 perform public.test_assert(public.apply_operation('77000000-0000-0000-0000-000000000011','kiosk.scan',payload)=result,'entry retry is idempotent');
 perform public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',payload)->>'action'='duplicate','standing car does not exit from entry camera');
 begin
  perform public.apply_operation('77000000-0000-0000-0000-000000000012','kiosk.scan',payload||'{"session_id":"87000000-0000-0000-0000-000000000002","direction":"exit"}');
  raise exception 'Unfunded exit accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_BALANCE' then raise; end if; end;
end $$;
reset role;
select public.test_assert((select status='parked' and checked_out_at is null from public.bookings where id='67000000-0000-0000-0000-000000000001'),'failed exit leaves vehicle parked');
select public.test_assert(not exists(select 1 from public.payments where booking_id='67000000-0000-0000-0000-000000000001'),'entry and rejected exit never debit money');
-- Remaining in front of entry camera for more than 30 seconds must still never checkout.
update public.bookings set checked_in_at=now()-interval '2 minutes',starts_at=now()-interval '2 minutes'
 where id='67000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',
 '{"session_id":"87000000-0000-0000-0000-000000000001","lot_id":"27000000-0000-0000-0000-000000000001","direction":"entry","plate":"43A97111"}')->>'action'='duplicate','entry never checks out even after old debounce window');
select public.admin_adjust_wallet(gen_random_uuid(),'17000000-0000-0000-0000-000000000001',20000,'Fund exit test');
do $$ declare payload jsonb:='{"session_id":"87000000-0000-0000-0000-000000000002","lot_id":"27000000-0000-0000-0000-000000000001","direction":"exit","plate":"43A97111"}'; result jsonb;
begin
 result:=public.apply_operation('77000000-0000-0000-0000-000000000012','kiosk.scan',payload);
 perform public.test_assert(result->>'action'='exited','exit retries after customer tops up');
 perform public.test_assert(public.apply_operation('77000000-0000-0000-0000-000000000012','kiosk.scan',payload)=result,'exit replay never bills twice');
 perform public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',payload)->>'action'='duplicate','second exit observation does not bill twice');
end $$;
reset role;
select public.test_assert(smartpark_private.wallet_balance('17000000-0000-0000-0000-000000000001')=5000,'only exit debits authoritative fee once');
select public.test_assert((select count(*)=1 from public.payments where booking_id='67000000-0000-0000-0000-000000000001'),'exactly one checkout payment');
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.open','{"lot_id":"27000000-0000-0000-0000-000000000001","direction":"entry"}');
  raise exception 'Customer opened kiosk';
 exception when insufficient_privilege then null; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan','{"session_id":"87000000-0000-0000-0000-000000000002","lot_id":"27000000-0000-0000-0000-000000000001","direction":"exit","plate":"43A97111"}');
  raise exception 'Customer reused owner session';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select public.test_assert(not has_function_privilege('authenticated','public.apply_wallet_choice_operation(uuid,text,jsonb)','execute'),'old operation wrapper cannot bypass direction checks');
select public.test_assert(not has_function_privilege('authenticated','public.apply_capacity_operation(uuid,text,jsonb)','execute'),'capacity helper stays private');
rollback;
