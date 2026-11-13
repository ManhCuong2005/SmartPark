# Nạp tiền payOS trong SmartPark

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
