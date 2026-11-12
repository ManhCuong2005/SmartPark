# Xóa vé bỏ hẹn và gia hạn vé đang gửi

Quy tắc mới theo lựa chọn người dùng ngày 12/11/2026 thay thế việc giữ thêm một
giờ sau giờ ra. Vé `confirmed` chưa check-in hết hiệu lực ngay tại `ends_at`.
Cron mỗi phút xóa bản ghi chưa sử dụng đã hết hạn, kể cả `expired` từ quy tắc cũ;
request-time cleanup cũng xóa theo phạm vi tài khoản hoặc ô đang đặt.
Availability và check-in từ chối vé quá hạn ngay, không chờ cron xóa xong.

Chỉ xóa vé không có `checked_in_at`, parking event và payment. Vé đang gửi,
hoàn thành hoặc có khoản thu không bị xóa. Thông báo cũ được gỡ liên kết trước
khi xóa vé để không vi phạm khóa ngoại. Receipt tạo vé chuyển thành tombstone
tối thiểu (không QR) để retry cũ không hồi sinh vé. Vé biến mất khỏi lịch sử.

Khách mở vé đang gửi → **Gia hạn thời gian** → +1/+2/+4 giờ. Hiển thị giờ ra mới
và phí dự kiến; máy chủ kiểm tra chủ vé, trạng thái, version, lịch ô và lịch xe.
Nếu trùng lịch, không đổi giờ và giữ form để chỉnh. Gia hạn online-only, không
tạo payment; phí vẫn thu khi xe ra theo quy tắc tối thiểu một giờ.

Nhắc trước **10 phút**, kèm hướng dẫn gia hạn hoặc ra đúng giờ. Nếu đã quá giờ,
nhắc lấy xe/gia hạn và tiếp tục tính phí, không xóa xe đang trong bãi. Notification
dedupe theo vé + giờ kết thúc nên gia hạn thành công sẽ có nhắc theo giờ mới.
Worker claim bỏ nhắc theo giờ cũ chưa được gửi; thông báo đã giao vẫn là lịch sử.
Cron chạy mỗi phút; FCM/Internet/quyền thông báo ảnh hưởng lúc điện thoại nhận.

Migration: `202611120008_expiry_and_extensions.sql` sau 007, chạy một lần.
Đã áp dụng ngày 12/11/2026; xử lý 22 vé bỏ hẹn cũ, giữ nguyên 10 xe đang gửi và
741 khoản thu tại thời điểm đối chiếu. Cron tiếp tục active và succeeded mỗi phút.
157 Flutter tests, phân tích mã và SQL migration/demo/concurrency đều qua.
Không sửa migration cũ. Bộ SQL test chạy quy tắc cũ trước 008 để chứng minh chuỗi
nâng cấp, sau đó kiểm tra chính sách mới, QR cũ, receipt, scope, gia hạn và nhắc.
Các test trả về số tiền vẫn dựa payment thực tế, không tạo doanh thu khi gia hạn.
Không push/pull hoặc build APK trong lượt sửa này.
