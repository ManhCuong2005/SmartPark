// Disposable test PostgreSQL only. The application always uses Supabase Cloud.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readdirSync } from 'node:fs';
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
 for(const file of ['supabase/tests/bootstrap.sql',...migrations,'supabase/tests/behavior.sql']){
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
 if(outcomes.filter(o=>o.code===0).length!==1||!outcomes.some(o=>o.output.includes('exclusion constraint')))throw new Error(JSON.stringify(outcomes));
 console.log('PASS concurrent sessions: exactly one overlapping reservation accepted');
}finally{
 if(started){run(binary('pg_ctl'),['-D',cluster,'-m','immediate','-w','stop']);console.log('Stopped disposable test server. App backend remains Supabase Cloud.');}
}
