# BẢN PHÁT HÀNH TỔNG HỢP NÂNG CẤP HỆ THỐNG SMARTPARK (RELEASE v1.2.0)

> **Tài liệu chuẩn bị phát hành:** Dành cho việc Review và gộp vào nhánh chính (`main`).  
> **Tổng hợp từ 3 nguồn:**
> 1. Nhánh gốc `main`.
> 2. Các sửa đổi nghiệp vụ lõi từ nhánh `fix/advance-booking-and-flow`.
> 3. Các nâng cấp trải nghiệm người dùng (UX), tối ưu hóa dung lượng APK và tính năng VietQR.

---

## 📑 MỤC LỤC TỔNG QUAN THAY ĐỔI

1. **Cơ sở dữ liệu & Quy tắc Nghiệp vụ Lõi (Supabase / Backend)**
2. **Quy trình Đặt chỗ Trực quan 3 Bước (Customer Flow)**
3. **Quản lý Vận hành & Xử lý Vé No-Show (Staff Flow)**
4. **Hệ thống Thanh toán VietQR On-Device (EMVCo Napas247)**
5. **Cải tiến Nhận diện Biển số AI OCR (Việt Nam)**
6. **Tối ưu hóa Hiệu năng & Dung lượng Bản cài đặt (Android / CI-CD)**

---

## 1. 🗄️ CƠ SỞ DỮ LIỆU & QUY TẮC NGHIỆP VỤ LÕI (SUPABASE)

- **Bổ sung Migration 003 (`202610280003_fix_booking_flow_and_availability.sql`):**
  - **Tối ưu hàm `slot_availability`:** Chuyển đổi thành hàm `STABLE`, kiểm tra tính khả dụng của ô đỗ bằng toán tử khoảng thời gian `tstzrange` chính xác. Loại bỏ hoàn toàn câu lệnh ghi/cập nhật dữ liệu bên trong hàm đọc, tránh nghẽn transaction và xung đột khóa.
  - **Tự động xử lý No-show (`cancel_no_shows`):** Tự động chuyển trạng thái các vé quá 1 giờ sau giờ hẹn (`now() >= starts_at + 1h`) sang `cancelled` để giải phóng vị trí cho khách khác.
  - **Hỗ trợ khách đến trễ linh hoạt (`flexible check-in`):** Khi khách đến trễ sau giờ hẹn dự kiến (`ends_at`), hệ thống cho phép nhân viên check-in và tự động gia hạn thêm 1 giờ nếu ô đỗ đó chưa có người khác đặt tiếp theo.

---

## 2. 📱 QUY TRÌNH ĐẶT CHỖ TRỰC QUAN 3 BƯỚC (CUSTOMER FLOW)

- **Đảo ngược luồng đặt chỗ logic:**
  - **Luồng cũ:** Chọn ô đỗ trước ➔ Sau đó mới chọn thời gian (dễ dẫn đến xung đột nếu ô đó đã có người đặt trong khoảng giờ vừa chọn).
  - **Luồng mới:** `01 Thời gian` ➔ `02 Chọn chỗ` ➔ `03 Xác nhận`. Đảm bảo sơ đồ bãi xe chỉ hiển thị các ô thực sự còn trống trong khung giờ khách cần.
- **Thanh chọn thời lượng nhanh (Quick Duration Chips):**
  - Tích hợp 4 mốc chọn nhanh: **`+1h`**, **`+2h`**, **`+4h`**, **`+8h`** tại màn hình chọn giờ. Khách hàng chỉ cần 1 chạm để tính giờ ra và tải lại chỗ trống ngay lập tức.
  - Tích hợp rung phản hồi xúc giác nhẹ (`HapticFeedback.selectionClick()`) khi chọn mốc giờ.
- **Trực quan hóa sơ đồ ô đỗ xe 4 màu (`SlotGrid` & `SlotLegend`):**
  - 🟢 **Màu xanh lá:** Ô còn trống, có thể chọn đặt ngay.
  - 🟡 **Màu vàng (`#FFF3CD`):** Ô vừa mới được đặt trước (trong vòng 10 phút gần nhất), đang trong thời gian giữ chỗ.
  - ⚪ **Màu xám:** Ô đã có xe đỗ hoặc đã được đặt trước đó.
  - 🔵 **Màu xanh dương:** Ô bạn đang chọn.
  - Bổ sung thanh **Chú thích trạng thái màu** cuộn ngang rõ ràng, dễ hiểu.

---

## 3. 🛡️ QUẢN LÝ VẬN HÀNH & XỬ LÝ VÉ NO-SHOW (STAFF FLOW)

- **Danh sách "Xe đã đặt trước / Sắp đến" tại bãi:**
  - Nhân viên soát vé có thể xem trước các xe sắp đến trong ca trực.
  - Cảnh báo trực quan màu đỏ: **"Quá hẹn 1h (No-show)"** đối với các xe không đến đúng giờ hẹn.
  - Cung cấp nút hủy vé No-show trực tiếp kèm xác nhận an toàn (`confirmAction`), bọc `runAction` và kiểm tra `context.mounted`.
- **Haptic Feedback khi thao tác thực địa:**
  - Tích hợp rung `mediumImpact` khi camera bắt được mã QR hợp lệ.
  - Tích hợp rung `lightImpact` khi ML Kit nhận diện thành công biển số xe.

---

## 4. 💳 HỆ THỐNG THANH TOÁN VIETQR ON-DEVICE (EMVCo)

