-- Run ONLY in Cloud SQL Editor, after registering and confirming your account.
-- Replace the email below with your own. Never accept an app-supplied role.
do $$
declare person uuid;
begin
 select id into person from auth.users
 where lower(email)=lower('manhcuongnguyen2205@gmail.com') and email_confirmed_at is not null;
 if person is null then raise exception 'Register and confirm this email before granting owner access'; end if;
 update public.profiles set role='owner' where id=person;
 if not found then raise exception 'Run SmartPark migrations first'; end if;
end $$;
