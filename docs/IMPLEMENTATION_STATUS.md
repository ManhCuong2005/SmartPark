# SmartPark implementation audit

Baseline reviewed: Flutter entrypoints, routes, theme, shared widgets, all feature
screens, tests, Android/iOS configuration, React admin state, pages and build scripts.

The original application was a UI prototype: Flutter state was in memory, admin
state was browser-local, authentication only validated input, QR was artwork, and
occupancy/revenue were illustrative. There was no API, offline database or release
signing pipeline. Existing visual assets and layout components are retained.

Implementation and verification results are recorded at the end of this file as
work progresses. Cloud migrations must be applied by the project owner; a client
publishable key does not grant schema administration. No production deployment or
GitHub Release is authorized in this stage.

## Trạng thái ngày 29/10/2026

| Tiêu chí | Đã triển khai | Phạm vi kiểm chứng |
|---|---|---|
| Clean Architecture | Domain thuần Dart, Data adapters, Presentation và composition root; Riverpod quản lý controller/theme | Analyzer không có lỗi/cảnh báo; test route phản ứng với cập nhật dữ liệu |
| AI thực tế | Camera → ML Kit Latin OCR bundled → trích xuất ứng viên → nhân viên sửa/đối chiếu biển số | Hai APK debug build được; regex đã test; chưa kiểm tra độ chính xác OCR trên ảnh/thiết bị thật |
| Offline-First | Drift/SQLite cache theo tài khoản, outbox bền vững, retry có delay, idempotency, version và màn hình xung đột | Test SQLite đóng/mở lại, SDK qua HTTP lỗi mạng và SQL transaction/constraint |
| UI/UX | Material 3, giữ assets/palette/shell, responsive, dark mode, form và trạng thái thật | Widget 320/390/480px; Admin 390/768/1440px; ảnh review sáng/tối. Chưa đo 60fps trên điện thoại |
| CI/CD | GitHub Actions kiểm tra/build; Fastlane và workflow ký APK/AAB thủ công, không publish | Hai flavor debug build cục bộ. Workflow GitHub/Fastlane và chữ ký release chưa chạy vì chưa có Ruby/keystore/secrets |

### Chức năng đã nối dữ liệu thật

- Customer: Supabase Auth đăng ký/đăng nhập, gửi email khôi phục, hồ sơ, phương tiện,
  tìm/lọc bãi, tọa độ/bản đồ, giá/chỗ trống, đặt/hủy, QR có dữ liệu thật, lịch sử,
  thông báo và bookmark bãi. Không có fallback mock trong ứng dụng.
- Staff: QR camera/nhập tay, OCR camera on-device có sửa kết quả, đối chiếu biển số,
  check-in/out, phí tiền mặt do server tính, sơ đồ/vị trí và danh sách xe đang gửi,
  lưu check-in rồi check-out khi offline, hàng đợi/xung đột.
- Owner/Admin: Auth/role guard, chỉ quản lý bãi của mình, CRUD cấu hình bãi và tăng
  vị trí/tạm ngưng ô trống, phân công/thu hồi nhân viên đã đăng ký, bảng giá version,
  xem/hủy vé được phép, xem phương tiện từng dùng bãi, doanh thu/biểu đồ/CSV từ khoản thu.
  Chủ bãi không sửa trực tiếp phương tiện cá nhân của khách hoặc nhập tay số xe.
- Server: 11 bảng RLS, transaction/RPC cho ghi dữ liệu, exclusion slot/time và
  vehicle/time, một xe/vị trí đang sử dụng, một payment/vé, audit events, kiểm tra
  QR/biển số/role/version, timestamp observation + receive time, private Storage bucket.
- Realtime + reload khi reconnect/định kỳ; trigger tăng revision vị trí để khách
  nhận tín hiệu chỗ trống mà không cần đọc vé riêng tư của khách khác.

### Kết quả thực tế

- `flutter analyze` và `dart analyze`: không có issues trong các lượt kiểm tra.
- `flutter test`: **65 tests passed** trong lượt cuối sau sửa route/Riverpod.
- PostgreSQL cục bộ: migrations **001 và 002**, assertions nghiệp vụ/RLS và hai
  phiên tranh một vị trí đều qua. Server kiểm thử đã dừng sau mỗi lượt.
- Admin: TypeScript + Vite build thành công; **33 Playwright tests passed**.
  Các route được chia bundle tải theo màn hình. Đã xem ảnh review sáng/tối.
- Android: Customer và Staff debug APK build được; application ID khác nhau.
  `build/app/outputs/flutter-apk/app-customer-debug.apk`, `app-staff-debug.apk`.
  Lỗi đầy C trong lần đầu đã tránh bằng cache/temp Gradle trên D; tắt Kotlin
  incremental khắc phục lỗi cache khác ổ C/D. Không xóa cache dự án khác.
- Flutter Web: cả Customer (`build/customer_web`) và Staff (`build/staff_web`)
  build release thành công với SQLite WASM/worker và fonts tương ứng.
- Cloud: Auth settings trả 200; truy cập bảng không đăng nhập trả 401/42501 như
  thiết kế. Bạn đã xác nhận chạy thành công cả 001 và 002. Agent không ghi schema
  hay tạo tài khoản thử nghiệm trên Cloud.

### Chưa kiểm thử / giới hạn cần giữ rõ

- Chưa có điện thoại kết nối (`adb devices` trống), chưa chạy end-to-end 3 tài
  khoản trên Cloud, camera/QR/OCR/GPS thật, offline restart trên máy hoặc Realtime
  giữa hai điện thoại. Có integration test opt-in và checklist trong TESTING.md.
- Chưa đo độ chính xác OCR, frame times/60fps hay tải đồng thời lớn. Snapshot hiện
  phù hợp quy mô nhỏ; phân trang lịch sử phía server là hướng tối ưu khi dữ liệu tăng.
- iOS đã bổ sung quyền và deployment target 15.5; chưa build trên macOS/Xcode.
- Không có thanh toán online, điều khiển barrier vật lý hoặc offline basemap; giai
  đoạn này dùng thu tiền mặt và bản đồ nền online. Thông báo là in-app, chưa có push.
- Chưa thực thi ký Release APK/AAB hay workflow GitHub; chưa phát hành/upload GitHub
  Releases, chưa triển khai hosting hoặc production. Không có secret/service_role key.

### Bước chạy thử tiếp theo

Migrations đã xong. Đăng ký/xác nhận tài khoản của bạn trong app khách, thay email
trong `supabase/bootstrap-owner.sql` rồi chạy script cấp owner trong SQL Editor.
Đăng nhập Admin để tạo bãi/vị trí/giá. Tạo tài khoản nhân viên riêng và phân công
qua Admin. Chi tiết ở SUPABASE_SETUP.md và TESTING.md; không cần gửi mật khẩu.
