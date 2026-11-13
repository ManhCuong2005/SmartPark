-- SMARTPARK DEMO DATA - run in Supabase Cloud SQL Editor AFTER migrations 001–010.
-- All parking locations, vehicles and payments below are fictional test data.
-- Uses existing, confirmed Auth accounts; never creates accounts or passwords.
-- A single owner can test both mobile apps; separate accounts are recommended
-- for testing RLS. Change the three configuration values below if needed.
-- Re-running preserves existing demo rows, edited prices, capacities and tickets.
-- It does NOT renew old reservation times or reset tickets after check-out.
-- No application tables, RLS policies or real operational rows are deleted.

begin;
set local search_path = public, extensions;
set local timezone = 'Asia/Ho_Chi_Minh';

do $seed$
declare
  -- CONFIGURATION: only email addresses, never passwords.
  owner_email text := 'manhcuongnguyen2205@gmail.com';
  customer_emails text[] := array['dadinhviruscorona@gmail.com'];
  staff_emails text[] := array['cuongnm.23it@vku.udn.vn'];

  owner_uid uuid;
  customer_uids uuid[] := '{}';
  staff_uids uuid[] := '{}';
  lot_ids uuid[] := '{}';
  vehicle_ids uuid[] := '{}';
  email_value text;
  person_uid uuid;
  seed_prefix text;
  lot_record record;
  ticket_record record;
  ticket public.bookings;
  vehicle public.vehicles;
  lot public.parking_lots;
  new_id uuid;
  lot_index integer;
  i integer;
  day_index integer;
  rate integer;
  plate_base integer;
  minutes integer;
  fee integer;
  actor_uid uuid;
  t_in timestamptz;
  t_out timestamptz;
  vn_today timestamptz := date_trunc('day', now());
  car_labels text[] := array['Toyota Vios','Hyundai Accent','Kia Seltos',
    'Mazda CX-5','Honda City','VinFast VF 5','Toyota Corolla Cross',
    'Mitsubishi Xpander','Hyundai Creta','Kia Morning','Ford Ranger','Suzuki XL7'];
  motorcycle_labels text[] := array['Honda Vision','Honda Air Blade','Honda SH',
    'Yamaha Grande','Yamaha Janus','Honda Wave Alpha','Honda Future',
    'Yamaha Sirius','Honda Lead','Yamaha NVX','VinFast Evo200','Honda Winner X'];
