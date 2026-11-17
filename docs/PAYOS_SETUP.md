# Thanh toán vé và nạp số dư qua payOS trong SmartPark

Trong payOS, dùng kênh thanh toán SmartPark đã chọn đúng tài khoản nhận.
Trong Supabase Dashboard của SmartPark, vào **Edge Functions → Secrets** và
tự điền `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` từ kênh đó.
Các khóa chỉ thuộc backend. Flutter dùng phiên đăng nhập Supabase hiện có.

1. Áp dụng migration `202611120011_payos_topups.sql` sau các migration trước.
2. Deploy function `payos-topup` bằng CLI từ repo, với project ref đã xác minh.
   Cấu hình `verify_jwt = false` trong repo cho phép webhook không có JWT;
   function kiểm tra chữ ký payOS hoặc phiên đăng nhập tùy loại yêu cầu.
3. Trong kênh thanh toán payOS, đặt Webhook URL thành
   `https://<project-ref>.supabase.co/functions/v1/payos-topup?webhook=1`.
   URL không có tham số này dùng để hướng dẫn quay lại app sau thanh toán.
4. Chạy customer APK, vào **Tài khoản → Số dư gửi xe**, tạo QR từ 2.000 ₫,
   kiểm tra người nhận trên trang payOS rồi chuyển khoản thử. Quay lại app và
   chọn **Kiểm tra giao dịch** nếu số dư chưa tự cập nhật. Xác nhận đơn chỉ
   xuất hiện một lần và số dư tăng đúng số tiền.

Mỗi yêu cầu có hiệu lực 30 phút. Giao dịch chỉ được ghi nhận khi API payOS
xác nhận đơn đúng mã, đúng link và đã thanh toán đủ. Chức năng này ghi nhận
tiền nạp. Khấu trừ phí gửi xe là luồng riêng.

## QR thanh toán vé và gia hạn

App dùng cùng function `payos-topup`: `create` tạo QR nạp số dư,
`create_booking` tạo QR trả trước vé/gia hạn, `check` đối soát cả hai loại.
Sau khi payOS xác nhận đã nhận đủ tiền, backend ghi nhận tiền và thanh toán vé
trong cùng giao dịch. Webhook hoặc nút kiểm tra đều không được ghi tiền hai lần.
Nếu hết chỗ hoặc lịch thay đổi khi đang chuyển khoản, tiền vẫn ở số dư để đặt lại.

Phải áp dụng migration 012 và các migration tiếp theo trước khi dùng QR vé.
Sau khi cập nhật code, cần **deploy lại `payos-topup`** trên cùng project.
Build APK hoặc chạy SQL không tự cập nhật Edge Function. Bản function chỉ hỗ trợ
`create` sẽ từ chối `create_booking`, khiến app không mở được QR thanh toán vé
dù QR nạp số dư vẫn hoạt động. Không tạo thêm kênh payOS hoặc đổi webhook/khóa
chỉ để bật thanh toán vé; hai chức năng dùng chung cấu hình hiện có.

Kiểm thử local: `node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin`
kiểm tra đối soát, trả trước, chống trùng và xử lý tiền khi lịch thay đổi.
`flutter test test/payos_booking_api_test.dart` kiểm tra hợp đồng HTTP của app.
Các bài này không thực hiện chuyển khoản ngân hàng thật.
