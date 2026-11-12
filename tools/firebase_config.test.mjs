import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateFirebaseClient, validateFirebasePair } from './check_firebase_config.mjs';

const client = (role, project='smartpark-test', number='123456789') => ({
  project_info: { project_id: project, project_number: number },
  client: [{ client_info: { mobilesdk_app_id: `1:${number}:android:abcdef`,
    android_client_info: { package_name: `vn.smartpark.smartpark.${role}` } },
    api_key: [{ current_key: 'public-client-fixture' }] }],
});
test('accepts the two matching Android flavors', () => {
  assert.equal(validateFirebasePair(client('customer'),client('staff')).projectId,'smartpark-test');
});
test('rejects a root-package file mistakenly used for customer flavor', () => {
  assert.throws(()=>validateFirebaseClient(client('root'),'vn.smartpark.smartpark.customer'),/không có Android app/);
});
test('rejects service-account credentials in a client file', () => {
  assert.throws(()=>validateFirebaseClient({type:'service_account',private_key:'never-log-this'},'customer'),/bí mật backend/);
});
test('rejects customer and staff belonging to different projects', () => {
  assert.throws(()=>validateFirebasePair(client('customer'),client('staff','another-project')),/cùng Firebase project/);
});
test('rejects an app ID with a mismatched messaging sender', () => {
  const config=client('customer'); config.client[0].client_info.mobilesdk_app_id='1:999:android:abcdef';
  assert.throws(()=>validateFirebaseClient(config,'vn.smartpark.smartpark.customer'),/không khớp sender/);
});
test('accepts a shared root file containing both Android clients', () => {
  const config=client('customer'); config.client.push(...client('staff').client);
  assert.equal(validateFirebasePair(config,config).projectId,'smartpark-test');
});
test('accepts configuration for the selected SmartPark project', () => {
  assert.equal(validateFirebasePair(client('customer','smartpark-606ea'),client('staff','smartpark-606ea'),
    'smartpark-606ea').projectId,'smartpark-606ea');
});
test('rejects a matching pair from a different Firebase project', () => {
  assert.throws(()=>validateFirebasePair(client('customer'),client('staff'),'smartpark-606ea'),/smartpark-606ea/);
});
