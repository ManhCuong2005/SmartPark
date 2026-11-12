-- Local fixture only. Never run on Cloud.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('91000000-0000-0000-0000-000000000001','grant-target@test.invalid'),
 ('91000000-0000-0000-0000-000000000002','inactive-target@test.invalid'),
 ('91000000-0000-0000-0000-000000000003','unconfirmed-target@test.invalid');
update auth.users set email_confirmed_at=null where email='unconfirmed-target@test.invalid';

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select public.manage_lot('92000000-0000-0000-0000-000000000001','Second owner lot','Local fixture',true,2);
reset role;

-- A customer cannot promote anyone; direct profile writes remain forbidden.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
 begin
  perform public.manage_staff('20000000-0000-0000-0000-000000000001','grant-target@test.invalid','morning',true);
  raise exception 'customer must not grant staff';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
do $$ begin
 begin
  perform public.manage_staff('92000000-0000-0000-0000-000000000001','grant-target@test.invalid','morning',true);
  raise exception 'owner must not grant at another owner lot';
 exception when insufficient_privilege then null; end;
 begin
  perform public.manage_staff('20000000-0000-0000-0000-000000000001','missing@test.invalid','morning',true);
  raise exception 'missing account accepted';
 exception when raise_exception then if sqlerrm<>'USER_MUST_REGISTER_FIRST' then raise; end if; end;
 begin
  perform public.manage_staff('20000000-0000-0000-0000-000000000001','unconfirmed-target@test.invalid','morning',true);
  raise exception 'unconfirmed email accepted';
 exception when raise_exception then if sqlerrm<>'USER_EMAIL_NOT_CONFIRMED' then raise; end if; end;
 begin
  perform public.manage_staff('20000000-0000-0000-0000-000000000001','grant-target@test.invalid','invalid',true);
  raise exception 'invalid shift accepted';
 exception when raise_exception then if sqlerrm<>'INVALID_SHIFT' then raise; end if; end;
end $$;
select public.manage_staff('20000000-0000-0000-0000-000000000001','  GRANT-TARGET@TEST.INVALID  ','morning',true);
select public.manage_staff('20000000-0000-0000-0000-000000000001','inactive-target@test.invalid','afternoon',false);
reset role;
select public.test_assert((select role='staff' from public.profiles where email='grant-target@test.invalid'),'grant promotes registered customer');
select public.test_assert((select role='customer' from public.profiles where email='inactive-target@test.invalid'),'inactive assignment never promotes customer');
select public.test_assert(not exists(select 1 from public.lot_staff where user_id='91000000-0000-0000-0000-000000000003'),'failed grant is atomic');

-- A second owner's assignment must survive revocation at the first owner's lot.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select public.manage_staff('92000000-0000-0000-0000-000000000001','grant-target@test.invalid','night',true);
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.manage_staff('20000000-0000-0000-0000-000000000001','grant-target@test.invalid','morning',false);
reset role;
select public.test_assert((select role='staff' from public.profiles where email='grant-target@test.invalid'),'other active assignment preserves staff role');
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.test_assert(not public.works_lot('20000000-0000-0000-0000-000000000001'),'revoked lot denied immediately');
select public.test_assert(public.works_lot('92000000-0000-0000-0000-000000000001'),'second assigned lot remains accessible');
do $$ begin
 begin
  perform public.manage_staff('92000000-0000-0000-0000-000000000001','inactive-target@test.invalid','night',true);
  raise exception 'staff must not promote another person';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select public.manage_staff('92000000-0000-0000-0000-000000000001','grant-target@test.invalid','night',false);
reset role;
select public.test_assert((select role='customer' from public.profiles where email='grant-target@test.invalid'),'last revocation returns account to customer');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select public.manage_staff('20000000-0000-0000-0000-000000000001','owner@test.invalid','morning',true);
select public.manage_staff('20000000-0000-0000-0000-000000000001','owner@test.invalid','morning',false);
reset role;
select public.test_assert((select role='owner' from public.profiles where email='owner@test.invalid'),'owner role is never demoted');
commit;
