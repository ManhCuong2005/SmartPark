-- Retire personnel assignments; owners administer kiosks and wallet corrections.
begin;

create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='owner')
$$;
revoke execute on function public.is_admin() from public,anon;
grant execute on function public.is_admin() to authenticated;

create table public.wallet_adjustments (
 id uuid primary key,
 customer_id uuid not null references public.profiles(id),
 actor_id uuid not null references public.profiles(id),
 amount integer not null check(amount<>0 and amount between -5000000 and 5000000),
 reason text not null check(length(trim(reason)) between 3 and 500),
 balance_after bigint not null check(balance_after>=0),
 created_at timestamptz not null default now()
);
create index wallet_adjustments_customer_history on public.wallet_adjustments(customer_id,created_at desc);
alter table public.wallet_adjustments enable row level security;
create policy wallet_adjustments_read on public.wallet_adjustments for select to authenticated
 using(customer_id=auth.uid() or public.is_admin());
revoke all on public.wallet_adjustments from public,anon,authenticated,service_role;
grant select on public.wallet_adjustments to authenticated;

create or replace function smartpark_private.wallet_balance(p_customer uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce((select sum(amount) from public.wallet_topups where customer_id=p_customer and paid_at is not null),0)
 +coalesce((select sum(amount) from public.wallet_adjustments where customer_id=p_customer),0)
 -coalesce((select sum(p.amount) from public.payments p join public.bookings b on b.id=p.booking_id
  where b.customer_id=p_customer and p.method in ('wallet','qr','wallet_refund')),0)
$$;
create or replace function public.wallet_topup_balance() returns bigint
language sql stable security invoker set search_path='' as $$
 select coalesce((select sum(amount) from public.wallet_topups where customer_id=auth.uid() and paid_at is not null),0)
 +coalesce((select sum(amount) from public.wallet_adjustments where customer_id=auth.uid()),0)
 -coalesce((select sum(p.amount) from public.payments p join public.bookings b on b.id=p.booking_id
  where b.customer_id=auth.uid() and p.method in ('wallet','qr','wallet_refund')),0)
$$;

create function public.admin_adjust_wallet(p_operation_id uuid,p_customer_id uuid,p_amount integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.wallet_adjustments; balance bigint; reason text:=trim(p_reason);
begin
 if not public.is_admin() then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_operation_id is null or p_customer_id is null or p_amount is null or p_amount=0
  or p_amount not between -5000000 and 5000000 or reason is null or length(reason) not between 3 and 500
  then raise exception 'INVALID_WALLET_ADJUSTMENT'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,5));
 select * into previous from public.wallet_adjustments where id=p_operation_id;
 if found then
  if previous.actor_id<>actor or previous.customer_id<>p_customer_id or previous.amount<>p_amount or previous.reason<>reason
   then raise exception 'OPERATION_ID_REUSED'; end if;
  return to_jsonb(previous);
 end if;
 -- The same customer lock serializes this correction with booking and exit debits.
 perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text,1));
 if not exists(select 1 from public.profiles where id=p_customer_id) then raise exception 'ACCOUNT_NOT_FOUND'; end if;
 balance:=smartpark_private.wallet_balance(p_customer_id)+p_amount;
 if balance<0 then raise exception 'INSUFFICIENT_BALANCE'; end if;
 insert into public.wallet_adjustments(id,customer_id,actor_id,amount,reason,balance_after)
  values(p_operation_id,p_customer_id,actor,p_amount,reason,balance) returning * into previous;
 insert into public.notifications(user_id,title,body)
  values(p_customer_id,'Số dư đã được điều chỉnh',
   case when p_amount>0 then 'Cộng ' else 'Trừ ' end||abs(p_amount)||'đ. Lý do: '||reason);
 return to_jsonb(previous);
end $$;

