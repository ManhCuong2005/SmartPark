# SmartPark v1.2.1

APK Customer và Staff được build từ nhánh `release/booking-fix-v1.2.1`.

- Chọn ngày/giờ trước, kiểm tra chỗ trống rồi chọn ô và xác nhận.
- Phân biệt ô đã được đặt với xe có vé trùng giờ tại bãi khác.
- Sửa nút Tiếp tục mất thao tác chuyển màn hình khi phản hồi mạng chậm.
- Nhận xe đến trễ trong hạn giữ chỗ; tự hết hạn sau 1 tiếng từ giờ ra dự kiến.
- Thêm thời lượng nhanh và phản hồi rung khi quét thành công.
- Cải thiện lịch sử vé, đồng bộ offline, bản đồ và thông báo.

Đã qua 148 Flutter tests và kiểm thử PostgreSQL cục bộ. Migration 005/006 đã
áp dụng trên project Supabase hiện tại. Camera, OCR và push cần kiểm tra trên
thiết bị mục tiêu. APK ký bằng khóa release được cấu hình tại máy build.

Phiên bản Android: 1.2.1, versionCode 12001. Hai APK có application ID riêng.
