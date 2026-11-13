create table public.wallet_topups (
  order_code bigint generated always as identity (start with 1000000000000) primary key,
  customer_id uuid not null references auth.users(id),
  amount integer not null check (amount between 2000 and 5000000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  payment_link_id text unique,
  checkout_url text,
  paid_at timestamptz,
  check (paid_at is null or payment_link_id is not null)
);

create index wallet_topups_customer_history
  on public.wallet_topups (customer_id, order_code desc);
alter table public.wallet_topups enable row level security;
create policy wallet_topups_read_own on public.wallet_topups
  for select to authenticated using ((select auth.uid()) = customer_id);
revoke all on public.wallet_topups from public, anon, authenticated, service_role;
grant select on public.wallet_topups to authenticated;
grant select, insert, update on public.wallet_topups to service_role;
grant usage on sequence public.wallet_topups_order_code_seq to service_role;

create function public.wallet_topup_balance()
returns bigint
language sql stable security invoker set search_path = ''
as $$
  select coalesce(sum(amount), 0)
  from public.wallet_topups
  where customer_id = (select auth.uid()) and paid_at is not null;
$$;
revoke all on function public.wallet_topup_balance() from public, anon;
grant execute on function public.wallet_topup_balance() to authenticated;

-- A settled row is the credit entry. Retries cannot add a second entry.
create function public.settle_payos_topup(
  p_order_code bigint, p_payment_link_id text, p_amount integer
) returns boolean
language sql volatile security invoker set search_path = ''
as $$
  with settled as (
    update public.wallet_topups
    set paid_at = now()
    where order_code = p_order_code and payment_link_id = p_payment_link_id
      and amount = p_amount and paid_at is null
    returning 1
  )
  select exists(select 1 from settled);
$$;
revoke all on function public.settle_payos_topup(bigint, text, integer)
  from public, anon, authenticated;
grant execute on function public.settle_payos_topup(bigint, text, integer)
  to service_role;
