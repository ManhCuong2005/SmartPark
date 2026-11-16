# Admin điều chỉnh số dư và máy quét tự động

Sau khi đã áp dụng 001–014, chạy **một lần**
`supabase/migrations/202611160015_admin_wallet_and_owner_kiosk.sql` trong SQL Editor.
Không chạy lại các migration đã thành công. Chưa có thay đổi nào được tự động
áp dụng lên CSDL Cloud từ việc sửa source.
Sau 015, áp dụng thêm `supabase/migrations/202611160016_directional_kiosk.sql`
để máy quét chỉ thực hiện chiều vào/ra đã chọn. Xem `docs/AUTOMATIC_SCANNING.md`.

## Các phần nhân viên được gỡ

- Xóa bảng phân công `lot_staff`, API `manage_staff`, vai trò `staff` và phân công
  người xử lý báo cáo. Báo cáo được admin trực tiếp cập nhật trạng thái.
- Tài khoản từng là nhân viên chuyển thành khách hàng; giữ nguyên tài khoản,
  phương tiện, ví, vé và giao dịch. Tài khoản admin `owner` giữ nguyên quyền.
- Không xóa người ghi nhận trên giao dịch cũ để bảo toàn lịch sử tài chính.
- Admin Web bỏ trang/menu nhân viên, ca làm việc, tìm kiếm nhân viên và hướng dẫn
  thu tiền tại chỗ. Máy quét đăng nhập bằng admin và chỉ quét các bãi của admin đó.
- Các migration 001–014 và kiểm thử lịch sử vẫn được giữ để có thể nâng cấp từ
  phiên bản cũ. Script seed ba vai trò trước đây thuộc phiên bản cũ, không dùng
  để nạp dữ liệu sau 015.

## Sử dụng

Chạy `Run-SmartPark.cmd`, đăng nhập Admin, mở **Số dư tài khoản** (`/wallets`).
Tìm email/tên, chọn **Cộng tiền** hoặc **Trừ tiền**, nhập số tiền và lý do, kiểm
tra tài khoản/số dư dự kiến rồi xác nhận. Mỗi lần từ 1đ đến 5.000.000đ, số nguyên;
lý do dài 3–500 ký tự. Màn hình hiển thị 25 tài khoản/trang và 20 điều chỉnh gần
nhất theo từ khóa. Lịch sử đầy đủ nằm trong bảng `wallet_adjustments`.

Quản trị viên là tài khoản có `profiles.role='owner'`, cùng quyền hiện dùng để
đăng nhập Admin. Quyền này được phép điều chỉnh ví các tài khoản trong hệ thống,
không chỉ khách từng đặt tại một bãi. Tài khoản khách không có quyền liệt kê ví
người khác hoặc thay đổi số dư.

## Hợp đồng backend

- `admin_wallet_accounts(p_query, p_offset, p_limit)` chỉ dành cho admin, trả
  `{accounts, adjustments, total}`. Mỗi tài khoản có số dư đã tính từ tiền nạp,
  điều chỉnh và tiền gửi xe đã trả.
- `admin_adjust_wallet(p_operation_id, p_customer_id, p_amount, p_reason)` chỉ
  dành cho admin; số tiền có dấu dương để cộng, âm để trừ. Máy chủ kiểm tra tài
  khoản, giới hạn số tiền, lý do, số dư và quyền người gọi.
- Thay đổi và thông báo khách commit cùng nhau. Không cho số dư âm, không trừ
  một phần và không sửa/xóa lịch sử. Số dư sau giao dịch được lưu trong biên nhận.
- Cùng UUID và cùng nội dung trả lại biên nhận cũ, không ghi thêm giao dịch.
  UUID đã dùng với nội dung khác báo `OPERATION_ID_REUSED`.
- Client lưu yêu cầu trước khi gửi. Khi timeout/mất phản hồi hoặc tải lại trang,
  chỉ thử lại cùng UUID và giữ nguyên nội dung. Lỗi xác định như thiếu số dư cho
  phép sửa lại yêu cầu. Đổi tài khoản không hiện kết quả của tài khoản trước.
- Cộng/trừ thủ công dùng chung khóa khách hàng với thanh toán đặt vé và quét xe
  ra, tránh hai giao dịch cùng tiêu một số dư. Đây là sổ điều chỉnh riêng, không
  giả làm một giao dịch payOS và không được tính vào doanh thu gửi xe.
- Khách nhận thông báo lý do; app làm mới số dư khi đồng bộ, mở lại ví hoặc bấm
  tải lại. Số dư mới được sử dụng cho đặt vé, gia hạn và thanh toán khi xe ra.

## Chạy local

```powershell
cd D:\LapTrinhDaNenTang\SmartPark-old
flutter pub get
.\Run-SmartPark.cmd
```

Máy quét riêng:

```powershell
flutter run -d chrome -t lib/main_kiosk.dart
```

Entry point `lib/main_staff.dart`, flavor Android `staff`, và tên RPC
`staff.check_in`/`staff.check_out` là tên kỹ thuật cũ để tương thích bản đã cài;
chúng không cấp vai trò nhân viên. Giao diện mới dùng tên SmartPark Camera.

## Kiểm thử

```powershell
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin
flutter test
flutter analyze
cd admin-web
npm run build
npm test
```

SQL tests dùng PostgreSQL tạm local và kiểm tra quyền, chống lặp, số dư âm, bảo
toàn dữ liệu cũ và xung đột đồng thời giữa điều chỉnh ví với thu phí khi xe ra.
Browser tests dùng API giả trong môi trường test và ảnh chụp UI mobile/desktop;
không thực hiện giao dịch trên Cloud.
