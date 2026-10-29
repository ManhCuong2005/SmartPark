# Kiểm thử SmartPark

## Tự động, không ghi Cloud

```powershell
flutter analyze
flutter test --reporter expanded
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin
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

Backend tests chạy migration SQL thật trong PostgreSQL tạm trên localhost, dừng
server sau test. Kiểm tra role không tự nâng quyền, RLS, quyền theo bãi, overlap,
version, đối chiếu biển số, idempotency check-in/out, một khoản thu mỗi vé và hai
phiên DB tranh cùng vị trí. Fixture auth/storage mô phỏng schema Supabase-owned;
Auth service và Realtime network thật không được chứng minh bằng test SQL.

Playwright chạy SDK và giao diện Admin với HTTP responses trong test, kiểm tra
đăng nhập/phân quyền UI, dữ liệu doanh thu, RPC/version, lỗi xung đột và 6 màn hình
ở 390/768/1440px. Ảnh review sáng/tối trong `admin-web/test-results/` là ảnh từ test
fixtures, không phải ảnh dữ liệu vận hành Cloud. Cổng ngoài Cloud bị intercept.

## Cần kiểm tra trên thiết bị thật

1. Migrations 001/002 đã được bạn xác nhận áp dụng. Đăng ký/xác nhận ba tài khoản
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
