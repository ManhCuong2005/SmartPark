-- CLOUD ONLY, AFTER Firebase and the Edge Function are configured.
-- First create the Vault secret named smartpark_push_dispatch_secret with the
-- SAME random value as Edge secret PUSH_DISPATCH_SECRET. Never commit its value.
create extension if not exists pg_net with schema extensions;
create or replace function smartpark_private.dispatch_push_tick() returns void
language plpgsql security definer set search_path='' as $$
declare dispatch_secret text;
begin
 select decrypted_secret into dispatch_secret from vault.decrypted_secrets
 where name='smartpark_push_dispatch_secret' limit 1;
 if dispatch_secret is null or length(dispatch_secret)<32 then
   raise exception 'Configure smartpark_push_dispatch_secret in Supabase Vault first';
 end if;
 perform net.http_post(
   url:='https://odpxmbkzdqutxitsdfaw.supabase.co/functions/v1/push-dispatch',
   headers:=jsonb_build_object('Content-Type','application/json','x-smartpark-dispatch-secret',dispatch_secret),
   -- A batch may wait for several bounded FCM/database requests. pg_net is
   -- asynchronous, so this timeout does not block the cron SQL transaction.
   body:='{}'::jsonb,timeout_milliseconds:=120000);
end $$;
revoke all on function smartpark_private.dispatch_push_tick() from public,anon,authenticated;
select cron.schedule('smartpark-push-dispatch','* * * * *',
 $$select smartpark_private.dispatch_push_tick();$$);
