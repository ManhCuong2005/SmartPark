begin;

insert into auth.users(id, email) values
  ('bd79aa42-5c16-4083-8d57-38bd0af366dd', 'payos-first@example.test'),
  ('bd79aa42-5c16-4083-8d57-38bd0af366de', 'payos-second@example.test');

set local role service_role;
insert into public.wallet_topups(customer_id, amount, payment_link_id)
  values ('bd79aa42-5c16-4083-8d57-38bd0af366dd', 20000, 'test-link');

do $$
declare
  order_id bigint;
begin
  select order_code into strict order_id from public.wallet_topups
    where payment_link_id = 'test-link';
  if public.settle_payos_topup(order_id, 'wrong-link', 20000)
    or public.settle_payos_topup(order_id, 'test-link', 10000) then
    raise exception 'An unmatched payment credited the wallet';
  end if;
  if not public.settle_payos_topup(order_id, 'test-link', 20000) then
    raise exception 'A matching payment did not settle';
  end if;
  if public.settle_payos_topup(order_id, 'test-link', 20000) then
    raise exception 'A webhook retry settled the order again';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'bd79aa42-5c16-4083-8d57-38bd0af366dd', true);
do $$
begin
  if public.wallet_topup_balance() <> 20000 then
    raise exception 'Wallet balance differs from the confirmed payment';
  end if;
  if has_table_privilege(current_user, 'public.wallet_topups', 'UPDATE')
    or has_table_privilege(current_user, 'public.wallet_topups', 'INSERT')
    or has_function_privilege(current_user,
      'public.settle_payos_topup(bigint,text,integer)', 'EXECUTE') then
    raise exception 'A customer can write their own wallet';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'bd79aa42-5c16-4083-8d57-38bd0af366de', true);
do $$
begin
  if public.wallet_topup_balance() <> 0 or exists (select 1 from public.wallet_topups) then
    raise exception 'A customer can see another customer payment';
  end if;
end;
$$;
rollback;
