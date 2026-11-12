-- Apply after 001, 002 and 003. No credentials, extensions or scheduler setup.
begin;
create schema if not exists smartpark_private;
revoke all on schema smartpark_private from public,anon,authenticated;

alter table public.bookings drop constraint bookings_status_check;
alter table public.bookings add constraint bookings_status_check
 check(status in ('confirmed','parked','completed','cancelled','expired'));
create index bookings_deadlines on public.bookings(ends_at)
 where status in ('confirmed','parked');
alter table public.notifications add column booking_id uuid references public.bookings(id);
alter table public.notifications add column category text;
alter table public.notifications add column dedupe_key text;
create unique index notifications_once on public.notifications(user_id,dedupe_key)
 where dedupe_key is not null;

create table public.push_devices (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 token text not null unique check(length(token) between 20 and 4096),
 active boolean not null default true,
 updated_at timestamptz not null default now()
);
create index push_devices_user on public.push_devices(user_id) where active;
create table public.push_jobs (
 id uuid primary key default gen_random_uuid(),
 notification_id uuid not null references public.notifications(id) on delete cascade,
 device_id uuid not null references public.push_devices(id) on delete cascade,
 state text not null default 'pending' check(state in ('pending','sending','sent','cancelled','failed')),
 attempts integer not null default 0,
 next_attempt timestamptz not null default now(),
 lease_id uuid,
 locked_until timestamptz,
 last_error text,
 created_at timestamptz not null default now(),
 unique(notification_id,device_id)
);
create index push_jobs_ready on public.push_jobs(next_attempt) where state in ('pending','sending');
alter table public.push_devices enable row level security;
alter table public.push_jobs enable row level security;
-- No client table access. A device token can only be registered for auth.uid().
revoke all on public.push_devices,public.push_jobs from public,anon,authenticated;