create function public.admin_wallet_accounts(p_query text default '',p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare accounts jsonb; history jsonb; total integer; query text:=lower(trim(coalesce(p_query,'')));
begin
 if not public.is_admin() then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 or length(query)>200
  then raise exception 'INVALID_REQUEST'; end if;
 select count(*) into total from public.profiles p
  where query='' or position(query in lower(p.email||' '||p.name))>0;
 select coalesce(jsonb_agg(t order by t.email),'[]'::jsonb) into accounts from (
  select p.id,p.email,p.name,p.role,smartpark_private.wallet_balance(p.id) as balance
  from public.profiles p where query='' or position(query in lower(p.email||' '||p.name))>0
  order by p.email,p.id limit p_limit offset p_offset
 ) t;
 select coalesce(jsonb_agg(t order by t.created_at desc,t.id),'[]'::jsonb) into history from (
  select a.*,c.email as customer_email,o.email as actor_email from public.wallet_adjustments a
  join public.profiles c on c.id=a.customer_id join public.profiles o on o.id=a.actor_id
  where query='' or position(query in lower(c.email||' '||c.name))>0
  order by a.created_at desc,a.id limit 20
 ) t;
 return jsonb_build_object('accounts',accounts,'adjustments',history,'total',total);
end $$;
revoke execute on function public.admin_wallet_accounts(text,integer,integer),
 public.admin_adjust_wallet(uuid,uuid,integer,text) from public,anon;
grant execute on function public.admin_wallet_accounts(text,integer,integer),
 public.admin_adjust_wallet(uuid,uuid,integer,text) to authenticated;

-- Preserve user identities and financial audit rows, removing the employee role.
delete from public.notifications where title='Báo cáo cần xử lý'
 and user_id in(select user_id from public.lot_staff);
delete from public.operation_receipts where kind='report.assign';
update public.profiles set role='customer' where role='staff';
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check check(role in ('customer','owner'));
create or replace function public.works_lot(p_lot uuid) returns boolean
language sql stable security definer set search_path='' as $$ select public.is_admin() and public.owns_lot(p_lot) $$;
drop function public.manage_staff(uuid,text,text,boolean);
drop policy profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid()
 or exists(select 1 from public.bookings b where b.customer_id=profiles.id and public.owns_lot(b.lot_id)));
drop policy reports_read on public.parking_reports;
create policy reports_read on public.parking_reports for select to authenticated using(reported_by=auth.uid() or public.owns_lot(lot_id));
update public.parking_reports set assigned_to=null,status=case when status='assigned' then 'in_progress' else status end;
alter table public.parking_reports drop column assigned_to;
alter table public.parking_reports drop constraint parking_reports_status_check;
alter table public.parking_reports add constraint parking_reports_status_check
 check(status in ('open','move_requested','in_progress','resolved','rejected'));

create or replace function public.snapshot_capacity_rows() returns jsonb
language sql volatile security invoker set search_path='' as $$
 select jsonb_build_object(
 'profiles',coalesce((select jsonb_agg(to_jsonb(t)) from public.profiles t),'[]'::jsonb),
 'lots',coalesce((select jsonb_agg(to_jsonb(t)) from public.parking_lots t),'[]'::jsonb),
 'capacities',public.capacity_snapshot(),
 'vehicles',coalesce((select jsonb_agg(to_jsonb(t)) from public.vehicles t where not deleted),'[]'::jsonb),
 'bookings',coalesce((select jsonb_agg(to_jsonb(t)-'qr_token' order by created_at desc) from public.bookings t),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(to_jsonb(t)) from public.payments t),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from public.notifications t),'[]'::jsonb),
 'favorites',coalesce((select jsonb_agg(to_jsonb(t)) from public.favorites t),'[]'::jsonb),'server_time',now())
$$;

