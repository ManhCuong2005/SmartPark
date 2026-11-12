# Kiểm thử SmartPark

## Tự động, không ghi Cloud

Lượt nâng cấp đặt chỗ ngày 12/11/2026: `flutter analyze` sạch, **148 Flutter tests**
và bộ PostgreSQL gồm migration/RPC/concurrency/demo seed đều qua cục bộ.
`test/reservation_flow_test.dart` và `supabase/tests/booking_flow.sql` bao gồm
lịch ngày sau, gia hạn nhận xe 1 tiếng sau giờ kết thúc, dời giờ/check phí, phản
hồi rung QR/OCR, tránh dữ liệu chỗ trống cũ và giao diện nhỏ/chữ lớn. Xem
[quy tắc và cách áp dụng](BOOKING_FLOW.md). Có thể xuất ảnh bằng
`flutter test test/reservation_flow_test.dart --dart-define=SMARTPARK_CAPTURE_REVIEW=true`.
Migration 005/006 đã áp dụng trong một transaction lên Cloud ngày 12/11/2026.
Đã gọi RPC khả dụng cho đúng trường hợp người dùng báo lỗi: ô ở bãi đang chọn
trống nhưng xe có vé trùng giờ tại bãi khác, trả về hai thông tin riêng. Số lượng
vé/khoản thu giữ nguyên trước và sau triển khai. Không tạo vé thử trên Cloud.
`booking_conflict_test.dart` và HTTP simulator kiểm tra preflight/race, retry mất
ACK, cảnh báo trên UI và phân biệt mã lỗi. Chưa xác minh rung/camera trên điện thoại.

Lỗi nút Tiếp tục khi mạng có độ trễ đã được tái hiện bằng test thất bại trước
khi sửa. Thêm 4 test cho cả luồng kiểm tra chỗ → xác nhận → tạo vé và lỗi mạng/
trùng ô/xe, có chờ qua nhiều frame. Xác minh không tạo vé khi chỉ chuyển bước,
chỉ gửi một lệnh ở xác nhận cuối và thử lại thành công sau lỗi mạng. Lượt sửa
nút chỉ thay giao diện, không thay migration hoặc ghi dữ liệu Cloud.

```powershell
flutter analyze
flutter test --reporter expanded
node --test tools/push_dispatcher.test.mjs
node --test tools/firebase_config.test.mjs
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin --demo-seed
cd admin-web
npm.cmd run build
npm.cmd test
```

Flutter tests gồm quy tắc giá/giờ/biển số/QR, hàng đợi offline, kiểm tra không cấp
vé khi đặt offline, đăng ký chờ email, route guard và UI ở 320/390/480px, cập nhật
Riverpod/đăng xuất và dark mode. Drift được kiểm tra thật với SQLite, đóng/mở lại
file, tách dữ liệu theo tài khoản, giữ lỗi/retry. SDK Supabase chạy qua HTTP server
mô phỏng hợp đồng để kiểm tra lỗi mạng, retry cùng ID, phản hồi xung đột và thứ tự.
Simulator không chứng minh RLS hoặc dữ liệu Cloud.

`test/auto_sync_test.dart` kiểm tra polling khi Internet trở lại trên cùng Wi-Fi,
resume/paused và tín hiệu reconnect trong lúc đang tải dữ liệu. Test HTTP/SQLite
trong `data_integration_test.dart` kiểm tra tự gửi bằng sự kiện mạng, gửi các lệnh
đã lưu khi mở app, bỏ thời gian chờ retry khi phục hồi, không đổi dữ liệu tài khoản
khác, không tự thử lại xung đột và không ghi trùng khi nhiều lần sync chồng nhau.
Các bài này không chứng minh OS/background delivery trên điện thoại thật; dữ liệu
Cloud không bị thay đổi. Khi app bị đóng hẳn, hàng đợi tiếp tục ở lần mở sau.

`test/map_test.dart` kiểm tra bản đồ bằng ảnh/GPS kiểm soát: lỗi và thử lại,
timeout, dữ liệu tọa độ đến sau lần dựng đầu, chọn marker không tạo lại nền,
GPS bị từ chối, GPS một lần và 3 kích thước màn hình. Không gửi request hàng loạt
đến dịch vụ tile trong bộ test. Xem cấu hình và giới hạn tại [MAPS.md](MAPS.md).

`test/booking_history_test.dart` gồm 13 test cho phạm vi tài khoản, ưu tiên vé
đang gửi xe, giá dự kiến/tạm tính so với khoản thu, ngày qua đêm, ẩn thanh kết nối
khi bình thường, cảnh báo/thử lại khi lỗi, tìm kiếm/lọc và mở QR. Kiểm tra 1.000 vé
để bảo đảm danh sách chỉ dựng các thẻ gần khung nhìn, giao diện sáng/tối và chữ lớn
ở 320/390/480px. Thêm `--dart-define=SMARTPARK_CAPTURE_REVIEW=true` khi chạy test
để xuất ảnh kiểm tra vào `.smartpark/ui-review`; ảnh dùng fixture, không ghi Cloud.

Backend tests chạy migration SQL thật trong PostgreSQL tạm trên localhost, dừng
server sau test. Kiểm tra role không tự nâng quyền, RLS, quyền theo bãi, overlap,
version, đối chiếu biển số, idempotency check-in/out, một khoản thu mỗi vé và hai
phiên DB tranh cùng vị trí. Fixture auth/storage mô phỏng schema Supabase-owned;
Auth service và Realtime network thật không được chứng minh bằng test SQL.

