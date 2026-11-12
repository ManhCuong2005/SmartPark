-- CLOUD ONLY: after migration 004, run once in Supabase SQL Editor.
-- Enables expiry + in-app reminders even when all phones are closed.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('smartpark-booking-deadlines','* * * * *',
 $$select smartpark_private.process_deadlines();$$);
-- cron.schedule updates an existing job with this name; do not create duplicates.
-- Inspect status: select * from cron.job_run_details order by start_time desc limit 10;
