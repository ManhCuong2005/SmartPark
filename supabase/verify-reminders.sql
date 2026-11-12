-- Read-only Cloud diagnostic. Run as project owner in SQL Editor if needed.
-- Returns no email, vehicle plate, QR, device token or secret.
-- Requires migration 004 + setup-reminder-scheduler.sql, already confirmed run.
select jsonb_pretty(jsonb_build_object(
 'checked_at_vietnam',to_char(now() at time zone 'Asia/Ho_Chi_Minh','YYYY-MM-DD HH24:MI:SS'),
 'deadline_job_active',exists(select 1 from cron.job
   where jobname='smartpark-booking-deadlines' and active and schedule='* * * * *'),
 'push_job_active',exists(select 1 from cron.job
   where jobname='smartpark-push-dispatch' and active and schedule='* * * * *'),
 'recent_deadline_runs',coalesce((select jsonb_agg(to_jsonb(r)) from (
   select d.status,to_char(d.start_time at time zone 'Asia/Ho_Chi_Minh','YYYY-MM-DD HH24:MI:SS') as started_at_vietnam
   from cron.job_run_details d join cron.job j on j.jobid=d.jobid
   where j.jobname='smartpark-booking-deadlines' order by d.start_time desc limit 5
 ) r),'[]'::jsonb),
 'recent_push_runs',coalesce((select jsonb_agg(to_jsonb(r)) from (
   select d.status,to_char(d.start_time at time zone 'Asia/Ho_Chi_Minh','YYYY-MM-DD HH24:MI:SS') as started_at_vietnam
   from cron.job_run_details d join cron.job j on j.jobid=d.jobid
   where j.jobname='smartpark-push-dispatch' order by d.start_time desc limit 5
 ) r),'[]'::jsonb),
 'registered_active_devices',(select count(*) from public.push_devices where active),
 'push_job_counts',coalesce((select jsonb_object_agg(state,total) from (
   select state,count(*) as total from public.push_jobs group by state
 ) j),'{}'::jsonb),
 'due_unprocessed_reservations',(select count(*) from public.bookings
   where status='confirmed' and checked_in_at is null and ends_at<=now()),
 'expired_reservations',(select count(*) from public.bookings where status='expired'),
 'reminder_counts',coalesce((select jsonb_object_agg(category,total) from (
   select category,count(*) as total from public.notifications
   where category in ('pickup_soon','pickup_overdue','booking_expired') group by category
 ) n),'{}'::jsonb),
 'anonymous_deadline_rpc_blocked',not has_function_privilege('anon','public.refresh_booking_deadlines()','EXECUTE'),
 'customer_push_worker_blocked',not has_function_privilege('authenticated','public.claim_push_jobs(integer)','EXECUTE'),
 'customer_push_devices_blocked',not has_table_privilege('authenticated','public.push_devices','SELECT'),
 'customer_push_jobs_blocked',not has_table_privilege('authenticated','public.push_jobs','SELECT')
));
