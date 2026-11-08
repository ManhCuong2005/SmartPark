# BÁO CÁO TỔNG HỢP CÁC NÂNG CẤP & CẢI TIẾN HỆ THỐNG SMARTPARK

> **Phiên bản:** v1.1.0  
> **Nhánh phát triển:** `cmtran`  
> **Dự án:** SmartPark Mobile & Backend System

---

## 1. TỔNG HỢP CÁC THAY ĐỔI CHI TIẾT

### 📱 1.1. Trải nghiệm Mobile & Phản hồi xúc giác (Haptic Feedback)
- **Tập tin chỉnh sửa:** [`lib/presentation/features/staff/operational_screens.dart`](file:///d:/Files/SmartPark/lib/presentation/features/staff/operational_screens.dart)
  - **Quét vé QR:** Tích hợp `HapticFeedback.mediumImpact()` khi camera phát hiện mã QR hợp lệ, tạo phản hồi rung tức thì giúp nhân viên xác nhận thao tác thành công.
  - **Nhận diện biển số OCR:** Tích hợp `HapticFeedback.lightImpact()` ngay khi hệ thống ML Kit nhận diện được biển số trên camera.

### ⚡ 1.2. Chọn nhanh thời lượng đỗ xe (Quick Duration Chips)
- **Tập tin chỉnh sửa:** [`lib/presentation/features/booking/booking_flow.dart`](file:///d:/Files/SmartPark/lib/presentation/features/booking/booking_flow.dart)
  - Bổ sung thanh chọn nhanh thời gian đỗ với 4 mức: **`+1h`**, **`+2h`**, **`+4h`**, **`+8h`**.
  - Bấm 1 chạm tự động cập nhật giờ ra và tải lại số chỗ trống (availability) theo thời gian thực mà không cần mở nhiều dialog chọn giờ phức tạp.

### 🔍 1.3. Tối ưu nhận diện biển số xe máy 2 dòng Việt Nam
- **Tập tin chỉnh sửa:** [`lib/domain/parking_rules.dart`](file:///d:/Files/SmartPark/lib/domain/parking_rules.dart)
  - Cải tiến hàm `plateCandidates()`: Bổ sung thuật toán ghép nối 2 dòng biển số bị ngắt đoạn (thường gặp khi camera chụp biển số xe máy tại Việt Nam: dòng trên là tỉnh/quận, dòng dưới là số xe).
  - Chuẩn hóa loại bỏ các ký tự nhiễu nhưng vẫn đảm bảo độ chính xác theo regex biển số Việt Nam.

### 💳 1.4. Thanh toán chuyển khoản tự động qua VietQR (Napas247)
- **Tập tin tạo mới:** [`lib/domain/vietqr_service.dart`](file:///d:/Files/SmartPark/lib/domain/vietqr_service.dart)
  - Xây dựng module `VietQrHelper` hỗ trợ tạo URL mã VietQR chuẩn Napas247 / EMVCo với mã BIN các ngân hàng phổ biến (MBBank, Vietcombank, Techcombank, BIDV...).
- **Tập tin chỉnh sửa:** [`lib/presentation/features/tickets/live_tickets.dart`](file:///d:/Files/SmartPark/lib/presentation/features/tickets/live_tickets.dart)
  - Thêm nút **"Thanh toán qua VietQR"** trên màn hình chi tiết vé điện tử. Khách hàng có thể quét mã QR động có sẵn số tiền và nội dung chuyển khoản để thanh toán nhanh qua app ngân hàng.

### 🚀 1.5. Tối ưu hóa dung lượng APK (ProGuard / R8 & Split-per-ABI)
- **Tập tin chỉnh sửa:** [`android/app/build.gradle.kts`](file:///d:/Files/SmartPark/android/app/build.gradle.kts)
  - Kích hoạt `isMinifyEnabled = true` (R8 code shrinking & dead-code elimination).
  - Kích hoạt `isShrinkResources = true` (Tự động loại bỏ ảnh và tài nguyên thừa không dùng đến).
- **Tập tin tạo mới:** [`.github/workflows/release.yml`](file:///d:/Files/SmartPark/.github/workflows/release.yml)
  - Áp dụng kỹ thuật `split-per-abi` khi build release giúp tách riêng kiến trúc `arm64-v8a`, giảm hơn 50% - 60% dung lượng file cài đặt APK.

### 🐳 1.6. Môi trường phát triển cục bộ (Local Dev)
- **Tập tin tạo mới:** [`docker-compose.yml`](file:///d:/Files/SmartPark/docker-compose.yml)
  - Thiết lập PostgreSQL 15 (Supabase Postgres) và PostgREST container. Tự động áp dụng toàn bộ schema và migration từ thư mục `supabase/migrations/`.

---

## 2. HƯỚNG DẪN BUILD VÀ CÀI ĐẶT APK

### 2.1. Tự động build & phát hành qua GitHub Actions (Khuyến nghị)
Khi push tag lên GitHub, workflow sẽ tự động chạy và đính kèm 2 file APK lên mục Releases:
```bash
git tag v1.1.0
git push origin v1.1.0
```

### 2.2. Biên dịch thủ công trên máy cục bộ
```powershell
# Build bản Customer (Khách hàng)
flutter build apk --flavor customer -t lib/main.dart --release --split-per-abi

# Build bản Staff (Nhân viên soát vé)
flutter build apk --flavor staff -t lib/main_staff.dart --release --split-per-abi
```
