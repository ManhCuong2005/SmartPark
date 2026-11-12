# Hạn vé và thông báo SmartPark

Supabase vẫn là backend, Auth và cơ sở dữ liệu chính. Firebase chỉ vận chuyển
thông báo Android (FCM), không cần Firestore hoặc Realtime Database của Firebase.
Chủ dự án đã cung cấp Firebase project ID `smartpark-606ea`.
Đã đăng ký Customer/Staff bằng Firebase CLI và tải cấu hình client đúng flavor.
Ngày 30/10/2026: khóa gửi đã được cấu hình trong Supabase Edge secrets, hàm
`push-dispatch` đã triển khai và hai lịch hạn vé/gửi push đang hoạt động mỗi phút.
Đã kiểm tra HTTP 200 từ pg_net tới worker; chưa thử nhận trên điện thoại thật.
Không có service account/service-role key trong app.

## Hành vi

- `confirmed`, chưa check-in, giờ máy chủ >= `ends_at`: chuyển `expired` (Hết hạn ·
  Chưa sử dụng) vào lịch sử đã kết thúc, không thu phí, không tạo payment hay
  check-out giả. Chủ bãi thấy “Hết hạn” và chỗ được giải phóng.
- `parked`: giữ đang gửi cho đến khi nhân viên check-out thật; phí tiếp tục tính
  theo giờ thực tế, không tự chuyển hoàn thành khi quá giờ dự kiến.
- Đang gửi và còn <=30 phút trước giờ lấy xe: một thông báo `pickup_soon`.
  Nếu mới check-in khi còn dưới 30 phút, nhắc trong lượt chạy kế tiếp.
- Quá giờ nhưng vẫn `parked`: một thông báo `pickup_overdue`, không nhắc lặp mỗi
  phút. Inbox lưu lại; push bị bỏ nếu vé đã check-out trước lúc worker lấy job.
- Cron chạy mỗi phút, nên đây là nhắc xấp xỉ mốc giờ. FCM/Internet/OS có thể làm
  chậm việc hiển thị. Khi chưa cài cron, tải lại app vẫn xử lý theo tài khoản.
- Server không biết thao tác check-in chưa được gửi từ một điện thoại offline.
  Nếu vé đã hết hạn trước khi thao tác đó được đồng bộ, giữ sự kiện check-in/out
  để chủ bãi kiểm tra; không tự hồi sinh vé hoặc ghi đè chỗ có thể đã được người
  khác đặt. Không xóa sự kiện vật lý đó.

## 1. Bật phần Supabase trước (không cần Firebase)

Ngày 29/10/2026, chủ dự án đã xác nhận chạy cả hai file dưới đây trên Cloud.
Không chạy lại migration 004. Ngày 30/10/2026 đã kiểm tra trực tiếp các lượt chạy
Cron thành công, không còn vé confirmed quá hạn chưa xử lý. Lịch gửi push cũng
đã bật. Không cần chạy lại các bước thiết lập trên project hiện tại.

Trong SQL Editor, sau 001/002/003, chạy theo thứ tự:

1. `supabase/migrations/202610290004_deadlines_and_push.sql` (một lần).
2. `supabase/setup-reminder-scheduler.sql` (có thể chạy lại theo tên job).

Không chạy `supabase/tests` trên Cloud. Scheduler bật Cron, tự xử lý hạn vé và
tạo thông báo trong app kể cả khi tất cả điện thoại đóng app.

## 2. Tạo Firebase khi sẵn sàng

Phần này đã được thực hiện cho `smartpark-606ea`: không tạo lại apps hoặc tải lại
file. `node tools/check_firebase_config.mjs --required` đã kiểm tra thành công cả
hai file thật. Hướng dẫn dưới đây dành cho thiết lập lại trên máy/CI khác.