begin
  if to_regclass('public.bookings') is null or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='parking_lots' and column_name='car_capacity'
  ) then
    raise exception 'Run all SmartPark migrations through 010 first. Do not run test fixtures in Cloud.';
  end if;

  select id into owner_uid from auth.users
  where lower(email)=lower(trim(owner_email)) and email_confirmed_at is not null;
  if owner_uid is null then
    raise exception 'Owner email % must be registered and confirmed first.', owner_email;
  end if;
  if coalesce(cardinality(customer_emails),0)=0 or coalesce(cardinality(staff_emails),0)=0 then
    raise exception 'Provide at least one confirmed customer email and one staff email (owner can be reused for a single-account demo).';
  end if;
  -- Stop concurrent executions of this seed for the same owner.
  perform pg_advisory_xact_lock(hashtextextended('smartpark-demo-v1:'||owner_uid::text,0));

  foreach email_value in array customer_emails loop
    select id into person_uid from auth.users
    where lower(email)=lower(trim(email_value)) and email_confirmed_at is not null;
    if person_uid is null or not exists(select 1 from public.profiles where id=person_uid) then
      raise exception 'Customer email % must be registered and confirmed first.', email_value;
    end if;
    if not person_uid=any(customer_uids) then
      customer_uids:=array_append(customer_uids,person_uid);
    end if;
  end loop;
  foreach email_value in array staff_emails loop
    select id into person_uid from auth.users
    where lower(email)=lower(trim(email_value)) and email_confirmed_at is not null;
    if person_uid is null or not exists(select 1 from public.profiles where id=person_uid) then
      raise exception 'Staff email % must be registered and confirmed first.', email_value;
    end if;
    if not person_uid=any(staff_uids) then
      staff_uids:=array_append(staff_uids,person_uid);
    end if;
  end loop;
  if not exists(select 1 from public.profiles where id=owner_uid) then
    raise exception 'Owner profile missing. Run the SmartPark migrations first.';
  end if;

  update public.profiles set role='owner' where id=owner_uid;
  -- Never demote an existing owner, including the single-account demo owner.
  update public.profiles set role='staff'
  where id=any(staff_uids) and role='customer' and not id=any(customer_uids);
  seed_prefix:='smartpark-demo-v1:'||owner_uid::text||':';

  for lot_record in select * from (values
    (1,'Cầu Rồng','Khu vực đường Trần Hưng Đạo, Sơn Trà',16.0612,108.2312,15000,4000,10),
    (2,'Biển Mỹ Khê','Khu vực Võ Nguyên Giáp, Sơn Trà',16.0544,108.2471,20000,5000,10),
    (3,'Chợ Hàn','Khu vực Trần Phú, Hải Châu',16.0678,108.2241,18000,5000,5),
    (4,'Trung tâm Hải Châu','Khu vực Nguyễn Văn Linh, Hải Châu',16.0608,108.2163,15000,4000,15),
    (5,'Công viên 29/3','Khu vực Điện Biên Phủ, Thanh Khê',16.0631,108.2012,10000,3000,15),
    (6,'Khu đại học','Khu vực Ngũ Hành Sơn',16.0156,108.2445,10000,2000,10),
    (7,'Bờ sông Hàn','Khu vực Bạch Đằng, Hải Châu',16.0774,108.2238,20000,5000,5),
    (8,'Khu dân cư Cẩm Lệ','Khu vực Cẩm Lệ',16.0144,108.2081,12000,3000,10)
  ) as locations(n,name,area,lat,lng,car,motorcycle,free_mins) loop
    new_id:=md5(seed_prefix||'lot:'||lot_record.n)::uuid;
    lot_ids:=array_append(lot_ids,new_id);
    insert into public.parking_lots(id,owner_id,name,area,latitude,longitude,
      car_rate,motorcycle_rate,free_minutes,car_capacity,motorcycle_capacity,created_at)
    values(new_id,owner_uid,'[DEMO] SmartPark '||lot_record.name,
      lot_record.area||' — địa điểm mô phỏng',lot_record.lat,lot_record.lng,
      lot_record.car,lot_record.motorcycle,0,38,38,now()-interval '45 days')
    on conflict(id) do nothing;
    foreach person_uid in array staff_uids loop
      insert into public.lot_staff(lot_id,user_id,shift,active)
      values(lot_ids[lot_record.n],person_uid,
        (array['morning','afternoon','night'])[1+(lot_record.n-1)%3],true)
      on conflict(lot_id,user_id) do nothing;
    end loop;
  end loop;

  plate_base:=10000+(('x'||substr(md5(owner_uid::text),1,7))::bit(28)::integer % 70000);
  for i in 1..24 loop
    new_id:=md5(seed_prefix||'vehicle:'||i)::uuid;
    person_uid:=customer_uids[1+(i-1)%cardinality(customer_uids)];
    vehicle_ids:=array_append(vehicle_ids,new_id);
    -- Do not overwrite an existing default vehicle. Defaults are chosen in-app.
    insert into public.vehicles(id,user_id,label,plate,kind,is_default)
    values(new_id,person_uid,
      '[DEMO] '||(case when i<=12 then car_labels[i] else motorcycle_labels[i-12] end),
      (case when i<=12 then '43A' else '43B1' end)||lpad((plate_base+i)::text,5,'0'),
      case when i<=12 then 'car' else 'motorcycle' end,false)
    on conflict(id) do nothing;
  end loop;

  -- Staging exists only during this transaction, never in the application schema.
  create temporary table smartpark_demo_tickets(
    seed_key text, vehicle_n integer, lot_n integer, slot_n integer,
    status text, starts_at timestamptz, ends_at timestamptz,
    checked_in_at timestamptz, checked_out_at timestamptz, created_at timestamptz
  ) on commit drop;

  -- 720 completed visits across the past 30 days, 24 per day.
  -- Every vehicle has at most one historical visit per day.
  for day_index in 1..30 loop
    for i in 1..24 loop
      lot_index:=1+(i+day_index-2)%8;
      t_in:=vn_today-make_interval(days=>day_index)
        +make_interval(hours=>7+(i-1)/8,mins=>(i*7)%45);
      t_out:=t_in+make_interval(mins=>25+(i*17+day_index*11)%240);
      insert into smartpark_demo_tickets values(
        'history:'||day_index||':'||i,i,lot_index,1+(i-1)/8,
        'completed',t_in-interval '5 minutes',t_out+interval '15 minutes',
        t_in,t_out,t_in-interval '1 hour');
    end loop;
  end loop;
  -- 16 recently completed visits, ensuring recent dashboard activity.
  for i in 1..16 loop
    t_out:=now()-make_interval(mins=>120+i*3);
    t_in:=t_out-make_interval(mins=>case when i=1 then 5 else 25+i*4 end);
    insert into smartpark_demo_tickets values('recent:'||i,i,1+(i-1)%8,
      4+(i-1)/8,'completed',t_in,t_out+interval '15 minutes',t_in,t_out,t_in-interval '30 minutes');
  end loop;
  -- 32 cancelled reservations without payments or check-in events.
  for day_index in 0..7 loop
    for i in 1..4 loop
      t_in:=vn_today-make_interval(days=>day_index)+make_interval(hours=>10+i);
      insert into smartpark_demo_tickets values('cancelled:'||day_index||':'||i,
        16+i,1+(day_index+i-1)%8,12+i,'cancelled',t_in,t_in+interval '2 hours',
        null,null,least(now()-interval '10 minutes',t_in-interval '2 hours'));
    end loop;
  end loop;
  for i in 1..8 loop
    -- One occupied slot per lot, ready for staff check-out.
    insert into smartpark_demo_tickets values('parked:'||i,i,i,1,'parked',
      now()-interval '1 hour',now()+interval '2 hours',
      now()-make_interval(mins=>10+i*5),null,now()-interval '2 hours');
    -- A different vehicle/slot per lot, ready to scan QR and check in now.
    insert into smartpark_demo_tickets values('ready:'||i,8+i,i,2,'confirmed',
      now()-interval '5 minutes',now()+interval '3 hours',null,null,now()-interval '30 minutes');
    -- Tomorrow's reservations can be cancelled from the customer app.
    t_in:=vn_today+interval '1 day 9 hours';
    insert into smartpark_demo_tickets values('future:'||i,i,i,3,'confirmed',
      t_in,t_in+interval '2 hours',null,null,now());
  end loop;

  for ticket_record in select * from smartpark_demo_tickets loop
    new_id:=md5(seed_prefix||'booking:'||ticket_record.seed_key)::uuid;
    -- Skip the entire ticket on rerun, preserving its current operational state.
    if exists(select 1 from public.bookings where id=new_id) then continue; end if;
    select * into vehicle from public.vehicles where id=vehicle_ids[ticket_record.vehicle_n];
    select * into lot from public.parking_lots where id=lot_ids[ticket_record.lot_n];
    actor_uid:=staff_uids[1+(ticket_record.lot_n-1)%cardinality(staff_uids)];
    rate:=case when vehicle.kind='motorcycle' then lot.motorcycle_rate else lot.car_rate end;
    fee:=0;
    if ticket_record.status='completed' then
      minutes:=ceil(extract(epoch from (ticket_record.checked_out_at-ticket_record.checked_in_at))/60)::integer;
      fee:=smartpark_private.parking_fee(ticket_record.checked_in_at,ticket_record.checked_out_at,rate);
    end if;
    insert into public.bookings(id,customer_id,vehicle_id,lot_id,plate,vehicle_kind,
      starts_at,ends_at,status,hourly_rate,free_minutes,amount,
      checked_in_at,checked_out_at,version,created_at)
    values(new_id,vehicle.user_id,vehicle.id,lot.id,
      vehicle.plate,vehicle.kind,
      ticket_record.starts_at,ticket_record.ends_at,ticket_record.status,rate,lot.free_minutes,fee,
      ticket_record.checked_in_at,ticket_record.checked_out_at,
      case when ticket_record.status='completed' then 3 when ticket_record.status in ('parked','cancelled') then 2 else 1 end,
      ticket_record.created_at)
    returning * into ticket;
    if ticket.checked_in_at is not null then
      insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at,received_at)
      values(md5(seed_prefix||'in:'||ticket_record.seed_key)::uuid,ticket.id,actor_uid,
        'check_in',ticket.plate,ticket.checked_in_at,ticket.checked_in_at);
    end if;
    if ticket.status='completed' then
      insert into public.parking_events(id,booking_id,actor_id,kind,plate,occurred_at,received_at)
      values(md5(seed_prefix||'out:'||ticket_record.seed_key)::uuid,ticket.id,actor_uid,
        'check_out',ticket.plate,ticket.checked_out_at,ticket.checked_out_at);
      insert into public.payments(id,booking_id,amount,received_by,paid_at)
      values(md5(seed_prefix||'payment:'||ticket_record.seed_key)::uuid,
        ticket.id,ticket.amount,actor_uid,ticket.checked_out_at);
    end if;
    insert into public.notifications(id,user_id,title,body,read,created_at)
    values(md5(seed_prefix||'notification:'||ticket_record.seed_key)::uuid,ticket.customer_id,
      '[DEMO] '||case ticket.status when 'completed' then 'Xe đã ra bãi'
        when 'parked' then 'Xe đã vào bãi' when 'cancelled' then 'Đã hủy đặt chỗ'
        else 'Đặt chỗ thành công' end,
      lot.name||' · '||ticket.plate||case when ticket.status='completed' then ' · '||fee||' VND (thu tiền mô phỏng)' else '' end,
      ticket_record.seed_key like 'history:%' or ticket_record.seed_key like 'cancelled:%',
      coalesce(ticket.checked_out_at,ticket.checked_in_at,ticket.created_at));
  end loop;

  foreach person_uid in array customer_uids loop
    for i in 1..3 loop
      insert into public.favorites(user_id,lot_id) values(person_uid,lot_ids[i])
      on conflict(user_id,lot_id) do nothing;
    end loop;
  end loop;
  raise notice 'Demo ready: 8 lots, 320 slots (16 disabled), 24 vehicles, 792 tickets, 736 simulated cash payments. Existing demo rows preserved on rerun.';
end $seed$;

-- The SQL Editor returns this summary after a successful transaction.
select l.id,l.name,l.car_capacity,l.motorcycle_capacity,
 (select count(*) from public.bookings b where b.lot_id=l.id) as tong_ve,
 (select coalesce(sum(p.amount),0) from public.payments p join public.bookings b on b.id=p.booking_id where b.lot_id=l.id) as doanh_thu_mo_phong_vnd
from public.parking_lots l where l.name like '[DEMO] SmartPark %' order by l.name;
commit;
