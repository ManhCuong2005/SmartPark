# Nạp dữ liệu mẫu SmartPark

File cần chạy trên Supabase Cloud: **`supabase/seed-demo.sql`**.
Đây là dữ liệu mô phỏng do người dùng chủ động nạp vào database, không phải
mock/fallback trong ứng dụng. Không dùng số tiền này làm báo cáo kinh doanh thật.

## Chạy ngay với tài khoản hiện tại

1. Đã chạy migrations **001 và 002**. Không chạy lại hai migration này. Chạy thêm
   `supabase/migrations/202610290003_staff_permissions.sql` để cập nhật cấp/thu hồi quyền nhân viên.
2. Cả ba tài khoản dưới đây đã đăng ký và xác nhận email:
   - Chủ bãi: `manhcuongnguyen2205@gmail.com`.
   - Khách: `dadinhviruscorona@gmail.com`.
   - Nhân viên: `cuongnm.23it@vku.udn.vn`.
3. Mở `seed-demo.sql`, sao chép **toàn bộ** vào Supabase → SQL Editor → New query
   và bấm **Run** với quyền quản trị SQL mặc định (`postgres`). Không chạy bằng
   publishable key từ app.
4. Kết quả trả về 8 dòng thống kê bãi. Đăng xuất/đăng nhập lại Admin và các app,
   hoặc tải lại dữ liệu khi đang có mạng. Không cần build lại APK.

Không chạy bất kỳ file nào trong `supabase/tests` trên Cloud.

## Dữ liệu tạo ra khi chạy lần đầu

| Thành phần | Số lượng / ý nghĩa |
|---|---|
| Bãi đỗ | 8 bãi mô phỏng tại khu vực Đà Nẵng, có tọa độ và giá riêng |
| Vị trí | 320 vị trí; 16 vị trí tạm ngừng sử dụng |
| Phương tiện | 24 xe: 12 ô tô và 12 xe máy, tên có nhãn `[DEMO]` |
| Lịch sử đã hoàn tất | 736 vé, gồm 720 vé trong 30 ngày trước và 16 vé gần đây |
| Xe đang trong bãi | 8 vé `parked`, có sự kiện check-in, có thể check-out |
| Vé sẵn sàng check-in | 8 vé `confirmed`, cửa sổ từ lúc nạp đến khoảng 3 giờ sau |
| Vé ngày mai | 8 vé `confirmed`, từ 09:00–11:00 theo giờ Việt Nam, có thể hủy |
| Vé đã hủy | 32 vé, không tạo khoản thu |
| Tổng vé | 792 vé với QR ngẫu nhiên do database cấp |
| Khoản thu | 736 giao dịch tiền mặt mô phỏng; phí đúng công thức RPC, có vé miễn phí |
| Nhật ký | 1.480 sự kiện check-in/out |
| Thông báo | 792 thông báo theo trạng thái vé |
| Yêu thích | 3 bãi / tài khoản khách được cấu hình |

Bãi và giá là giả lập phục vụ đồ án, không đại diện dịch vụ hay mức giá có thật.
Các vé dùng thời gian tính từ **lần chạy đầu tiên**. Sau vài giờ, vé check-in có
thể hết hạn; bạn tạo vé mới trong ứng dụng để tiếp tục thử. Chạy lại script không
đổi thời gian các vé cũ, không khôi phục vé đã dùng và không làm mới QR.

## Dữ liệu của ba tài khoản

Cấu hình hiện tại tách đúng ba tài khoản đã cung cấp:

- **Admin Web**: `manhcuongnguyen2205@gmail.com` giữ quyền `owner`, sở hữu 8 bãi,
  xem lịch sử xe, khoản thu và quản lý nhân viên; không sở hữu xe/vé cá nhân của khách.
- **Customer APK**: `dadinhviruscorona@gmail.com` giữ quyền `customer`, sở hữu
  24 phương tiện, 792 vé, thông báo và 3 bãi yêu thích.
- **Staff APK**: `cuongnm.23it@vku.udn.vn` được chuyển từ `customer` thành `staff`,
  phân công vào 8 bãi mẫu, thao tác check-in/out; không có quyền quản trị bãi/doanh thu.

Các khách khác đăng nhập chỉ thấy bãi; vé, xe và thông báo mẫu không được chia sẻ
công khai. Nếu tài khoản khách hiện đã có quyền owner/staff, script không tự hạ
quyền tài khoản đó; dùng tài khoản khách đã đăng ký bình thường để thử tách vai trò.

Muốn thay bằng các tài khoản khác, đăng ký/xác nhận các email đó trước, rồi sửa
ba dòng ở đầu script **trước khi nạp bộ dữ liệu**:

```sql
owner_email text := 'EMAIL_CHU_BAI';
customer_emails text[] := array['EMAIL_KHACH_1', 'EMAIL_KHACH_2'];
staff_emails text[] := array['EMAIL_NHAN_VIEN_1', 'EMAIL_NHAN_VIEN_2'];
```

Không điền cùng một tài khoản khách và nhân viên nếu muốn kiểm thử ba vai trò
riêng. Script chỉ gán role `staff` cho email nhân viên không nằm trong danh sách
khách và không hạ quyền owner. Xe được chia đều cho các email khách đã cung cấp.

## Chạy lại và an toàn dữ liệu

- Script chạy trong một transaction; lỗi sẽ hủy toàn bộ thay đổi của lần chạy.
- ID mẫu xác định theo owner và bộ seed, không chèn thêm bản sao khi chạy lại.
- Không xóa dữ liệu, không ghi đè giá, trạng thái vé, khoản thu, thông báo đã đọc
  hay phân công đã chỉnh trong app; không vô hiệu hóa RLS hay constraint.
- Không tạo/sửa mật khẩu hoặc tự xác nhận email trong `auth.users`.
- Chạy lại với email khách/nhân viên khác **không chuyển quyền sở hữu xe/vé đã
  tạo**. Giữ nguyên cấu hình cho bộ seed đã nạp; phân công nhân viên mới qua Admin,
  khách mới tự thêm xe/đặt vé trong app.
- Nếu không nhận ra email hoặc email chưa xác nhận, script báo rõ và không nạp
  một phần. Nếu trùng biển số thật của tài khoản, không xóa xe thật để chạy seed;
  đổi biển số mẫu trong script trước lần nạp đầu.

## Kiểm thử script trên máy phát triển

```powershell
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin --demo-seed
```

Chỉ dùng database tạm cục bộ. Kiểm tra số lượng, phí, quan hệ, RLS, QR check-in/out,
chạy lại sau khi sửa dữ liệu và cả hai cấu hình một tài khoản / ba tài khoản.
Đây không phải lệnh kết nối PostgreSQL riêng cho backend ứng dụng.
