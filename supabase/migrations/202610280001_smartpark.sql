-- Apply through the Cloud SQL Editor or the Supabase CLI. No operational seed data.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
set local search_path=public,extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text not null default '',
  phone text not null default '',
  role text not null default 'customer' check (role in ('customer','staff','owner')),
  created_at timestamptz not null default now()
);
create table public.parking_lots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  name text not null check (length(trim(name)) between 1 and 150),
  area text not null default '',
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  enabled boolean not null default true,
  car_rate integer not null default 15000 check (car_rate between 0 and 10000000),
  motorcycle_rate integer not null default 5000 check (motorcycle_rate between 0 and 10000000),
  free_minutes integer not null default 0 check (free_minutes between 0 and 120),
  version integer not null default 1,
  created_at timestamptz not null default now()
);
create table public.parking_slots (
  id uuid primary key default gen_random_uuid(),
  lot_id uuid not null references public.parking_lots(id),
  code text not null check (length(trim(code)) between 1 and 20),
  enabled boolean not null default true,
  unique(lot_id, code)
);
create table public.lot_staff (
  lot_id uuid not null references public.parking_lots(id),
  user_id uuid not null references public.profiles(id),
  shift text not null default 'morning' check (shift in ('morning','afternoon','night')),
  active boolean not null default true,
  primary key(lot_id,user_id)
);
create table public.vehicles (
  id uuid primary key,
  user_id uuid not null references public.profiles(id),
  label text not null check(length(trim(label)) between 1 and 100),
  plate text not null check(plate ~ '^[0-9]{2}[A-Z]{1,2}[0-9]{5,6}$'),
  kind text not null default 'car' check(kind in ('car','motorcycle')),
  is_default boolean not null default false,
  version integer not null default 1,
  deleted boolean not null default false
);
create unique index vehicle_active_plate on public.vehicles(user_id,plate) where not deleted;
create unique index vehicle_one_default on public.vehicles(user_id) where is_default and not deleted;
create table public.bookings (
  id uuid primary key,
  customer_id uuid not null references public.profiles(id),
  vehicle_id uuid not null references public.vehicles(id),
  lot_id uuid not null references public.parking_lots(id),
  slot_id uuid not null references public.parking_slots(id),
  plate text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'confirmed' check(status in ('confirmed','parked','completed','cancelled')),
  qr_token text not null unique default encode(extensions.gen_random_bytes(32),'hex'),
  hourly_rate integer not null,
  free_minutes integer not null,
  amount integer not null default 0 check(amount >= 0),
  checked_in_at timestamptz,
  checked_out_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  check(ends_at > starts_at),
  exclude using gist (slot_id with =, tstzrange(starts_at,ends_at,'[)') with &&)
    where (status in ('confirmed','parked'))
);
create unique index one_parked_vehicle_per_slot on public.bookings(slot_id) where status='parked';
create unique index one_active_vehicle on public.bookings(vehicle_id) where status='parked';
create index bookings_customer on public.bookings(customer_id,created_at desc);
create index bookings_lot on public.bookings(lot_id,status);
create table public.parking_events (
  id uuid primary key,
  booking_id uuid not null references public.bookings(id),
  actor_id uuid not null references public.profiles(id),
  kind text not null check(kind in ('check_in','check_out')),
  plate text not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique(booking_id,kind)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  amount integer not null check(amount >= 0),
  method text not null default 'cash' check(method='cash'),
  received_by uuid not null references public.profiles(id),
  paid_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  title text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.operation_receipts (
  actor_id uuid not null references public.profiles(id),
  operation_id uuid not null,
  kind text not null,
  payload jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_id,operation_id)
);
create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  lot_id uuid not null references public.parking_lots(id),
  primary key(user_id,lot_id)
);

create function public.handle_new_user() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  insert into public.profiles(id,email,name,phone)
  values(new.id,coalesce(new.email,''),left(coalesce(new.raw_user_meta_data->>'name',''),100),
    left(coalesce(new.raw_user_meta_data->>'phone',''),30));
  return new;
end $$;
create trigger smartpark_new_user after insert on auth.users for each row execute function public.handle_new_user();
-- Also support users created before this migration.
insert into public.profiles(id,email,name)
select id,coalesce(email,''),left(coalesce(raw_user_meta_data->>'name',''),100) from auth.users
on conflict(id) do nothing;