- **Chuyển đổi sang chuẩn EMVCo Payload nội bộ (`vietqr_service.dart`):**
  - Tự động sinh chuỗi dữ liệu Napas247 kèm mã kiểm tra CRC-16 trên thiết bị.
  - Vẽ mã QR trực tiếp qua `QrImageView`, **chạy 100% offline, độc lập hoàn toàn với các dịch vụ sinh ảnh bên thứ ba**, loại bỏ triệt để lỗi timeout/hết hạn phiên.
- **Tiện ích sao chép thông tin nhanh:**
  - Dưới mã VietQR có sẵn ô hiển thị Số tài khoản ngân hàng và Cú pháp chuyển khoản định danh vé xe (`SPK <BIỂN_SỐ>`).
  - Tích hợp 2 nút **`Sao chép STK`** và **`Sao chép ND`** vào bộ nhớ tạm (Clipboard), thuận tiện cho người dùng thanh toán trên cùng một điện thoại.
- **Cảnh báo đếm ngược thời gian giữ chỗ:**
  - Hiển thị hạn chót check-in trên vé điện tử.
  - Tự động đổi sang **màu cam cảnh báo** khi còn dưới 15 phút và **màu đỏ** khi đã quá 1 tiếng.

---

## 5. 🔍 CẢI TIẾN NHẬN DIỆN BIỂN SỐ AI OCR (VIỆT NAM)

- **Nâng cấp hàm `plateCandidates()` trong `parking_rules.dart`:**
  - Hỗ trợ nhận diện biển số xe máy 2 dòng phổ biến ở Việt Nam (dòng trên là mã tỉnh/quận, dòng dưới là số đăng ký).
  - Thuật toán ghép dòng thông minh và chuẩn hóa regex loại bỏ ký tự nhiễu nhưng không đoán mò sai lệch giữa chữ `O`/`0` hay `I`/`1`.

---

## 6. 🚀 TỐI ƯU HÓA HIỆU NĂNG & DUNG LƯỢNG BẢN CÀI (ANDROID / CI-CD)

- **R8 / ProGuard Code & Resource Shrinking (`android/app/build.gradle.kts`):**
  - Kích hoạt `isMinifyEnabled = true` và `isShrinkResources = true`. Loại bỏ mã thừa từ các bộ thư viện ML Kit không dùng tới.
  - Cấu hình fallback ký release tự động bằng debug keystore khi chạy trên CI GitHub Actions.
- **Workflow Đóng gói Tự động (`.github/workflows/release.yml`):**
  - Áp dụng kỹ thuật `--split-per-abi`, tự động tạo 3 bản APK riêng biệt (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
  - **Bản `arm64-v8a` tối ưu giảm hơn 50% dung lượng** (chỉ còn khoảng 31MB - 39MB), giúp cài đặt nhanh chóng và mượt mà.
- **Môi trường phát triển cục bộ (`docker-compose.yml`):**
  - Định nghĩa sẵn dịch vụ PostgreSQL 15 và PostgREST tự nạp migrations giúp lập trình viên chạy thử offline không phụ thuộc Cloud.

---

## 📝 DANH SÁCH TẬP TIN THAY ĐỔI TỔNG HỢP

| Đường dẫn tập tin | Loại thay đổi | Mô tả |
| :--- | :---: | :--- |
| `supabase/migrations/202610280003_fix_booking_flow_and_availability.sql` | Thêm mới | Migration sửa hàm `slot_availability`, xử lý No-show và late check-in. |
| `lib/presentation/features/booking/booking_flow.dart` | Chỉnh sửa | Đảo luồng chọn thời gian lên trước, bổ sung thanh chọn nhanh `+1h/+2h/+4h/+8h`. |
| `lib/presentation/features/booking/booking_screens.dart` | Chỉnh sửa | Cập nhật `SlotGrid` hiển thị ô màu vàng đang giữ chỗ và thanh chú thích `SlotLegend`. |
| `lib/presentation/park_controller.dart` | Chỉnh sửa | Thêm getter `recentlyReserved` lọc các chỗ đỗ được đặt trong vòng 10 phút. |
| `lib/presentation/features/tickets/live_tickets.dart` | Chỉnh sửa | Tích hợp VietQR EMVCo, nút sao chép STK/nội dung và cảnh báo đếm ngược giữ chỗ. |
| `lib/presentation/features/staff/operational_screens.dart` | Chỉnh sửa | Bổ sung danh sách xe sắp đến, cảnh báo No-show và Haptic feedback camera. |
| `lib/domain/parking_rules.dart` | Chỉnh sửa | Cải tiến thuật toán ghép dòng biển số xe máy 2 dòng của Việt Nam. |
| `lib/domain/vietqr_service.dart` | Thêm mới | Module helper sinh chuỗi chuẩn EMVCo Napas247 offline on-device. |
| `android/app/build.gradle.kts` | Chỉnh sửa | Kích hoạt R8 ProGuard minify, shrinkResources và cấu hình ký CI. |
| `.github/workflows/release.yml` | Thêm mới | Tự động hóa build APK tối ưu Split-per-ABI và upload lên GitHub Releases. |
| `docker-compose.yml` | Thêm mới | Môi trường Supabase Local container hóa. |

---

*Bản phát hành này đã sẵn sàng để bạn kiểm tra nội dung trước khi gộp (merge) trực tiếp vào nhánh `main`.*

