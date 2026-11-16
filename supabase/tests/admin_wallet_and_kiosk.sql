\set ON_ERROR_STOP on
begin;
select public.test_assert(to_regclass('public.lot_staff') is null,'personnel assignments removed');
select public.test_assert(not exists(select 1 from public.profiles where role='staff'),'employee accounts demoted without deleting identities');
select public.test_assert(exists(select 1 from public.profiles where id='14000000-0000-0000-0000-000000000003' and role='customer'),'former employee identity is preserved as customer');
select public.test_assert((select count(*)=1 and sum(p.amount)=15000 from public.payments p join public.bookings b on b.id=p.booking_id
 where b.customer_id='14000000-0000-0000-0000-000000000001'),'retirement preserves historical parking payments');
select public.test_assert(to_regprocedure('public.manage_staff(uuid,text,text,boolean)') is null,'personnel grant API removed');
select public.test_assert(not exists(select 1 from public.notifications where title='Báo cáo cần xử lý'),'personnel work notifications removed');
select public.test_assert(not exists(select 1 from public.operation_receipts where kind='report.assign'),'assignment payloads removed');
select public.test_assert((select status='in_progress' from public.parking_reports where id='68000000-0000-0000-0000-000000000001'),'assigned report retained for admin processing');
insert into auth.users(id,email) values
 ('16000000-0000-0000-0000-000000000001','wallet-admin-customer@test.invalid'),
 ('16000000-0000-0000-0000-000000000002','wallet-admin-other@test.invalid'),
 ('16000000-0000-0000-0000-000000000004','wallet-admin-owner@test.invalid');
update public.profiles set role='owner' where id='16000000-0000-0000-0000-000000000004';
insert into public.parking_lots(id,owner_id,name,car_capacity,motorcycle_capacity) values
 ('26000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000004','Owner kiosk',10,10);
insert into public.vehicles(id,user_id,label,plate,kind) values
 ('56000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','Car','43A96111','car');
insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,starts_at,ends_at,hourly_rate,free_minutes) values
 ('66000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',
 '26000000-0000-0000-0000-000000000001','43A96111','car',now(),now()+interval '1 hour',15000,0);
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000004',true);
set local role authenticated;
do $$ declare result jsonb;
begin
 result:=public.admin_adjust_wallet('76000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001',2000000,'Cộng số dư kiểm thử');
 perform public.test_assert((result->>'balance_after')::bigint=2000000,'owner credits customer');
 perform public.test_assert(public.admin_adjust_wallet('76000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000001',2000000,'Cộng số dư kiểm thử')=result,'credit replay returns original receipt');
 begin
  perform public.admin_adjust_wallet('76000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001',1,'Changed amount');
  raise exception 'Reused correction ID accepted';
 exception when raise_exception then if sqlerrm<>'OPERATION_ID_REUSED' then raise; end if; end;
 perform public.admin_adjust_wallet('76000000-0000-0000-0000-000000000002','16000000-0000-0000-0000-000000000001',-500000,'Điều chỉnh giảm');
 perform public.admin_adjust_wallet('76000000-0000-0000-0000-000000000002','16000000-0000-0000-0000-000000000001',-500000,'Điều chỉnh giảm');
 begin
  perform public.admin_adjust_wallet(gen_random_uuid(),'16000000-0000-0000-0000-000000000001',-1500001,'Không được âm số dư');
  raise exception 'Negative balance accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_BALANCE' then raise; end if; end;
 begin
  perform public.admin_adjust_wallet(gen_random_uuid(),'16000000-0000-0000-0000-000000000001',1,'');
  raise exception 'Empty reason accepted';
 exception when raise_exception then if sqlerrm<>'INVALID_WALLET_ADJUSTMENT' then raise; end if; end;
 perform public.test_assert((public.admin_wallet_accounts('wallet-admin-customer')->'accounts'->0->>'balance')::bigint=1500000,'admin account search exposes authoritative balance');
 perform public.test_assert(jsonb_array_length(public.admin_wallet_accounts('wallet-admin-customer')->'adjustments')=2,'audit log has exactly two successful corrections');
 perform public.test_assert(public.park_snapshot()->'memberships' is null,'snapshot contains no personnel assignments');
 perform public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',
  '{"lot_id":"26000000-0000-0000-0000-000000000001","plate":"43A96111"}')->>'action'='entered','owner operates unattended kiosk');
end $$;
reset role;
update public.bookings set checked_in_at=now()-interval '1 minute',starts_at=now()-interval '1 minute'
 where id='66000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.test_assert(public.apply_operation(gen_random_uuid(),'kiosk.scan',
 '{"lot_id":"26000000-0000-0000-0000-000000000001","plate":"43A96111"}')->>'action'='exited','wallet corrections fund automatic exit');
reset role;
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert(public.wallet_topup_balance()=1485000,'customer balance includes corrections and parking debit');
select public.test_assert((select count(*)=2 from public.wallet_adjustments),'customer reads their own audit entries');
do $$ begin
 begin
  perform public.admin_adjust_wallet(gen_random_uuid(),auth.uid(),1000,'Attempted self credit');
  raise exception 'Customer adjusted balance';
 exception when insufficient_privilege then null; end;
 begin
  perform public.admin_wallet_accounts();
  raise exception 'Customer listed all accounts';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.wallet_adjustments(id,customer_id,actor_id,amount,reason,balance_after)
   values(gen_random_uuid(),auth.uid(),auth.uid(),1000,'Direct insert',1000);
  raise exception 'Customer bypassed RPC';
 exception when insufficient_privilege then null; end;
 begin
  perform public.apply_operation(gen_random_uuid(),'kiosk.scan',
   '{"lot_id":"26000000-0000-0000-0000-000000000001","plate":"43A96111"}');
  raise exception 'Customer controlled kiosk';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.test_assert((select count(*)=0 from public.wallet_adjustments),'other customers cannot read corrections');
select public.test_assert(public.wallet_topup_balance()=0,'other wallet remains unchanged');
reset role;
rollback;
