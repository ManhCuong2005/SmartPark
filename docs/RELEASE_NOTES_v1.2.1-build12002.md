# SmartPark 1.2.1 — build 12002

Nhánh: `release/booking-fix-v1.2.1`. Android versionName `1.2.1`, versionCode `12002`.

- Customer: đặt/gia hạn trả ngay hoặc trả sau; trả sau yêu cầu số dư trên 100.000đ.
  Backend tính và thu phần chưa trả khi xe ra, không cho số dư âm.
- SmartPark Camera thay giao diện nhân viên: admin chọn bãi, chọn cam vào/ra,
  chọn thiết bị nếu có nhiều camera, sau đó tự nhận biển số qua nhiều khung hình.
- Sửa preview Web bị soi gương, giữ đồng thuận khi OCR chậm, xử lý tương phản
  cục bộ cho biển sáng trên nền xe tối. Camera cần được căn chỉnh ngoài thực tế.
- Phiên camera bị ràng buộc với tài khoản/bãi/chiều trên backend: cam vào không
  checkout hoặc thu tiền; cam ra không check-in. Chống xử lý và thu tiền lặp.
- Admin bỏ quản lý/phân công nhân viên, thêm tìm tài khoản và cộng/trừ số dư
  kèm lý do/lịch sử; giữ tài khoản, vé và giao dịch lịch sử.

## Trước khi dùng

Áp dụng migration 013–016 theo thứ tự, **chỉ chạy những migration chưa thành công**.
Nếu 012–014 đã có thì chỉ thêm 015 và 016. Không chạy SQL fixture/test lên Cloud.
Máy quét cần đăng nhập admin `owner` có bãi. Cấp quyền camera/âm thanh thiết bị.

Hai APK release:

- `smartpark-v1.2.1-build12002-customer.apk`: `vn.smartpark.smartpark.customer`.
- `smartpark-v1.2.1-build12002-camera.apk`: `vn.smartpark.smartpark.staff`.

Giữ package Camera `.staff` để cập nhật được app cũ khi chữ ký trùng.
Build này không tự cập nhật tag, xóa release hay thay APK cũ trên GitHub.
File output mặc định local có thể bị ghi đè khi build lại; bộ APK bàn giao và
bản sao lưu cũ được giữ riêng trong `.smartpark/releases/`.

## Xác minh

187 Flutter tests, 42 Admin browser tests, PostgreSQL migration/authorization/
wallet/concurrency tests, 19 Node tests, Flutter analyze và Web build đã qua local.
Browser integration dùng camera_web/OCR thật với video tổng hợp và backend test;
SQL tests riêng xác minh quyền/tiền. Chưa kiểm thử camera/loa lắp thật hoặc áp dụng
migration lên Supabase Cloud từ phiên làm việc này.