create function public.register_push_device(p_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if length(p_token) not between 20 and 4096 or p_token is null then raise exception 'INVALID_TOKEN'; end if;
 insert into public.push_devices(user_id,token) values(auth.uid(),p_token)
 on conflict(token) do update set user_id=excluded.user_id,active=true,updated_at=now();
end $$;
create function public.unregister_push_device(p_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 update public.push_devices set active=false,updated_at=now() where user_id=auth.uid() and token=p_token;
end $$;

create function smartpark_private.enqueue_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.push_jobs(notification_id,device_id)
 select new.id,d.id from public.push_devices d where d.user_id=new.user_id and d.active;
 return new;
end $$;
create trigger smartpark_notification_push after insert on public.notifications
 for each row execute function smartpark_private.enqueue_push();

-- Row locks serialize expiry with check-in/out. Parked vehicles NEVER expire.
-- p_scope=NULL is reserved for the private cron worker, not the public RPC.
create function smartpark_private.process_deadlines(p_scope uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings; lot_name text; stamp timestamptz:=now(); category text; heading text; message text;
begin
 for b in select t.* from public.bookings t
   where ((t.status='confirmed' and t.checked_in_at is null and t.ends_at<=stamp)
      or (t.status='parked' and t.ends_at<=stamp+interval '30 minutes'))
   and (p_scope is null or t.customer_id=p_scope or exists(
      select 1 from public.parking_lots l where l.id=t.lot_id and l.owner_id=p_scope)
      or exists(select 1 from public.lot_staff s where s.lot_id=t.lot_id and s.user_id=p_scope and s.active))
   order by t.ends_at for update of t skip locked
 loop
   select name into lot_name from public.parking_lots where id=b.lot_id;
   if b.status='confirmed' then
     update public.bookings set status='expired',version=version+1 where id=b.id;
     category:='booking_expired'; heading:='Vé đặt chỗ đã hết hạn';
     message:=b.plate||' · '||lot_name||': đã quá giờ kết thúc nhưng chưa vào bãi. Vé đã kết thúc, không thu phí.';
   elsif b.ends_at>stamp then
     category:='pickup_soon'; heading:='Sắp đến giờ lấy xe';
     message:=b.plate||' · '||lot_name||': giờ lấy xe dự kiến '||to_char(b.ends_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI DD/MM')||'. Vui lòng sắp xếp lấy xe.';
   else
     category:='pickup_overdue'; heading:='Đã quá giờ lấy xe';
     message:=b.plate||' · '||lot_name||': đã quá giờ lấy xe dự kiến. Xe vẫn đang trong bãi, phí được tính đến khi check-out.';
   end if;
   insert into public.notifications(user_id,booking_id,category,dedupe_key,title,body)
   values(b.customer_id,b.id,category,category||':'||b.id::text,heading,message)
   on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
 end loop;
end $$;

create function public.refresh_booking_deadlines() returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 perform smartpark_private.process_deadlines(auth.uid());
end $$;

-- Preserve the existing RLS-filtered snapshot, adding request-time maintenance
-- as a fallback when the cron scheduler has not been installed yet.
alter function public.park_snapshot() rename to park_snapshot_rows;
create function public.park_snapshot() returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
 perform public.refresh_booking_deadlines();
 return public.park_snapshot_rows();
end $$;
alter function public.apply_operation(uuid,text,jsonb) rename to apply_operation_core;
revoke execute on function public.apply_operation_core(uuid,text,jsonb) from public,anon,authenticated;
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public.refresh_booking_deadlines();
 if p_kind in ('booking.create','vehicle.save') then
   perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 end if;
 return public.apply_operation_core(p_operation_id,p_kind,p_payload);
end $$;

-- Booking creation previously read a vehicle before locking the slot. Serialize
-- it with vehicle edits and reject stale plate snapshots at the write boundary.
create function smartpark_private.guard_booking_vehicle() returns trigger
language plpgsql security definer set search_path='' as $$
declare v public.vehicles;
begin
 select * into v from public.vehicles where id=new.vehicle_id for update;
 if v.deleted or v.plate is distinct from new.plate then raise exception 'VERSION_CONFLICT'; end if;
 return new;
end $$;
create trigger smartpark_booking_vehicle before insert on public.bookings
 for each row execute function smartpark_private.guard_booking_vehicle();

-- Service-role-only worker RPCs. Neither staff nor an owner can read tokens,
-- claim delivery jobs, change deadlines globally, or acknowledge a push.
create function public.claim_push_jobs(p_limit integer default 30) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job record; result jsonb:='[]'; claim uuid;
begin
 for job in select j.id,j.attempts,n.id as notification_id,n.user_id,n.title,n.body,n.category,n.booking_id,n.created_at,
     d.token,d.active,d.user_id as device_user,b.status,b.ends_at
   from public.push_jobs j join public.notifications n on n.id=j.notification_id
   join public.push_devices d on d.id=j.device_id left join public.bookings b on b.id=n.booking_id
   where j.next_attempt<=now() and (j.state='pending' or (j.state='sending' and j.locked_until<now()))
   order by j.next_attempt,j.id limit greatest(1,least(p_limit,100)) for update of j skip locked
 loop
   if not job.active or job.device_user<>job.user_id or job.created_at<now()-interval '1 day'
     or (job.category in ('pickup_soon','pickup_overdue') and
       (job.status is distinct from 'parked' or (job.category='pickup_soon' and job.ends_at<=now()))) then
     update public.push_jobs set state='cancelled' where id=job.id; continue;
   end if;
   claim:=gen_random_uuid();
   update public.push_jobs set state='sending',attempts=attempts+1,lease_id=claim,locked_until=now()+interval '3 minutes' where id=job.id;
   result:=result||jsonb_build_array(jsonb_build_object('id',job.id,'lease_id',claim,'notification_id',job.notification_id,
     'user_id',job.user_id,'title',job.title,'body',job.body,'category',job.category,'booking_id',job.booking_id,
     'token',job.token,'ends_at',job.ends_at));
 end loop;
 return result;
end $$;
create function public.finish_push_job(p_id uuid,p_lease_id uuid,p_result text,p_error text default null) returns void
language plpgsql security definer set search_path='' as $$
declare j public.push_jobs;
begin
 select * into j from public.push_jobs where id=p_id and state='sending' and lease_id=p_lease_id for update;
 if not found then return; end if;
 if p_result='invalid_token' then
   update public.push_devices set active=false where id=j.device_id;
 end if;
 update public.push_jobs set state=case when p_result='sent' then 'sent'
   when p_result in ('invalid_token','permanent') or attempts>=10 then 'failed' else 'pending' end,
   next_attempt=now()+make_interval(secs=>least(3600,30*power(2,least(attempts,7)))::integer),
   last_error=left(p_error,300),locked_until=null,lease_id=null where id=j.id;
end $$;

revoke execute on all functions in schema smartpark_private from public,anon,authenticated;
revoke execute on function public.register_push_device(text),public.unregister_push_device(text),public.refresh_booking_deadlines(),
 public.park_snapshot(),public.apply_operation(uuid,text,jsonb),public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,text,text)
 from public,anon,authenticated;
grant execute on function public.register_push_device(text),public.unregister_push_device(text),public.refresh_booking_deadlines(),
 public.park_snapshot(),public.apply_operation(uuid,text,jsonb) to authenticated;
grant execute on function public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,text,text) to service_role;
commit;
