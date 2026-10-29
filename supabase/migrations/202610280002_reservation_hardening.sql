-- Incremental migration; safe after 001. Prevents one vehicle reserving two
-- different slots for the same interval (including ambiguous client retries).
begin;
set local search_path=public,extensions;
alter table public.vehicles drop constraint vehicles_plate_check;
alter table public.vehicles add constraint vehicles_plate_check
 check(plate ~ '^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$');
alter table public.bookings add constraint bookings_vehicle_no_overlap
 exclude using gist (vehicle_id with =, tstzrange(starts_at,ends_at,'[)') with &&)
 where (status in ('confirmed','parked'));
-- Customers cannot subscribe to another customer's private booking. Bump a
-- public slot revision instead, prompting a fresh privacy-safe availability RPC.
alter table public.parking_slots add column revision integer not null default 1;
create function public.signal_slot_availability() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.parking_slots set revision=revision+1 where id=new.slot_id;
 if tg_op='UPDATE' and old.slot_id is distinct from new.slot_id then
  update public.parking_slots set revision=revision+1 where id=old.slot_id;
 end if;
 return new;
end $$;
revoke execute on function public.signal_slot_availability() from public,anon,authenticated;
create trigger smartpark_slot_availability after insert or update on public.bookings
 for each row execute function public.signal_slot_availability();
commit;