create function public.owns_lot(p_lot uuid) returns boolean language sql stable security definer
set search_path = '' as $$ select exists(select 1 from public.parking_lots where id=p_lot and owner_id=auth.uid()) $$;
create function public.works_lot(p_lot uuid) returns boolean language sql stable security definer
set search_path = '' as $$ select public.owns_lot(p_lot) or exists(select 1 from public.lot_staff where lot_id=p_lot and user_id=auth.uid() and active) $$;

alter table public.profiles enable row level security;
alter table public.parking_lots enable row level security;
alter table public.parking_slots enable row level security;
alter table public.lot_staff enable row level security;
alter table public.vehicles enable row level security;
alter table public.bookings enable row level security;
alter table public.parking_events enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.operation_receipts enable row level security;
alter table public.favorites enable row level security;

create policy profiles_read on public.profiles for select to authenticated using(
  id=auth.uid() or exists(select 1 from public.lot_staff s where s.user_id=profiles.id and public.owns_lot(s.lot_id))
  or exists(select 1 from public.bookings b where b.customer_id=profiles.id and public.works_lot(b.lot_id))
);
create policy lots_read on public.parking_lots for select to authenticated using(enabled or public.works_lot(id));
create policy slots_read on public.parking_slots for select to authenticated using(exists(
  select 1 from public.parking_lots l where l.id=lot_id and (l.enabled or public.works_lot(l.id))));
create policy staff_read on public.lot_staff for select to authenticated using(user_id=auth.uid() or public.owns_lot(lot_id));
create policy vehicles_read on public.vehicles for select to authenticated using(user_id=auth.uid() or exists(
  select 1 from public.bookings b where b.vehicle_id=vehicles.id and public.works_lot(b.lot_id)));
create policy bookings_read on public.bookings for select to authenticated using(customer_id=auth.uid() or public.works_lot(lot_id));
create policy events_read on public.parking_events for select to authenticated using(exists(
  select 1 from public.bookings b where b.id=booking_id and (b.customer_id=auth.uid() or public.works_lot(b.lot_id))));
create policy payments_read on public.payments for select to authenticated using(exists(
  select 1 from public.bookings b where b.id=booking_id and (b.customer_id=auth.uid() or public.owns_lot(b.lot_id))));
create policy notifications_read on public.notifications for select to authenticated using(user_id=auth.uid());
create policy favorites_read on public.favorites for select to authenticated using(user_id=auth.uid());
-- All writes go through checked RPCs. No client UPDATE permission on role, fees or state.
revoke all on public.profiles,public.parking_lots,public.parking_slots,public.lot_staff,
 public.vehicles,public.bookings,public.parking_events,public.payments,public.notifications,
 public.operation_receipts,public.favorites from anon,authenticated;
grant select on public.profiles,public.parking_lots,public.parking_slots,public.lot_staff,
 public.vehicles,public.bookings,public.parking_events,public.payments,public.notifications,public.favorites to authenticated;

create function public.slot_availability(p_lot_id uuid,p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_end<=p_start or p_end-p_start>interval '7 days' then raise exception 'INVALID_TIME'; end if;
 if not exists(select 1 from public.parking_lots where id=p_lot_id and (enabled or public.works_lot(id))) then
   raise exception 'LOT_UNAVAILABLE'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'code',s.code,'lot_id',s.lot_id,
  'enabled',s.enabled,'occupied',not s.enabled or exists(select 1 from public.bookings b where b.slot_id=s.id
  and (b.status='parked' or (b.status='confirmed' and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(p_start,p_end,'[)')))))
  order by s.code) from public.parking_slots s where s.lot_id=p_lot_id),'[]');
end $$;

create function public.current_slots() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'lot_id',s.lot_id,'code',s.code,'enabled',s.enabled,
  'occupied',not s.enabled or exists(select 1 from public.bookings b where b.slot_id=s.id and
   (b.status='parked' or (b.status='confirmed' and b.starts_at<=now() and b.ends_at>now())))) order by s.code),'[]'::jsonb)
 from public.parking_slots s join public.parking_lots l on l.id=s.lot_id
 where auth.uid() is not null and (l.enabled or public.works_lot(l.id))
