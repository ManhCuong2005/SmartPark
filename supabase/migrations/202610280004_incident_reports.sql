begin;
set local search_path=public,extensions;
create table public.incident_reports (
 id uuid primary key default gen_random_uuid(), lot_id uuid not null references public.parking_lots(id),
 reporter_id uuid not null references public.profiles(id), booking_id uuid references public.bookings(id),
 category text not null check(category in ('wrong_slot','ticket_mismatch','vehicle_damage','equipment','safety','other')),
 description text not null check(length(trim(description)) between 3 and 2000),
 status text not null default 'open' check(status in ('open','in_progress','resolved')),
 resolution text not null default '', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 resolved_by uuid references public.profiles(id), resolved_at timestamptz
);
create index incident_reports_lot_created on public.incident_reports(lot_id,created_at desc);
alter table public.incident_reports enable row level security;
create policy incident_reports_read on public.incident_reports for select to authenticated using(public.works_lot(lot_id));
revoke all on public.incident_reports from anon,authenticated;
grant select on public.incident_reports to authenticated;
create function public.report_incident(p_lot_id uuid,p_booking_id uuid,p_category text,p_description text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result public.incident_reports;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if not exists(select 1 from public.lot_staff where lot_id=p_lot_id and user_id=actor and active)
   and not exists(select 1 from public.parking_lots where id=p_lot_id and owner_id=actor) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_category not in ('wrong_slot','ticket_mismatch','vehicle_damage','equipment','safety','other') or length(trim(coalesce(p_description,''))) not between 3 and 2000 then raise exception 'INVALID_REPORT'; end if;
 if p_booking_id is not null and not exists(select 1 from public.bookings where id=p_booking_id and lot_id=p_lot_id) then raise exception 'TICKET_NOT_FOUND'; end if;
 insert into public.incident_reports(lot_id,reporter_id,booking_id,category,description) values(p_lot_id,actor,p_booking_id,p_category,trim(p_description)) returning * into result;
 return to_jsonb(result);
end $$;
create function public.update_incident(p_id uuid,p_status text,p_resolution text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); item public.incident_reports;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 select * into item from public.incident_reports where id=p_id for update;
 if not found or not public.owns_lot(item.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_status not in ('open','in_progress','resolved') then raise exception 'INVALID_STATUS'; end if;
 if p_status='resolved' and length(trim(coalesce(p_resolution,'')))<3 then raise exception 'RESOLUTION_REQUIRED'; end if;
 update public.incident_reports set status=p_status,resolution=case when p_status='resolved' then trim(p_resolution) else '' end,
 updated_at=now(),resolved_by=case when p_status='resolved' then actor else null end,
 resolved_at=case when p_status='resolved' then now() else null end where id=p_id returning * into item;
 return to_jsonb(item);
end $$;
grant execute on function public.report_incident(uuid,uuid,text,text) to authenticated;
grant execute on function public.update_incident(uuid,text,text) to authenticated;
revoke all on function public.report_incident(uuid,uuid,text,text),public.update_incident(uuid,text,text) from public,anon;
create or replace function public.park_snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
select jsonb_build_object(
 'profiles',coalesce((select jsonb_agg(to_jsonb(t)) from public.profiles t),'[]'::jsonb),
 'lots',coalesce((select jsonb_agg(to_jsonb(t)) from public.parking_lots t),'[]'::jsonb),
 'slots',public.current_slots(),
 'memberships',coalesce((select jsonb_agg(to_jsonb(t)) from public.lot_staff t),'[]'::jsonb),
 'vehicles',coalesce((select jsonb_agg(to_jsonb(t)) from public.vehicles t where not deleted),'[]'::jsonb),
 'bookings',coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from public.bookings t),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(to_jsonb(t)) from public.payments t),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from public.notifications t),'[]'::jsonb),
 'favorites',coalesce((select jsonb_agg(to_jsonb(t)) from public.favorites t),'[]'::jsonb),
 'incidents',coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from public.incident_reports t),'[]'::jsonb),
 'server_time',now())
$$;
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='incident_reports') then
  alter publication supabase_realtime add table public.incident_reports;
 end if;
end $$;
commit;
