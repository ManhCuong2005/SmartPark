// Local fake transport only: never contacts Firebase or Supabase.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createPushHandler } from '../supabase/functions/push-dispatch/core.ts';
const key = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5',
  modulusLength: 2048, publicExponent: new Uint8Array([1,0,1]), hash: 'SHA-256' }, true, ['sign','verify']);
const pem = Buffer.from(await crypto.subtle.exportKey('pkcs8', key.privateKey)).toString('base64');
const secret = 'test-only-dispatch-secret-with-32-characters';
const env = { PUSH_DISPATCH_SECRET: secret, SUPABASE_URL: 'https://db.example.invalid',
  FCM_PROJECT_ID: 'test-smartpark',
  SUPABASE_SERVICE_ROLE_KEY: 'server-test-secret', FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
    project_id: 'test-smartpark', client_email: 'test@example.invalid',
    private_key: `-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----`,
  }) };
const job = { id: 'job', lease_id: 'lease', notification_id: 'notice', user_id: 'customer',
  title: 'Sắp đến giờ lấy xe', body: 'Lấy xe trước 14:00', token: 'private-device-token',
  booking_id: 'ticket', category: 'pickup_soon', ends_at: new Date(Date.now()+600000).toISOString() };
const incoming = (value=secret) => new Request('https://edge.example.invalid',
  { method:'POST', headers: { 'x-smartpark-dispatch-secret': value } });
function transport({ status=200, code, network=false, ackFailure=false, authFailure=false }={}) {
  const sent=[], acks=[];
  return { sent, acks, fetch: async(url, options) => {
    if(url.includes('oauth2')) {
      if(authFailure) return Response.json({}, { status: 503 });
      // Verify the actual RS256 assertion, not just its shape.
      const jwt = new URLSearchParams(options.body).get('assertion');
      const [head,body,signature]=jwt.split('.');
      assert.ok(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key.publicKey,
        Buffer.from(signature,'base64url'), new TextEncoder().encode(`${head}.${body}`)));
      return Response.json({access_token:'short-lived-test-token',expires_in:3600});
    }
    if(url.includes('claim_push_jobs')) return Response.json([job]);
    if(url.includes('finish_push_job')) {
      acks.push(JSON.parse(options.body));
      return ackFailure ? Response.json({}, {status:503}) : new Response(null,{status:204});
    }
    assert.ok(url.startsWith('https://fcm.googleapis.com/v1/projects/test-smartpark/'));
    sent.push(JSON.parse(options.body));
    if(network) throw new TypeError('Connection reset');
    return Response.json(status===200 ? {name:'fcm-receipt'} : {error:{details:[{errorCode:code}]}},{status});
  } };
}
test('missing/wrong cron secret cannot claim or send',async()=>{
  let calls=0;
  const handle=createPushHandler(env,async()=>{calls++;throw Error('Unexpected network')});
  assert.equal((await handle(incoming('public-publishable-key'))).status,401);
  assert.equal((await handle(incoming(''))).status,401);
  assert.equal(calls,0);
});
test('missing Firebase configuration leaves jobs unclaimed',async()=>{
  const handle=createPushHandler({...env,FCM_SERVICE_ACCOUNT_JSON:undefined},()=>{throw Error('Unexpected network')});
  assert.equal((await handle(incoming())).status,503);
});
test('wrong Firebase project cannot authenticate or claim jobs',async()=>{
  let calls=0;
  const handle=createPushHandler({...env,FCM_PROJECT_ID:'smartpark-606ea'},async()=>{calls++;throw Error('Unexpected network')});
  assert.equal((await handle(incoming())).status,503);
  assert.equal(calls,0);
});
test('Google auth outage does not lease jobs',async()=>{
  const fake=transport({authFailure:true});
  assert.equal((await createPushHandler(env,fake.fetch)(incoming())).status,503);
  assert.equal(fake.sent.length,0);
});
test('sends background notification payload, recipient guard and stable tag',async()=>{
  const fake=transport();
  const response=await createPushHandler(env,fake.fetch)(incoming());
  assert.equal(response.status,200);
  assert.equal(fake.sent[0].message.android.notification.tag,'notice');
  assert.equal(fake.sent[0].message.data.user_id,'customer');
  assert.equal(fake.acks[0].p_lease_id,'lease');
  assert.equal(fake.acks[0].p_result,'sent');
  const body=await response.text();
  assert.equal(body.includes('private-device-token'),false);
  assert.equal(body.includes('server-test-secret'),false);
});
for(const scenario of [
  {name:'rate limit',status:429,result:'retry'},
  {name:'FCM outage',status:503,result:'retry'},
  {name:'network failure',network:true,result:'retry'},
  {name:'invalid device',status:404,code:'UNREGISTERED',result:'invalid_token'},
  {name:'malformed payload does not disable device',status:400,code:'INVALID_ARGUMENT',result:'permanent'},
]) test(scenario.name,async()=>{
  const fake=transport(scenario);
  await createPushHandler(env,fake.fetch)(incoming());
  assert.equal(fake.acks[0].p_result,scenario.result);
});
test('lost DB acknowledgement is recoverable by lease expiry',async()=>{
  const fake=transport({ackFailure:true});
  const result=await createPushHandler(env,fake.fetch)(incoming());
  assert.equal((await result.json()).ackPending,1);
});