Migration 003 có kiểm thử chủ bãi cấp customer thành staff, từ chối tài khoản chưa
xác nhận email, giữ quyền nhân viên ở bãi khác khi thu hồi một bãi, trả về customer
khi hết phân công và không hạ quyền owner. `--demo-seed` kiểm tra số lượng dữ liệu,
phí, RLS, QR check-in/out và không ghi đè dữ liệu khi chạy seed lại.

Playwright chạy SDK và giao diện Admin với HTTP responses trong test, kiểm tra
đăng nhập/phân quyền UI, dữ liệu doanh thu, RPC/version, lỗi xung đột và 6 màn hình
ở 390/768/1440px. Ảnh review sáng/tối trong `admin-web/test-results/` là ảnh từ test
fixtures, không phải ảnh dữ liệu vận hành Cloud. Cổng ngoài Cloud bị intercept.

## Cần kiểm tra trên thiết bị thật

Lượt sửa hạn vé/thông báo: `flutter analyze` sạch, **123 Flutter tests**, **38
Playwright tests** và **11 push-worker tests** qua. `business_rejection_test.dart`
kiểm tra thông báo rõ và giữ form khi sửa xe bị từ chối; `data_integration_test`
kiểm tra lỗi chỉnh sửa offline trở thành notice bền vững, tách tài khoản, không
retry/block hàng đợi. `device_notifications_test` kiểm tra opt-in, refresh inbox,
mở đúng vé và logout bằng service contract kiểm soát.

Kiểm thử mới bao gồm tải lại cache sau hết hạn/check-out/hủy, chặn lưu xe lặp,
khóa form trong lúc gửi và tránh gửi với tài khoản khác khi session đổi.
`supabase/tests/reminder_flow.sql` chạy chuỗi RPC đặt vé → check-in → nhắc → đọc
→ check-out và kiểm tra push lỗi thời bị hủy. **8 tests cấu hình Firebase**
kiểm tra hai package/cùng project, app ID/sender và đặt nhầm service account.
Đây là kiểm tra file client, chưa xác minh gửi/nhận FCM thật.

Firebase project `smartpark-606ea`: đã đăng ký hai Android apps qua Firebase CLI,
tải và kiểm tra file client đúng package/app ID/project. App và worker từ chối
project không khớp; test worker chứng minh không claim job khi cấu hình sai
project. Các file thật được gitignore. Ngày 30/10/2026 đã deploy Edge Function,
cấu hình secrets/Vault và lịch gửi; chưa build APK hoặc thử nhận trên điện thoại.

`supabase/tests/deadlines_and_push.sql` kiểm tra expiry không tạo phí/check-out,
parked không tự kết thúc, dedupe, scope fallback, worker RPC không cấp cho khách,
retry, lease ACK, token đổi tài khoản và bỏ nhắc khi xe đã ra. Worker được test
với OAuth RS256 thật và transport giả cho 429/503/network/UNREGISTERED/lost ACK;
không gửi push thật. Bộ test PostgreSQL và seed idempotency đều qua cục bộ.
Cron/pg_net/Vault và Edge runtime đã được kiểm chứng trên Cloud: lịch succeeded,
endpoint chặn thiếu secret bằng 401, gọi hợp lệ và pg_net trả 200. Worker không
có job/thiết bị, các bộ đếm đều 0; chưa chứng minh điện thoại nhận push. Xem
[NOTIFICATIONS.md](NOTIFICATIONS.md). Không build APK; giữ 1.0.1+2.

1. Migrations 001/002/004 và `setup-reminder-scheduler.sql` đã được bạn xác nhận
   chạy trên Cloud (004/lịch hạn vé ngày 29/10/2026). Không chạy lại migration;
   chạy 003 nếu chưa có. Kiểm tra Cron có lượt chạy thành công và luồng nhắc thật.
   Đăng ký/xác nhận ba tài khoản
   và cấp quyền theo SUPABASE_SETUP.md.
2. Hai điện thoại cùng chọn một vị trí/giờ: chỉ một máy nhận vé, máy kia báo hết chỗ.
3. Khách đặt vé; nhân viên quét QR bằng camera; khách thấy trạng thái cập nhật khi
   nhân viên check-in/out, Admin thấy khoản thu tương ứng.
4. OCR ít nhất một bộ ảnh biển số ô tô/xe máy: sáng, tối, nghiêng, mờ, hai dòng.
   Ghi nhận tỉ lệ đúng; không suy ra độ chính xác từ test regex. Kiểm tra từ chối
   quyền camera, hủy chụp, sửa kết quả, biển số không khớp.
5. Tải dữ liệu nhân viên trước, bật chế độ máy bay, ghi check-in rồi check-out.
   Khởi động lại app: lệnh vẫn ở hàng đợi. Nối mạng: gửi một lần về mặt nghiệp vụ,
   chỉ một khoản thu. Không mất lệnh khi app bị đóng giữa chừng.
6. Gây xung đột bằng thiết bị thứ hai hoặc thu hồi membership: lệnh giữ trạng thái
   cần kiểm tra. Kiểm tra retry/bỏ lệnh và đăng xuất khi còn lệnh chờ.
7. GPS được/từ chối quyền, Web không có ML Kit, map mất mạng, màn hình nhỏ, tăng
   cỡ chữ và dark mode. Số chỗ khi offline phải hiện là dữ liệu đã lưu.
8. Profile mode trên điện thoại mục tiêu, xem DevTools Frame chart trong các luồng
   cuộn/quét/chụp; ghi jank/frame times. Chưa có số đo 60fps trong phiên này.

Integration test Cloud có ghi vé/khoản thu chỉ chạy khi tự chọn với file cấu hình
riêng và `SMARTPARK_TEST_ALLOW_WRITES=true`; xem SUPABASE_SETUP.md. Không đưa
tài khoản kiểm thử vào CI công khai hoặc commit mật khẩu.