1. Mở [Firebase project SmartPark](https://console.firebase.google.com/project/smartpark-606ea/settings/general).
   Project đã được tạo với ID `smartpark-606ea`; không cần tạo lại.
2. Thêm **hai Android apps** vào cùng project, đúng package ID:
   - Customer: `vn.smartpark.smartpark.customer`
   - Staff: `vn.smartpark.smartpark.staff`
3. Tải `google-services.json` tương ứng **từng app**, lưu lần lượt:
   - `android/app/src/customer/google-services.json`
   - `android/app/src/staff/google-services.json`
4. Trong Project settings → Cloud Messaging, kiểm tra Firebase Cloud Messaging
   API (V1) đã được bật. Không dùng “legacy server key”.

Hai file cấu hình client được gitignore, không phải khóa quản trị. Không đặt file
service account vào đây. Khi chưa có cấu hình Firebase, app vẫn chạy với inbox
Supabase. Khi thêm cấu hình cần chạy lại app; APK cũ không tự có cấu hình mới.
Chỉ build APK khi chủ dự án yêu cầu; giữ version theo quyết định của chủ dự án.

Sau khi đặt file, có thể kiểm tra cấu hình mà không build APK:

```powershell
node tools/check_firebase_config.mjs --required
```

Lệnh kiểm tra đúng package hai flavor, cùng project/sender và không dùng nhầm
service account. App và worker mặc định dùng project `smartpark-606ea`; file client
hoặc service account thuộc project khác bị từ chối trước khi đăng ký/gửi.
Không in API key. File hợp lệ chưa chứng minh FCM giao được tin.

## 3. Cấu hình bộ gửi phía Supabase (thực hiện sau)

**Đã thực hiện trên project hiện tại.** Supabase CLI đã đăng nhập; khóa Firebase
nằm trong Edge secrets, secret xác thực cron sinh trên server và lưu trong Vault.
Function ở trạng thái ACTIVE, yêu cầu không có secret trả 401; yêu cầu hợp lệ
và pg_net đều trả 200. Thời gian chờ pg_net là 120 giây để đủ cho một batch.
File env/SQL tạm chứa dữ liệu cấu hình đã được xóa. Hướng dẫn dưới đây dành cho
thiết lập lại, không cần tạo khóa mới hoặc chạy lại lúc này.

1. Firebase Project settings → Service accounts → Generate new private key.
   File này là **bí mật của backend**, không gửi qua chat, không commit/upload
   cùng APK và không dùng trong Vite/Flutter. Nếu cần cấu hình bằng công cụ cục
   bộ, lưu đúng `.smartpark/firebase/service-account.json` đã gitignore; chỉ
   thông báo đã lưu file, không gửi nội dung khóa qua chat.
2. Trong Supabase → Edge Functions → Secrets, thêm:
   - `FCM_SERVICE_ACCOUNT_JSON`: toàn bộ nội dung JSON của service account.
   - `PUSH_DISPATCH_SECRET`: chuỗi ngẫu nhiên tối thiểu 32 ký tự; nên dùng
     trình quản lý mật khẩu sinh chuỗi 64 ký tự.
   `SUPABASE_URL` và `SUPABASE_SERVICE_ROLE_KEY` là môi trường server do Supabase
   cung cấp, không chép sang ứng dụng.
3. Máy hiện tại đã cài Supabase CLI cục bộ trong `.smartpark/supabase-cli`.
   Nếu cần đăng nhập lại, trong terminal ở thư mục dự án chạy:

   ```powershell
   .\.smartpark\supabase-cli\node_modules\.bin\supabase.cmd login
   ```

   Không gửi access token qua chat. Sau khi cấu hình Secrets, lệnh deploy thủ
   công tương ứng (hoặc tiếp tục bằng công cụ trong phiên làm việc):

   ```powershell
   .\.smartpark\supabase-cli\node_modules\.bin\supabase.cmd functions deploy push-dispatch --project-ref odpxmbkzdqutxitsdfaw
   ```

   `supabase/config.toml` đặt `verify_jwt=false` cho worker: cron xác thực bằng
   secret riêng `x-smartpark-dispatch-secret`. Handler kiểm tra secret trước mọi
   truy vấn/gửi FCM; publishable key và tài khoản khách không gọi được worker.
4. Supabase → Vault: tạo secret tên `smartpark_push_dispatch_secret`, giá trị
   **đúng bằng** `PUSH_DISPATCH_SECRET` ở bước 2. Tạo bằng dashboard để tránh ghi
   bí mật vào SQL/lịch sử Git.
5. Chạy `supabase/setup-push-scheduler.sql` trong SQL Editor, sau phần 1 để có
   extension Cron. Địa chỉ function trong file đang trỏ project SmartPark.
6. Trên Android: đăng nhập → Cá nhân → Thông báo → **Bật thông báo trên điện
   thoại**, cho phép thông báo. Token gắn với tài khoản hiện tại và cập nhật khi
   đổi. Đăng xuất ngừng đăng ký thiết bị trước khi xóa session; nếu không xác
   nhận được vì mất mạng, app yêu cầu kết nối rồi đăng xuất lại.

FCM gửi notification payload để Android hiển thị khi app nền hoặc đóng;
foreground dùng `flutter_local_notifications`. Chạm mở vé còn được cấp quyền.
Android bị Force stop trong Settings cần mở app lại; thiết bị phải có Google
Play services phù hợp và có mạng. Không dùng exact alarm hoặc chạy GPS/worker nền
liên tục. Web hiện chỉ có inbox, chưa bật Web Push hoặc iOS/APNs.
[Hướng dẫn Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[lập lịch Supabase](https://supabase.com/docs/guides/functions/schedule-functions).

## 4. Kiểm thử sau cấu hình

Đã xác minh trên Cloud: OAuth service account được Google chấp nhận, endpoint
worker chặn thiếu secret, worker có secret và tuyến pg_net → worker trả 200,
hai lịch Cron active và có lượt chạy succeeded. Hiện có **0 thiết bị đăng ký**;
worker trả `sent/retry/failed/ackPending` đều 0. Đây là kiểm tra hạ tầng, không
phải xác nhận điện thoại đã nhận FCM. Chưa build APK mới hoặc test thiết bị thật.

Với tài khoản thử, đặt giờ kết thúc gần mốc nhắc rồi cho nhân viên check-in. Khách
thử app mở, app nền và app đóng; kiểm tra inbox, thông báo Android, chạm mở đúng
vé. Check-out trước lượt gửi tiếp theo để kiểm tra job lỗi thời bị bỏ. Không đổi
đồng hồ thiết bị để giả giờ vì server là nguồn thời gian chính.

SQL kiểm tra trong Dashboard của chủ dự án:

Có thể chạy riêng `supabase/verify-reminders.sql` để lấy một báo cáo JSON chỉ
đọc: lịch hoạt động, năm lượt chạy gần nhất, số vé/thông báo và quyền bị chặn.
File này không phải migration, không trả email/biển số/QR/token/secret. Khóa public
của app không đọc được `cron.job_run_details`, nên cần Dashboard để xác minh job.

```sql
select status, count(*) from public.bookings group by status;
select category, count(*) from public.notifications
where category is not null group by category;
select state, count(*) from public.push_jobs group by state;
select jobname, schedule, active from cron.job;
select status, return_message, start_time from cron.job_run_details
order by start_time desc limit 10;
```

Worker dùng lease/`SKIP LOCKED`, retry exponential, ngừng token `UNREGISTERED`,
không trả token/secret trong HTTP response. Nếu FCM đã nhận nhưng ACK database
mất có thể gửi lại; notification ID/tag cố định gộp thẻ hiển thị. Không tuyên bố
giao đúng một lần. Job thất bại 10 lần chuyển `failed`; kiểm tra `last_error`, sửa
cấu hình rồi chỉ requeue có chọn lọc.

CI ký nhận tùy chọn hai GitHub Secrets `FIREBASE_CUSTOMER_JSON_BASE64` và
`FIREBASE_STAFF_JSON_BASE64`, base64 cấu hình client từng app. Cung cấp cả hai
hoặc để trống cả hai. Service account chỉ ở Supabase, không ở CI build.
Chưa chạy workflow CI hoặc kiểm thử FCM trên thiết bị thật trong lượt sửa này.

Lưu ý cho người vận hành: không đưa `net`/`vault` vào schema Data API hoặc cấp
SQL LOGIN cho vai trò app. pg_net có quyền mặc định PUBLIC trên hàng đợi; đã
kiểm tra `net`/`vault` không được API phơi bày (406/PGRST106), `anon` và
`authenticated` không có LOGIN, Vault không cho hai vai trò đọc secret.
[Giới hạn quyền pg_net của Supabase](https://supabase.com/kb/troubleshooting/revoking-access-to-pg_net-objects-has-no-effect).
