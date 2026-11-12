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
| CI/CD | GitHub Actions kiểm tra/build; Fastlane và workflow ký APK/AAB thủ công, không publish | Hai flavor APK release build/ký và kiểm chữ ký cục bộ; workflow ký GitHub/Fastlane/AAB chưa được xác minh |

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
- Server: 13 bảng RLS, transaction/RPC cho ghi dữ liệu, exclusion slot/time và
  vehicle/time, một xe/vị trí đang sử dụng, một payment/vé, audit events, kiểm tra
  QR/biển số/role/version, timestamp observation + receive time, private Storage bucket.
- Realtime + reload khi reconnect/định kỳ; trigger tăng revision vị trí để khách
  nhận tín hiệu chỗ trống mà không cần đọc vé riêng tư của khách khác.

### Kết quả thực tế

- `flutter analyze` và `dart analyze`: không có issues trong các lượt kiểm tra.
- `flutter test`: **123 tests passed**, gồm bản đồ, lịch sử, tự đồng bộ, lỗi nghiệp
  vụ không thành hàng đợi, thông báo và SQLite/HTTP.
- PostgreSQL cục bộ: migrations **001, 002, 003 và 004**, assertions nghiệp vụ/RLS và hai
  phiên tranh một vị trí đều qua. Server kiểm thử đã dừng sau mỗi lượt.
- Admin: TypeScript + Vite build thành công; **38 Playwright tests passed**.
  Các route được chia bundle tải theo màn hình. Đã xem ảnh review sáng/tối.
- Android: Customer và Staff debug APK build được; application ID khác nhau.
  `build/app/outputs/flutter-apk/app-customer-debug.apk`, `app-staff-debug.apk`.
  Lỗi đầy C trong lần đầu đã tránh bằng cache/temp Gradle trên D; tắt Kotlin
  incremental khắc phục lỗi cache khác ổ C/D. Không xóa cache dự án khác.
- Android 1.0.1+2: Customer và Staff release APK build thành công, apksigner xác
  minh v1/v2; aapt xác nhận versionName 1.0.1, versionCode 2 ở cả hai package.
- Flutter Web: cả Customer (`build/customer_web`) và Staff (`build/staff_web`)
  build release thành công với SQLite WASM/worker và fonts tương ứng.
- Bản đồ Customer Web release 1.0.1: Chrome tải đủ 9/9 tile PNG 200 trong khung
  nhìn Đà Nẵng, không có page error; đã xem ảnh bản đồ hoàn chỉnh. Nguồn mặc định
  đổi sang OSM France/HOT, có attribution, cache và điều khiển tải lại; xem MAPS.md.
- Lịch sử đặt chỗ được chỉnh theo frame Figma `16:390` và SVG đã lưu: thẻ vé
  đang dùng, hai lượt gần đây, lịch sử có tìm kiếm/lọc đã hủy và nhóm theo tháng.
  Danh sách dựng lười, kiểm tra với 1.000 vé. Giá dự kiến/tạm tính tách khỏi khoản
  thu đã xác nhận. Thanh trạng thái kết nối kỹ thuật được ẩn khi hoạt động bình
  thường; lỗi đồng bộ chỉ hiện thông báo ngắn và nút thử lại. Đã xem ảnh sáng/tối,
  kiểm tra rộng 320/390/480px và cỡ chữ lớn. Lượt sửa UI này không build APK.
- Đồng bộ tự động: startup/auth, mạng trở lại, resume và polling foreground;
  kiểm tra lại transport khi resume, bỏ retry delay cho pending đúng tài khoản,
  không tự phát lại conflict, không bỏ mất tín hiệu reconnect khi đang refresh.
  Đã kiểm tra gửi một lần với SQLite + Supabase SDK qua HTTP mô phỏng. Menu Cá
  nhân là Trạng thái đồng bộ, bỏ nút Đồng bộ ngay thông thường; đóng hẳn app giữ
  hàng đợi và tiếp tục ở lần mở sau. Chưa kiểm tra OS delivery trên điện thoại thật.
- Lỗi nghiệp vụ online được báo ngay và giữ form, không thành hàng đợi. Sửa
  biển số/loại xe/xóa xe bị chặn khi có vé hoạt động. Lỗi chỉnh sửa xe offline
  bị server từ chối chuyển thành thông báo bền vững, không tiếp tục retry; sự
  kiện check-in/out vật lý có xung đột vẫn giữ để kiểm tra.
- Hạn vé: confirmed chưa check-in qua ends_at thành expired, hiển thị trong
  lịch sử với 0 phí, không tạo doanh thu. Parked không tự hết hạn; server tạo
  nhắc trong 30 phút trước giờ lấy xe và khi quá giờ, có khóa/dedupe.
- Push Android đã có Domain contract, Firebase adapter, opt-in/permission,
  token RPC, foreground notification, mở vé khi chạm và ngừng token khi logout.
  Edge Function OAuth FCM v1 + job lease/retry: **11 tests passed** bằng HTTP
  kiểm soát; TypeScript strict kiểm tra qua. SQL kiểm tra quyền, scope, dedupe,
  retry và loại nhắc lỗi thời. Firebase project `smartpark-606ea` đã được cung
  cấp, hai Android apps đã đăng ký bằng CLI và file client tải đúng flavor.
  App/worker kiểm tra đúng project. Ngày 30/10/2026 đã deploy riêng hàm backend
  `push-dispatch`, cấu hình Edge secrets/Vault và bật lịch gửi; chưa xác minh
  nhận push trên Android thật. Xem NOTIFICATIONS.md.
