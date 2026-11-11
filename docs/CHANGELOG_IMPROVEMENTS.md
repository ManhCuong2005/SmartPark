# NHẬT KÝ CÁC CẢI TIẾN & NÂNG CẤP DỰ ÁN SMARTPARK (UNCOMMITTED)

> **Ghi chú quan trọng:** Tất cả thay đổi dưới đây hiện đang nằm ở trạng thái **Working Directory (chưa commit)** để bạn có thể tự tạo nhánh Git riêng (ví dụ: `feature/improvements-ux-payment`) và commit theo cấu trúc mong muốn.

---

## 1. TỔNG HỢP CÁC TÍNH NĂNG & THAY ĐỔI ĐÃ THỰC HIỆN

### 📱 1. Trải Nghiệm Mobile & OCR (Flutter)
- **Haptic Feedback (Phản hồi rung xúc giác):**
  - Đã tích hợp `HapticFeedback.mediumImpact()` khi camera phát hiện mã QR hợp lệ trong `StaffScannerScreen`.
  - Tích hợp `HapticFeedback.lightImpact()` ngay khi hệ thống ML Kit nhận diện được biển số trong `StaffConfirmationScreen`.
  - Tệp chỉnh sửa: [`lib/presentation/features/staff/operational_screens.dart`](file:///d:/Files/SmartPark/lib/presentation/features/staff/operational_screens.dart).
- **Chọn Thời Lượng Đỗ Xe Nhanh (Quick-duration Chips):**
  - Màn hình `TimeSelectionScreen` được bổ sung các chip chọn nhanh: `+1h`, `+2h`, `+4h`, `+8h`.
  - Giúp khách hàng bấm 1 chạm để tính giờ ra và tải lại chỗ trống ngay lập tức mà không cần mở nhiều hộp thoại ngày/giờ phức tạp.
  - Tệp chỉnh sửa: [`lib/presentation/features/booking/booking_flow.dart`](file:///d:/Files/SmartPark/lib/presentation/features/booking/booking_flow.dart).
- **Cải tiến Nhận Diện Biển Số Xe Máy 2 Dòng (Vietnam Plate Normalization):**
  - Tối ưu hóa hàm `plateCandidates()` trong `parking_rules.dart`: Tự động ghép nối các dòng biển số bị ngắt đoạn (thường gặp ở biển xe máy Việt Nam dòng trên gồm tỉnh/quận, dòng dưới gồm dãy số) và chuẩn hóa loại bỏ ký tự lạ.
  - Tệp chỉnh sửa: [`lib/domain/parking_rules.dart`](file:///d:/Files/SmartPark/lib/domain/parking_rules.dart).

---

### 💳 2. Thanh Toán Chuyển Khoản Trực Tuyến (VietQR Napas247)
- **VietQR Helper Service:**
  - Tạo mới module `vietqr_service.dart` hỗ trợ chuẩn sinh QR động liên ngân hàng (VietQR / Napas247).
  - Tệp tạo mới: [`lib/domain/vietqr_service.dart`](file:///d:/Files/SmartPark/lib/domain/vietqr_service.dart).
- **Tích hợp Nút Thanh Toán VietQR trên Vé Điện Tử:**
  - Trên màn hình chi tiết vé (`TicketScreen`), khi xe đang gửi hoặc đã checkout cần thanh toán, khách hàng có thể chọn **"Thanh toán qua VietQR"** để hiển thị mã QR động có sẵn số tiền và nội dung chuyển khoản theo biển số xe.
  - Tệp chỉnh sửa: [`lib/presentation/features/tickets/live_tickets.dart`](file:///d:/Files/SmartPark/lib/presentation/features/tickets/live_tickets.dart).

---

### 🐳 3. Môi Trường Phát Triển Cục Bộ (Local Dev)
- **Docker Compose cho Supabase Database & REST:**
  - Tạo tệp `docker-compose.yml` định nghĩa PostgreSQL 15 (Supabase Postgres) và PostgREST container. Tự động load các migration trong `supabase/migrations/` để lập trình viên có thể test ngay mà không bị lệ thuộc vào mạng internet hoặc tài khoản Cloud.
  - Tệp tạo mới: [`docker-compose.yml`](file:///d:/Files/SmartPark/docker-compose.yml).

---

## 2. HƯỚNG DẪN TẠO BRANCH VÀ COMMIT

Để lưu các thay đổi này vào một nhánh riêng trên Git, bạn có thể thực hiện theo các bước sau trong terminal của thư mục `d:\Files\SmartPark`:

```powershell
# 1. Tạo và chuyển sang branch mới
git checkout -b feature/ux-vietqr-enhancements

# 2. Xem lại danh sách các tệp đã thay đổi
git status

# 3. Thêm các tệp vào staging
git add lib/ docker-compose.yml docs/CHANGELOG_IMPROVEMENTS.md

# 4. Commit với nội dung mô tả rõ ràng
git commit -m "feat: improve mobile UX, quick duration chips, VietQR payment, and local docker setup"
```