create or replace function smartpark_private.expire_no_shows(p_scope uuid default null,p_slot uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare l record; b public.bookings;
begin
 for l in select lot.id,lot.name from public.parking_lots lot where exists(
  select 1 from public.bookings t where t.lot_id=lot.id and t.status='confirmed' and t.checked_in_at is null and t.ends_at<=now()
   and (p_scope is null or t.customer_id=p_scope or lot.owner_id=p_scope)) order by lot.id for update of lot skip locked
 loop
  for b in select t.* from public.bookings t where t.lot_id=l.id and t.status='confirmed' and t.checked_in_at is null and t.ends_at<=now()
   and (p_slot is null or t.slot_id=p_slot) and (p_scope is null or t.customer_id=p_scope or l.id in(
    select id from public.parking_lots where owner_id=p_scope)) for update of t skip locked
  loop
   if b.prepaid or exists(select 1 from public.payments where booking_id=b.id)
    or exists(select 1 from public.parking_events where booking_id=b.id) then
    update public.bookings set status='expired',version=version+1 where id=b.id;
   else
    update public.operation_receipts set result=jsonb_build_object('id',b.id,'status','expired','deleted',true)
     where kind in ('booking.reserve','booking.create') and result->>'id'=b.id::text;
    update public.notifications set booking_id=null where booking_id=b.id;
    delete from public.bookings where id=b.id;
   end if;
   insert into public.notifications(user_id,booking_id,category,dedupe_key,title,body)
    values(b.customer_id,case when exists(select 1 from public.bookings where id=b.id) then b.id else null end,
     'booking_expired','booking_expired:'||b.id,'Vé đã hết hạn',l.name||': vé chưa vào bãi đã hết hiệu lực.')
    on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
  end loop;
 end loop;
end $$;

-- Report processing belongs to the owner; there is no personnel assignment API.
create or replace function smartpark_private.apply_report(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; r public.parking_reports; l public.parking_lots;
 normalized text; target uuid; next_status text; result jsonb; already_open boolean:=false;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_kind not in ('report.create','report.request_move','report.progress') then raise exception 'UNKNOWN_OPERATION'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
  if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
  return previous.result;
 end if;
 if p_kind='report.create' then
  normalized:=smartpark_private.plate(p_payload->>'plate');
  if normalized !~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$' then raise exception 'INVALID_PLATE'; end if;
  if length(trim(coalesce(p_payload->>'description',''))) not between 1 and 1000 then raise exception 'INVALID_DESCRIPTION'; end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text||normalized||coalesce(p_payload->>'lot_id',''),4));
  select * into l from public.parking_lots where id=(p_payload->>'lot_id')::uuid and enabled;
  if not found then raise exception 'LOT_UNAVAILABLE'; end if;
  select * into r from public.parking_reports where reported_by=actor and lot_id=l.id and plate=normalized and status not in ('resolved','rejected') order by created_at limit 1;
  already_open:=found;
  if not already_open then
   insert into public.parking_reports(id,lot_id,reported_by,plate,description)
    values((p_payload->>'id')::uuid,l.id,actor,normalized,trim(p_payload->>'description')) returning * into r;
   insert into public.notifications(user_id,title,body) values(l.owner_id,'Báo cáo đỗ sai mới',l.name||' · '||r.plate);
  end if;
 else
  select * into r from public.parking_reports where id=(p_payload->>'report_id')::uuid for update;
  if not found then raise exception 'REPORT_NOT_FOUND'; end if;
  if not public.owns_lot(r.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if r.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  if r.status in ('resolved','rejected') then raise exception 'INVALID_STATE'; end if;
  if p_kind='report.request_move' then
   select b.customer_id into target from public.bookings b where b.lot_id=r.lot_id and b.plate=r.plate and b.status='parked'
    order by b.checked_in_at desc limit 1;
   if target is null then raise exception 'PARKED_OWNER_NOT_FOUND'; end if;
   next_status:='move_requested';
   insert into public.notifications(user_id,category,dedupe_key,title,body)
    values(target,'move_requested','report_move:'||r.id,'Vui lòng di chuyển xe',r.plate||': vui lòng di chuyển xe về đúng vị trí hoặc liên hệ quản trị bãi.')
    on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
  else
   next_status:=p_payload->>'status';
   if next_status is null or next_status not in ('in_progress','resolved','rejected') then raise exception 'INVALID_STATE'; end if;
  end if;
  update public.parking_reports set status=next_status,version=version+1,updated_at=now() where id=r.id returning * into r;
 end if;
 if not already_open then
  insert into public.report_events(report_id,actor_id,status,note) values(r.id,actor,r.status,left(coalesce(p_payload->>'note',''),1000));
 end if;
 result:=to_jsonb(r);
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values(actor,p_operation_id,p_kind,p_payload,result);
 return result;
end $$;

drop function smartpark_private.expire_before_automatic(uuid,uuid);
drop function smartpark_private.expire_unpaid_no_shows(uuid,uuid);
drop table public.lot_staff;
revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.wallet_adjustments;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
