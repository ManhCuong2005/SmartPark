// Disposable test PostgreSQL only. The application always uses Supabase Cloud.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import net from 'node:net';
const root=resolve(fileURLToPath(new URL('..',import.meta.url))),args=process.argv.slice(2);
const option=name=>args.includes(name)?args[args.indexOf(name)+1]:undefined;
const pgBin=option('--pg-bin'),binary=name=>pgBin?join(pgBin,name+(process.platform==='win32'?'.exe':'')):name;
function run(command,params){
 const r=spawnSync(command,params,{encoding:'utf8',windowsHide:true,timeout:60000});
 if(r.status!==0)throw new Error(`${command}: ${r.stderr||r.stdout||r.error}`);
 return r.stdout;
}
let url=option('--url'),cluster,started=false;
try{
 if(url){
  const p=new URL(url);if(!['localhost','127.0.0.1'].includes(p.hostname)||!p.pathname.endsWith('_test'))throw new Error('Refusing non-local/non-test database');
 }else{
  const work=join(root,'.smartpark','backend-tests');mkdirSync(work,{recursive:true});cluster=mkdtempSync(join(work,'postgres-'));
  const server=net.createServer();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const port=server.address().port;await new Promise(resolve=>server.close(resolve));
  run(binary('initdb'),['-D',cluster,'-U','postgres','--auth=trust','--encoding=UTF8','--locale=C']);
  run(binary('pg_ctl'),['-D',cluster,'-l',join(cluster,'server.log'),'-o',`-p ${port} -h 127.0.0.1 -c wal_level=logical`,'-w','start']);started=true;
  run(binary('createdb'),['-h','127.0.0.1','-p',String(port),'-U','postgres','smartpark_test']);
  url=`postgresql://postgres@127.0.0.1:${port}/smartpark_test`;
 }
 const migrations=readdirSync(join(root,'supabase','migrations')).filter(f=>f.endsWith('.sql')).sort().map(f=>'supabase/migrations/'+f);
 const expiryPolicy='supabase/migrations/202611120008_expiry_and_extensions.sql';
 // Verify the historical grace-period behavior before the policy change, then
 // verify deletion and extensions against the final schema. Never rewrite old migrations.
 for(const file of ['supabase/tests/bootstrap.sql',...migrations.filter(f=>f<expiryPolicy),'supabase/tests/behavior.sql','supabase/tests/staff_permissions.sql','supabase/tests/deadlines_and_push.sql','supabase/tests/reminder_flow.sql','supabase/tests/booking_flow.sql','supabase/tests/booking_availability.sql','supabase/tests/paid_checkout.sql',...migrations.filter(f=>f>=expiryPolicy),'supabase/tests/expiry_and_extensions.sql']){
  run(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-f',join(root,file)]);console.log(`PASS ${file}`);
 }
 const reservation=n=>`begin; set local role authenticated;
  select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
  select public.apply_operation('70000000-0000-0000-0000-${String(n).padStart(12,'0')}','booking.create',jsonb_build_object(
   'id','80000000-0000-0000-0000-${String(n).padStart(12,'0')}','vehicle_id','50000000-0000-0000-0000-000000000001',
   'slot_id','30000000-0000-0000-0000-000000000002','starts_at',date_trunc('hour',now())+interval '1 day',
   'ends_at',date_trunc('hour',now())+interval '25 hours'));
  select pg_sleep(0.5); commit;`;
 const race=n=>new Promise((resolve,reject)=>{
  const child=spawn(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-c',reservation(n)],{windowsHide:true});
  let output='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>output+=d);
  child.on('error',reject);child.on('close',code=>resolve({code,output}));
 });
 const outcomes=await Promise.all([race(1),race(2)]);
 if(outcomes.filter(o=>o.code===0).length!==1||!outcomes.some(o=>/exclusion constraint|VEHICLE_TIME_CONFLICT|SLOT_TIME_CONFLICT/.test(o.output)))throw new Error(JSON.stringify(outcomes));
 console.log('PASS concurrent sessions: exactly one overlapping reservation accepted');
 if(args.includes('--demo-seed')){
  run(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-c',`
   alter table auth.users add column if not exists email_confirmed_at timestamptz default now();
   insert into auth.users(id,email,raw_user_meta_data) values
    ('90000000-0000-0000-0000-000000000001','demo-owner@test.invalid','{"name":"Demo Owner"}'),
    ('90000000-0000-0000-0000-000000000002','demo-customer@test.invalid','{"name":"Demo Customer"}'),
    ('90000000-0000-0000-0000-000000000003','demo-staff@test.invalid','{"name":"Demo Staff"}'),
    ('90000000-0000-0000-0000-000000000004','single-owner@test.invalid','{"name":"Single Owner"}');`]);
  const seedSource=readFileSync(join(root,'supabase/seed-demo.sql'),'utf8');
  const seedWork=join(root,'.smartpark','backend-tests');mkdirSync(seedWork,{recursive:true});
  const seedDir=cluster??mkdtempSync(join(seedWork,'seed-'));
  for(const single of [false,true]){
   const owner=single?'single-owner@test.invalid':'demo-owner@test.invalid';
   const customer=single?owner:'demo-customer@test.invalid',staff=single?owner:'demo-staff@test.invalid';
   const source=seedSource.replace(/owner_email text := '[^']*'/,`owner_email text := '${owner}'`)
    .replace(/customer_emails text\[\] := array\[[^\]]*\]/,`customer_emails text[] := array['${customer}']`)
    .replace(/staff_emails text\[\] := array\[[^\]]*\]/,`staff_emails text[] := array['${staff}']`);
   const seedFile=join(seedDir,`seed-${single?'single':'separate'}.sql`);writeFileSync(seedFile,source);
   run(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-f',seedFile]);
   run(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-v',`demo_owner=${owner}`,
    '-v',`demo_customer=${customer}`,'-v',`demo_staff=${staff}`,'-f',join(root,'supabase/tests/demo_seed.sql')]);
   // Test that re-running does not resurrect checked-out tickets, restore prices,
   // unread notifications, revoked memberships or disabled parking slots.
   const fingerprint=()=>run(binary('psql'),[url,'-X','-At','-v','ON_ERROR_STOP=1','-c',`
    select md5(string_agg(table_name||':'||row_data,E'\n' order by table_name,row_data)) from (
     ${['profiles','parking_lots','parking_slots','lot_staff','vehicles','bookings','parking_events','payments','notifications','favorites','operation_receipts']
       .map(table=>`select '${table}' as table_name,to_jsonb(t)::text as row_data from public.${table} t`).join(' union all ')}
    ) rows;`]).trim();
   const before=fingerprint();
   run(binary('psql'),[url,'-X','-v','ON_ERROR_STOP=1','-f',seedFile]);
   if(before!==fingerprint())throw new Error('Demo seed rerun overwrote operational data');
   console.log(`PASS demo seed (${single?'single owner':'three accounts'}): counts, fees, RLS, QR workflow and non-destructive rerun`);
  }
 }
}finally{
 if(started){run(binary('pg_ctl'),['-D',cluster,'-m','immediate','-w','stop']);console.log('Stopped disposable test server. App backend remains Supabase Cloud.');}
}
