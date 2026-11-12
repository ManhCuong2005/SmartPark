// Client configuration only. Never prints an API key or reads a service account.
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

export function validateFirebaseClient(config, expectedPackage) {
  if (config?.type === 'service_account' || config?.private_key) {
    throw new Error('Sai loại file: service account là bí mật backend, không được đưa vào ứng dụng.');
  }
  const info = config?.project_info;
  if (typeof info?.project_id !== 'string' || !info.project_id.trim() ||
      typeof info.project_number !== 'string' || !/^\d+$/.test(info.project_number)) {
    throw new Error('Thiếu Firebase project_id hoặc project_number hợp lệ.');
  }
  const client = config.client?.find(item => item.client_info?.android_client_info?.package_name === expectedPackage);
  if (!client) throw new Error(`File Firebase không có Android app ${expectedPackage}.`);
  const appId = client.client_info?.mobilesdk_app_id;
  if (typeof appId !== 'string' || !appId.startsWith(`1:${info.project_number}:android:`)) {
    throw new Error(`Firebase app ID không khớp sender/project của ${expectedPackage}.`);
  }
  if (!client.api_key?.some(item => typeof item.current_key === 'string' && item.current_key.trim())) {
    throw new Error(`Thiếu cấu hình API key client cho ${expectedPackage}.`);
  }
  return { projectId: info.project_id, senderId: info.project_number };
}

export function validateFirebasePair(customer, staff, expectedProjectId) {
  const a = validateFirebaseClient(customer, 'vn.smartpark.smartpark.customer');
  const b = validateFirebaseClient(staff, 'vn.smartpark.smartpark.staff');
  if (a.projectId !== b.projectId || a.senderId !== b.senderId) {
    throw new Error('Customer và Staff cần cấu hình cùng Firebase project.');
  }
  if (expectedProjectId && a.projectId !== expectedProjectId) {
    throw new Error(`File client không thuộc Firebase project ${expectedProjectId} đã cấu hình cho SmartPark.`);
  }
  return a;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const root = fileURLToPath(new URL('..', import.meta.url));
    const common = resolve(root, 'android/app/google-services.json');
    const paths = ['customer', 'staff'].map(flavor => {
      const specific = resolve(root, `android/app/src/${flavor}/google-services.json`);
      return existsSync(specific) ? specific : common;
    });
    const present = paths.map(path => existsSync(path));
    if (!present.some(Boolean) && !process.argv.includes('--required')) {
      console.log('CHỜ CẤU HÌNH: chưa có Firebase client; inbox Supabase vẫn sử dụng được.');
    } else {
      if (!present.every(Boolean)) throw new Error('Cần cấu hình Firebase cho cả Customer và Staff trước khi build hai flavor.');
      const [customer, staff] = paths.map(path => JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, '')));
      const source = readFileSync(resolve(root, 'lib/core/config/notifications_config.dart'), 'utf8');
      const expectedProjectId = source.match(/defaultValue:\s*'([^']+)'/)?.[1];
      if (!expectedProjectId) throw new Error('Thiếu Firebase project ID trong cấu hình SmartPark.');
      const result = validateFirebasePair(customer, staff, expectedProjectId);
      console.log(`OK: cấu hình Customer/Staff hợp lệ, Firebase project ${result.projectId}.`);
      console.log('Đây là kiểm tra file client, chưa xác nhận gửi/nhận FCM trên thiết bị.');
    }
  } catch (error) {
    // JSON syntax errors may echo credential fragments. Return a safe message.
    console.error(error instanceof SyntaxError ? 'JSON cấu hình không hợp lệ. Tải lại file client từ Firebase Console.' : error.message);
    process.exitCode = 1;
  }
}
