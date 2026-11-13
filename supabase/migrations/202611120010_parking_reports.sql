begin;
create table public.parking_reports (
 id uuid primary key,
 lot_id uuid not null references public.parking_lots(id),
 reported_by uuid not null references public.profiles(id),
 plate text not null check(plate ~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$'),
 description text not null check(length(trim(description)) between 1 and 1000),
 status text not null default 'open' check(status in ('open','move_requested','assigned','in_progress','resolved','rejected')),
 assigned_to uuid references public.profiles(id),
 version integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index reports_lot_status on public.parking_reports(lot_id,status,created_at desc);
create table public.report_events (
 id uuid primary key default gen_random_uuid(),
 report_id uuid not null references public.parking_reports(id),
 actor_id uuid not null references public.profiles(id),
 status text not null,
 note text not null default '' check(length(note)<=1000),
 created_at timestamptz not null default now()
);
alter table public.parking_reports enable row level security;
alter table public.report_events enable row level security;
create policy reports_read on public.parking_reports for select to authenticated using(
 reported_by=auth.uid() or public.owns_lot(lot_id) or (assigned_to=auth.uid() and public.works_lot(lot_id)));
create policy report_events_read on public.report_events for select to authenticated using(exists(
 select 1 from public.parking_reports r where r.id=report_id));
revoke all on public.parking_reports,public.report_events from public,anon,authenticated;
grant select on public.parking_reports,public.report_events to authenticated;

create function smartpark_private.apply_report(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous public.operation_receipts; r public.parking_reports; l public.parking_lots;
 normalized text; target uuid; next_status text; result jsonb; already_open boolean:=false;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
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
  if not public.owns_lot(r.lot_id) and not (r.assigned_to is not distinct from actor and public.works_lot(r.lot_id) and p_kind='report.progress') then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if r.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
  if r.status in ('resolved','rejected') then raise exception 'INVALID_STATE'; end if;
  if p_kind='report.request_move' then
   if not public.owns_lot(r.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   select b.customer_id into target from public.bookings b where b.lot_id=r.lot_id and b.plate=r.plate and b.status='parked'
    order by b.checked_in_at desc limit 1;
   if target is null then raise exception 'PARKED_OWNER_NOT_FOUND'; end if;
   next_status:='move_requested';
   insert into public.notifications(user_id,category,dedupe_key,title,body)
    values(target,'move_requested','report_move:'||r.id,'Vui lòng di chuyển xe',r.plate||': vui lòng di chuyển xe về đúng vị trí trong bãi hoặc liên hệ nhân viên.')
    on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
  elsif p_kind='report.assign' then
   target:=(p_payload->>'staff_id')::uuid;
   if target is null or not exists(select 1 from public.lot_staff where lot_id=r.lot_id and user_id=target and active) then raise exception 'STAFF_NOT_ASSIGNED'; end if;
   next_status:='assigned';
   update public.parking_reports set assigned_to=target where id=r.id;
   insert into public.notifications(user_id,title,body) values(target,'Báo cáo cần xử lý',r.plate||': '||r.description);
  elsif p_kind='report.progress' then
   next_status:=p_payload->>'status';
   if next_status is null or next_status not in ('in_progress','resolved','rejected') or
    (not public.owns_lot(r.lot_id) and next_status='rejected') or
    (next_status='in_progress' and r.status not in ('assigned','in_progress')) then raise exception 'INVALID_STATE'; end if;
  else raise exception 'UNKNOWN_OPERATION'; end if;
  update public.parking_reports set status=next_status,version=version+1,updated_at=now() where id=r.id returning * into r;
 end if;
 if not already_open then
  insert into public.report_events(report_id,actor_id,status,note) values(r.id,actor,r.status,left(coalesce(p_payload->>'note',''),1000));
 end if;
 -- No booking/customer lookup result is ever returned to the reporter.
 result:=to_jsonb(r);
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values(actor,p_operation_id,p_kind,p_payload,result);
 return result;
end $$;
alter function public.apply_operation(uuid,text,jsonb) rename to apply_capacity_operation;
revoke execute on function public.apply_capacity_operation(uuid,text,jsonb) from public,anon,authenticated;
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if p_kind like 'report.%' then return smartpark_private.apply_report(p_operation_id,p_kind,p_payload); end if;
 return public.apply_capacity_operation(p_operation_id,p_kind,p_payload);
end $$;
alter function public.park_snapshot_rows() rename to snapshot_capacity_rows;
create function public.park_snapshot_rows() returns jsonb language sql volatile security invoker set search_path='' as $$
 select public.snapshot_capacity_rows() || jsonb_build_object(
  'reports',coalesce((select jsonb_agg(to_jsonb(r) order by created_at desc) from public.parking_reports r),'[]'::jsonb),
  'report_events',coalesce((select jsonb_agg(to_jsonb(e) order by created_at) from public.report_events e),'[]'::jsonb))
$$;
-- Staff needs ticket/plate data, not customer names, email addresses or phone numbers.
drop policy profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid()
 or exists(select 1 from public.lot_staff s where s.user_id=profiles.id and public.owns_lot(s.lot_id))
 or exists(select 1 from public.bookings b where b.customer_id=profiles.id and public.owns_lot(b.lot_id)));
revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
revoke execute on function public.apply_operation(uuid,text,jsonb),public.park_snapshot_rows() from public,anon;
grant execute on function public.apply_operation(uuid,text,jsonb),public.park_snapshot_rows() to authenticated;
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.parking_reports,public.report_events;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
