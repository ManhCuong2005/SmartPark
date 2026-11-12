# Thiết lập SmartPark trên Supabase Cloud

Ứng dụng dùng project Cloud đã cung cấp. PostgreSQL cục bộ trong bộ test chỉ là
môi trường kiểm thử dùng rồi dừng, không phải backend của ứng dụng.

## Migrations

Trong SQL Editor của project phát triển SmartPark, chạy theo thứ tự:

1. `supabase/migrations/202610280001_smartpark.sql` (bạn đã xác nhận chạy thành công).
2. `supabase/migrations/202610280002_reservation_hardening.sql` bổ sung chống một
   phương tiện đặt nhiều vị trí trong cùng khoảng giờ và phát tín hiệu cập nhật
   chỗ trống công khai mà không lộ thông tin vé của khách khác.
3. `supabase/migrations/202610290003_staff_permissions.sql` cập nhật RPC cấp quyền
   nhân viên: chỉ chủ bãi được phân công tại bãi của mình, yêu cầu email đã xác
   nhận khi cấp quyền; thu hồi phân công cuối cùng trả tài khoản staff về customer.

4. `supabase/migrations/202610290004_deadlines_and_push.sql` bổ sung hạn vé,
   nhắc lấy xe và hàng đợi push (đã có trong project hiện tại).
5. `supabase/migrations/202611120005_booking_flow.sql` sửa đặt trước theo khoảng
   giờ, nhận khách đến trễ và tự hủy sau 1 tiếng kể từ giờ kết thúc. Chạy trước
   khi dùng app mới; xem [quy tắc và kiểm thử](BOOKING_FLOW.md).

6. `supabase/migrations/202611120006_booking_availability.sql` đồng bộ kiểm tra
   lịch xe/ô giữa giao diện và lệnh đặt, phân biệt hai loại xung đột và giữ receipt
   khi retry. App mới cần RPC này, không tự fallback sang dữ liệu ô trống cũ.

Mỗi migration chỉ chạy một lần. Không chạy lại 001 nếu đã thành công. Không chạy
`supabase/tests/bootstrap.sql` hoặc `behavior.sql` trên Cloud; đó là fixture test.
Nếu 002 gặp vé đặt trùng tồn tại, transaction sẽ thất bại và không tự xóa vé;
cần kiểm tra các vé đó trước khi áp dụng constraint.

## Tài khoản và ba vai trò

Trạng thái hiện tại: bạn đã xác nhận chạy thành công migration 001/002 và ngày
29/10/2026 xác nhận chạy 004 cùng `supabase/setup-reminder-scheduler.sql` trên
Cloud. Không chạy lại các migration này. Chạy **003** nếu chưa chạy. Cần kiểm tra
lịch Cron thực sự chạy và nhắc/hết hạn đúng bằng tài khoản thử; xác nhận chạy SQL
không thay thế kiểm thử end-to-end.
Thông báo Android cần cấu hình Firebase riêng, theo [NOTIFICATIONS.md](NOTIFICATIONS.md).
Ngày 12/11/2026 đã áp dụng 005/006 trên project hiện tại và xác minh RPC khả dụng
trên dữ liệu thật; giữ nguyên số vé/khoản thu. Không chạy lại hai migration này.

1. Chạy ứng dụng khách, đăng ký email/mật khẩu, xác nhận email nếu Auth yêu cầu.
2. Để tài khoản của bạn quản lý bãi, mở `supabase/bootstrap-owner.sql`, thay đúng
   email đã đăng ký, rồi chạy trong SQL Editor. Không chia sẻ mật khẩu.
3. Đăng nhập Admin Web bằng tài khoản đó. Tạo bãi, nhập địa chỉ/tọa độ và số vị trí,
   cấu hình giá ô tô/xe máy và thời gian miễn phí.
4. Nhân viên đăng ký và xác nhận email tài khoản riêng trong app khách. Chủ bãi
   vào **Nhân viên → Cấp quyền nhân viên**, nhập email đó, chọn bãi/ca rồi bấm
   **Cấp quyền và phân công**. RPC đổi customer thành staff và tạo phân công.
   Sau đó nhân viên đăng nhập app Staff. Bỏ chọn **Cho phép làm việc tại bãi này**
   trong Phân công để thu hồi quyền bãi đó. Nếu không còn phân công hoạt động
   ở bãi nào, tài khoản trở về customer; owner không bị hạ quyền.
5. Khách đăng ký, thêm phương tiện rồi đặt chỗ. Không có dữ liệu mẫu tự động.
   Nếu muốn nạp dữ liệu để xem giao diện/dashboard, xem
   [hướng dẫn nạp dữ liệu mẫu](../supabase/SEED_DEMO.md) và chạy riêng
   `supabase/seed-demo.sql` trong SQL Editor sau migrations 001/002.

Vai trò owner chỉ cấp qua thao tác quản trị tin cậy. Metadata đăng ký không thể tự
cấp role. Membership giới hạn nhân viên theo bãi; thu hồi membership cũng làm
các lệnh offline gửi lên sau đó bị từ chối.

## Auth, Realtime, Storage

- Auth email/password phải bật. Cấu hình Site URL và Redirect URLs về địa chỉ
  Admin Web đang dùng để khôi phục mật khẩu qua web; localhost khi phát triển,
  domain của bạn khi tự quyết định triển khai.
- Migration thêm các bảng vào publication `supabase_realtime`. Ứng dụng subscribe
  và tải lại snapshot, đồng thời tải lại định kỳ/khi nối mạng để bù sự kiện bị bỏ lỡ.
- Bucket `parking-evidence` riêng tư được chuẩn bị nếu cần mở rộng bằng chứng.
  OCR hiện tại xử lý ảnh on-device, không tải ảnh lên Cloud.
- Client chỉ có URL và publishable key. RLS bảo vệ việc đọc; thay đổi nghiệp vụ
  đi qua RPC kiểm tra quyền và transaction. Không nhúng secret/service_role key.

## Kiểm tra cấu hình

`node tools/check_cloud.mjs` chỉ đọc Auth settings và thăm dò bảng, không đăng ký
tài khoản hoặc thay đổi dữ liệu. Sau migration, HTTP 401 / `42501` khi truy cập
bảng không có đăng nhập là kết quả đúng; HTTP 404 / `PGRST205` nghĩa là chưa có bảng.

URL/key public có giá trị mặc định trong source. Có thể thay qua
`--dart-define-from-file=config/supabase.example.json` và `admin-web/.env.local`
theo `.env.example`. Các cấu hình đó không được dùng chứa khóa quản trị.

## Test toàn luồng trên Cloud (tự chọn, có ghi dữ liệu)

Dùng project phát triển và tài khoản kiểm thử do bạn sở hữu. Sao chép
`config/integration.example.json` thành `config/integration.local.json`, điền URL,
publishable key, ba tài khoản, ID bãi và mã vị trí trống. Khách phải có xe,
nhân viên đã được phân công và chủ bãi sở hữu bãi. Đặt
`SMARTPARK_TEST_ALLOW_WRITES` thành `true` chỉ khi chủ động chạy:

```powershell
flutter test integration_test/supabase_flow_test.dart -d DEVICE_ID --flavor customer --dart-define-from-file=config/integration.local.json
```

Test tạo vé, check-in/check-out và khoản thu trong project phát triển, không tự xóa
lịch sử tài chính. Mặc định test bị skip và chưa được chạy trong phiên triển khai
vì chưa có tài khoản/thiết bị kiểm thử. Kiểm tra OCR/camera/GPS bằng `docs/TESTING.md`.