$$;
create function public.park_snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
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
 'server_time',now())
$$;

-- Durable command endpoint; repeat of the same ID and payload returns the same result.
create function public.apply_operation(p_operation_id uuid,p_kind text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); previous public.operation_receipts; result jsonb;
 b public.bookings; v public.vehicles; s public.parking_slots; l public.parking_lots;
 item_id uuid; observed timestamptz; rate integer; minutes integer; fee integer;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,0));
 select * into previous from public.operation_receipts where actor_id=actor and operation_id=p_operation_id;
 if found then
   if previous.kind<>p_kind or previous.payload<>p_payload then raise exception 'OPERATION_ID_REUSED'; end if;
   return previous.result;
 end if;
 if p_kind='booking.create' then
   item_id:=(p_payload->>'id')::uuid;
   select * into v from public.vehicles where id=(p_payload->>'vehicle_id')::uuid and user_id=actor and not deleted;
   if not found then raise exception 'VEHICLE_NOT_FOUND'; end if;
   select * into s from public.parking_slots where id=(p_payload->>'slot_id')::uuid for update;
   if not found or not s.enabled then raise exception 'SLOT_UNAVAILABLE'; end if;
   select * into l from public.parking_lots where id=s.lot_id;
   if not l.enabled then raise exception 'LOT_UNAVAILABLE'; end if;
   if (p_payload->>'starts_at')::timestamptz < now()-interval '5 minutes'
     or (p_payload->>'ends_at')::timestamptz <= (p_payload->>'starts_at')::timestamptz
     or (p_payload->>'ends_at')::timestamptz-(p_payload->>'starts_at')::timestamptz>interval '7 days'
     then raise exception 'INVALID_TIME'; end if;
   if exists(select 1 from public.bookings where slot_id=s.id and status='parked') then raise exception 'SLOT_UNAVAILABLE'; end if;
   rate:=case when v.kind='motorcycle' then l.motorcycle_rate else l.car_rate end;
   insert into public.bookings(id,customer_id,vehicle_id,lot_id,slot_id,plate,starts_at,ends_at,hourly_rate,free_minutes)
   values(item_id,actor,v.id,l.id,s.id,v.plate,(p_payload->>'starts_at')::timestamptz,
     (p_payload->>'ends_at')::timestamptz,rate,l.free_minutes) returning * into b;
   insert into public.notifications(user_id,title,body) values(actor,'Đặt chỗ thành công',l.name||' · '||s.code);
   result:=to_jsonb(b);
 elsif p_kind in ('booking.cancel','staff.check_in','staff.check_out') then
   select * into b from public.bookings where id=(p_payload->>'booking_id')::uuid for update;
   if not found then raise exception 'TICKET_NOT_FOUND'; end if;
   if p_kind='booking.cancel' then
     if b.customer_id<>actor and not public.owns_lot(b.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   else
     if not public.works_lot(b.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
     if p_payload->>'qr_token' is distinct from b.qr_token then raise exception 'INVALID_QR'; end if;
   end if;
   if b.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
   if p_kind='booking.cancel' then
     if b.status<>'confirmed' or (b.customer_id=actor and now()>=b.starts_at) then raise exception 'INVALID_STATE'; end if;
     update public.bookings set status='cancelled',version=version+1 where id=b.id returning * into b;
   else
     observed:=(p_payload->>'occurred_at')::timestamptz;
     -- Device time is an observation, never an unrestricted fee override.
     if observed is null or observed>now()+interval '5 minutes' or observed<now()-interval '24 hours'
       then raise exception 'CLOCK_REVIEW_REQUIRED'; end if;
     if regexp_replace(upper(p_payload->>'plate'),'[^A-Z0-9]','','g') is distinct from b.plate then raise exception 'PLATE_MISMATCH'; end if;
     perform 1 from public.parking_slots where id=b.slot_id for update;
     if p_kind='staff.check_in' then
       if b.status<>'confirmed' or observed<b.starts_at-interval '15 minutes' or observed>=b.ends_at then raise exception 'INVALID_STATE'; end if;
       if not exists(select 1 from public.parking_slots where id=b.slot_id and enabled) then raise exception 'SLOT_UNAVAILABLE'; end if;
       update public.bookings set status='parked',checked_in_at=observed,version=version+1 where id=b.id returning * into b;
     else
       if b.status<>'parked' or observed<b.checked_in_at then raise exception 'INVALID_STATE'; end if;
       minutes:=ceil(extract(epoch from (observed-b.checked_in_at))/60);
       fee:=case when minutes<=b.free_minutes then 0 else ceil(minutes/60.0)::integer*b.hourly_rate end;
       update public.bookings set status='completed',checked_out_at=observed,amount=fee,version=version+1 where id=b.id returning * into b;
       insert into public.payments(booking_id,amount,received_by,paid_at) values(b.id,fee,actor,observed);
     end if;
     insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at)
       values(p_operation_id,b.id,actor,substring(p_kind from 7),b.plate,observed);
   end if;
   insert into public.notifications(user_id,title,body) values(b.customer_id,
      case b.status when 'cancelled' then 'Đã hủy đặt chỗ' when 'parked' then 'Xe đã vào bãi' else 'Xe đã ra bãi' end,b.plate);
   result:=to_jsonb(b);
 elsif p_kind='vehicle.save' then
   item_id:=(p_payload->>'id')::uuid;
   perform pg_advisory_xact_lock(hashtextextended(actor::text,1));
   select * into v from public.vehicles where id=item_id for update;
   if found and v.user_id<>actor then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if found and v.version is distinct from (p_payload->>'expected_version')::integer then raise exception 'VERSION_CONFLICT'; end if;
   if found and exists(select 1 from public.bookings where vehicle_id=v.id and status in ('confirmed','parked'))
     and (v.plate<>p_payload->>'plate' or v.kind<>p_payload->>'kind' or coalesce((p_payload->>'deleted')::boolean,false)) then raise exception 'VEHICLE_IN_USE'; end if;
   if coalesce((p_payload->>'is_default')::boolean,false) then
     update public.vehicles set is_default=false,version=version+1 where user_id=actor and is_default and id<>item_id;
   end if;
   insert into public.vehicles(id,user_id,label,plate,kind,is_default,deleted)
   values(item_id,actor,p_payload->>'label',p_payload->>'plate',p_payload->>'kind',
     coalesce((p_payload->>'is_default')::boolean,false),coalesce((p_payload->>'deleted')::boolean,false))
   on conflict(id) do update set label=excluded.label,plate=excluded.plate,kind=excluded.kind,
     is_default=excluded.is_default,deleted=excluded.deleted,version=vehicles.version+1 returning * into v;
   result:=to_jsonb(v);
 elsif p_kind='favorite.set' then
   if not exists(select 1 from public.parking_lots where id=(p_payload->>'lot_id')::uuid and enabled) then raise exception 'LOT_UNAVAILABLE'; end if;
   if (p_payload->>'enabled')::boolean then
     insert into public.favorites(user_id,lot_id) values(actor,(p_payload->>'lot_id')::uuid) on conflict do nothing;
   else delete from public.favorites where user_id=actor and lot_id=(p_payload->>'lot_id')::uuid; end if;
   result:=jsonb_build_object('ok',true);
 elsif p_kind='profile.update' then
   if length(trim(coalesce(p_payload->>'name','')))=0 then raise exception 'INVALID_NAME'; end if;
   update public.profiles set name=left(trim(p_payload->>'name'),100),phone=left(coalesce(p_payload->>'phone',''),30) where id=actor;
   result:=jsonb_build_object('ok',true);
 elsif p_kind='notifications.read' then
   update public.notifications set read=true where user_id=actor;
   result:=jsonb_build_object('ok',true);
 else raise exception 'UNKNOWN_OPERATION'; end if;
 insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values(actor,p_operation_id,p_kind,p_payload,result);
 return result;
end $$;

create function public.manage_lot(p_id uuid,p_name text,p_area text,p_enabled boolean,p_capacity integer,
 p_latitude double precision default null,p_longitude double precision default null,p_expected_version integer default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare l public.parking_lots; current_count integer; i integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and role='owner') then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_capacity not between 1 and 500 then raise exception 'INVALID_CAPACITY'; end if;
 select * into l from public.parking_lots where id=p_id for update;
 if found then
   if l.owner_id<>auth.uid() then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if l.version is distinct from p_expected_version then raise exception 'VERSION_CONFLICT'; end if;
   select count(*) into current_count from public.parking_slots where lot_id=p_id;
   -- Shrinking a lot with tickets requires deliberate slot management; never erase a live slot.
   if p_capacity<current_count then raise exception 'USE_SLOT_MANAGEMENT_TO_DISABLE'; end if;
   update public.parking_lots set name=p_name,area=p_area,enabled=p_enabled,latitude=p_latitude,
     longitude=p_longitude,version=version+1 where id=p_id;
 else
   insert into public.parking_lots(id,owner_id,name,area,enabled,latitude,longitude)
    values(p_id,auth.uid(),p_name,p_area,p_enabled,p_latitude,p_longitude);
   current_count:=0;
 end if;
 for i in current_count+1..p_capacity loop
   insert into public.parking_slots(lot_id,code) values(p_id,'A'||lpad(i::text,3,'0'));
 end loop;
 return p_id;
end $$;
create function public.manage_slot(p_id uuid,p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
declare s public.parking_slots;
begin
 select * into s from public.parking_slots where id=p_id for update;
 if not found or not public.owns_lot(s.lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if not p_enabled and exists(select 1 from public.bookings where slot_id=p_id and (status='parked' or (status='confirmed' and ends_at>now()))) then raise exception 'SLOT_IN_USE'; end if;
 update public.parking_slots set enabled=p_enabled where id=p_id;
end $$;
create function public.set_pricing(p_lot_id uuid,p_car integer,p_motorcycle integer,p_free_minutes integer,p_expected_version integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.owns_lot(p_lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 update public.parking_lots set car_rate=p_car,motorcycle_rate=p_motorcycle,free_minutes=p_free_minutes,version=version+1
 where id=p_lot_id and version=p_expected_version;
 if not found then raise exception 'VERSION_CONFLICT'; end if;
end $$;
create function public.manage_staff(p_lot_id uuid,p_email text,p_shift text,p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if not public.owns_lot(p_lot_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select id into person from public.profiles where lower(email)=lower(trim(p_email));
 if person is null then raise exception 'USER_MUST_REGISTER_FIRST'; end if;
 insert into public.lot_staff(lot_id,user_id,shift,active) values(p_lot_id,person,p_shift,p_active)
 on conflict(lot_id,user_id) do update set shift=excluded.shift,active=excluded.active;
 update public.profiles set role='staff' where id=person and role='customer';
end $$;

-- Private optional evidence bucket. OCR itself runs on-device and does not upload images.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('parking-evidence','parking-evidence',false,5242880,array['image/jpeg','image/png']) on conflict(id) do nothing;
create policy evidence_own_insert on storage.objects for insert to authenticated with check(
 bucket_id='parking-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
create policy evidence_own_read on storage.objects for select to authenticated using(
 bucket_id='parking-evidence' and (storage.foldername(name))[1]=auth.uid()::text);

do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('handle_new_user','owns_lot','works_lot','current_slots','park_snapshot',
  'slot_availability','apply_operation','manage_lot','manage_slot','set_pricing','manage_staff') loop
   execute format('revoke execute on function %s from public,anon,authenticated',f.signature);
 end loop;
end $$;
grant execute on function public.owns_lot(uuid),public.works_lot(uuid),public.current_slots(),public.park_snapshot(),
 public.slot_availability(uuid,timestamptz,timestamptz),public.apply_operation(uuid,text,jsonb),
 public.manage_lot(uuid,text,text,boolean,integer,double precision,double precision,integer),
 public.manage_slot(uuid,boolean),public.set_pricing(uuid,integer,integer,integer,integer),
 public.manage_staff(uuid,text,text,boolean) to authenticated;

do $$ declare t text; begin
 foreach t in array array['parking_lots','parking_slots','lot_staff','vehicles','bookings','payments','notifications','favorites'] loop
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
   execute format('alter publication supabase_realtime add table public.%I',t);
  end if;
 end loop;
end $$;
commit;
