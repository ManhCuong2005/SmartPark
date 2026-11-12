-- Run once in Cloud SQL Editor after migrations 001/002; no seed data.
-- Keep the existing RPC signature so already-built apps remain compatible.
begin;
create or replace function public.manage_staff(
  p_lot_id uuid, p_email text, p_shift text, p_active boolean
) returns void language plpgsql security definer set search_path='' as $$
declare
  person public.profiles;
begin
  if auth.uid() is null or not exists(
    select 1 from public.profiles where id=auth.uid() and role='owner'
  ) or not public.owns_lot(p_lot_id) then
    raise exception 'FORBIDDEN' using errcode='42501';
  end if;
  if p_shift is null or p_shift not in ('morning','afternoon','night') then
    raise exception 'INVALID_SHIFT';
  end if;
  if p_active is null then raise exception 'INVALID_ACTIVE_STATE'; end if;

  -- Serialize changes for the same person across different owners/lots. This
  -- prevents simultaneous grant/revoke requests from leaving the wrong role.
  select * into person from public.profiles
  where lower(email)=lower(trim(p_email)) for update;
  if not found then raise exception 'USER_MUST_REGISTER_FIRST'; end if;
  if p_active and not exists(
    select 1 from auth.users where id=person.id and email_confirmed_at is not null
  ) then
    raise exception 'USER_EMAIL_NOT_CONFIRMED';
  end if;

  insert into public.lot_staff(lot_id,user_id,shift,active)
  values(p_lot_id,person.id,p_shift,p_active)
  on conflict(lot_id,user_id) do update set shift=excluded.shift,active=excluded.active;

  if p_active then
    update public.profiles set role='staff' where id=person.id and role='customer';
  elsif not exists(select 1 from public.lot_staff where user_id=person.id and active) then
    update public.profiles set role='customer' where id=person.id and role='staff';
  end if;
  -- An owner remains an owner, even if also assigned to work at a parking lot.
end $$;
revoke execute on function public.manage_staff(uuid,text,text,boolean) from public,anon;
grant execute on function public.manage_staff(uuid,text,text,boolean) to authenticated;
commit;