- Cloud: Auth settings trả 200; truy cập bảng không đăng nhập trả 401/42501 như
  thiết kế. Bạn đã xác nhận chạy thành công 001, 002 và ngày 29/10/2026 xác nhận
  chạy thêm 004 cùng `setup-reminder-scheduler.sql`. Sau khi được cung cấp đăng
  nhập CLI và khóa Firebase, agent đã kiểm tra trực tiếp Cron thành công và áp
  dụng `setup-push-scheduler.sql`; không tạo tài khoản/vé thử trên Cloud.
- Kiểm tra Cloud sau xác nhận 004: ba RPC `refresh_booking_deadlines`,
  `register_push_device`, `claim_push_jobs` tồn tại và từ chối truy cập không
  đăng nhập (HTTP 401 / PostgreSQL 42501). Không tạo tài khoản hoặc dữ liệu thử
  trên Cloud. Lượt kiểm tra sau bằng CLI đã xác minh Cron và worker như dưới đây.
- Hoàn thiện tiếp luồng xe: tải lại vé trước khi áp dụng hạn chế từ cache khi
  online, chặn lưu lặp cùng xe, khóa form khi chờ phản hồi, kiểm tra QR khớp vé
  và giải thích vé hết hạn trước khi lưu offline. Không gửi thao tác nếu tài
  khoản đã thay đổi trong lúc ghi hàng đợi.
- `supabase/tests/reminder_flow.sql` kiểm tra chuỗi RPC thật đặt vé → check-in →
  snapshot nhắc → đọc thông báo → check-out → hủy push lỗi thời, trên PostgreSQL
  tạm. Seed và kiểm thử tranh chỗ vẫn qua. `tools/check_firebase_config.mjs`
  kiểm tra đúng hai flavor/cùng project, chặn file service account; **8 tests
  cấu hình Firebase qua**. Hai file client thật đã kiểm tra đúng package/app ID,
  project `smartpark-606ea`, được gitignore. Service account đã được người dùng
  lưu ở vị trí thỏa thuận và cấu hình chỉ cho Edge secrets.
- Supabase CLI 2.122.0 đã cài cục bộ trong `.smartpark/supabase-cli` (gitignore),
  đã đăng nhập và truy cập đúng project. Backend `push-dispatch` ACTIVE, chặn
  thiếu secret bằng 401, gọi hợp lệ trả 200; pg_net → worker trả 200, không timeout.
  Vault sinh/lưu dispatch secret ở server; hai lịch chạy mỗi phút có succeeded.
  Báo cáo Cloud: 9 vé expired, 8 thông báo overdue, 0 confirmed quá hạn chưa xử
  lý; chưa có thiết bị đăng ký, không gửi thông báo thử tới người dùng.
  Google OAuth chấp nhận service account. Probe FCM validate_only dùng token
  không phải thiết bị trả INVALID_ARGUMENT, không chứng minh giao FCM thật.
  File env/SQL tạm đã xóa, không có server key trong app hoặc Git.

### Chưa kiểm thử / giới hạn cần giữ rõ

- Chưa có điện thoại kết nối (`adb devices` trống), chưa chạy end-to-end 3 tài
  khoản trên Cloud, camera/QR/OCR/GPS thật, offline restart trên máy hoặc Realtime
  giữa hai điện thoại. Có integration test opt-in và checklist trong TESTING.md.
- Chưa đo độ chính xác OCR, frame times/60fps hay tải đồng thời lớn. Snapshot hiện
  phù hợp quy mô nhỏ; phân trang lịch sử phía server là hướng tối ưu khi dữ liệu tăng.
- iOS đã bổ sung quyền và deployment target 15.5; chưa build trên macOS/Xcode.
- Không có thanh toán online, điều khiển barrier vật lý hoặc offline basemap; giai
  đoạn này dùng thu tiền mặt và bản đồ nền online. Inbox đã nối Supabase; code
  push Android đã cấu hình client/server/lịch gửi, còn kiểm thử điện thoại thật
  với bản app có cấu hình mới. Web Push/iOS chưa làm.
- Hai Release APK đã build/ký cục bộ; AAB/Fastlane và workflow ký GitHub chưa được
  xác minh trong phiên này. Agent chưa phát hành/upload GitHub Releases, chưa
  triển khai hosting. Đã deploy riêng backend push theo luồng cấu hình được yêu
  cầu; không phát hành ứng dụng. Không có secret/service_role key trong app/Git.

### Bước chạy thử tiếp theo

Migrations 001/002/004 và lịch hạn vé đã được bạn xác nhận chạy trên Cloud;
không chạy lại các migration này. Chạy 003 nếu chưa có; không chạy SQL fixture
tests. Kiểm tra lượt chạy cron và luồng hết hạn/nhắc trong app theo NOTIFICATIONS.md.
Đăng ký/xác nhận tài khoản của bạn trong app khách, thay email
trong `supabase/bootstrap-owner.sql` rồi chạy script cấp owner trong SQL Editor.
Đăng nhập Admin để tạo bãi/vị trí/giá. Tạo tài khoản nhân viên riêng và phân công
qua Admin. Chi tiết ở SUPABASE_SETUP.md và TESTING.md; không cần gửi mật khẩu.
