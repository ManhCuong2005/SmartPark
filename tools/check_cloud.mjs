// Read-only checks. Never logs keys, signs up users, or changes Cloud data/schema.
import { readFileSync } from 'node:fs';
const config=JSON.parse(readFileSync(new URL('../config/supabase.example.json',import.meta.url),'utf8'));
const base=config.SUPABASE_URL,headers={apikey:config.SUPABASE_PUBLISHABLE_KEY};
for(const path of ['/auth/v1/settings','/rest/v1/parking_lots?select=id&limit=0','/rest/v1/favorites?select=lot_id&limit=0']){
 try{
  const response=await fetch(base+path,{headers,signal:AbortSignal.timeout(12000)}),body=await response.json();
  console.log(JSON.stringify({path,status:response.status,code:body.code??null,
   emailEnabled:path.includes('settings')?body.external?.email:undefined,
   message:path.includes('settings')?undefined:body.message}));
 }catch(e){console.log(JSON.stringify({path,error:e.message}));process.exitCode=1;}
}
