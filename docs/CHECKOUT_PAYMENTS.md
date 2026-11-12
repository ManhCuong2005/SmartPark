# Thu tiền khi xe ra

Ngày 12/11/2026, người dùng chọn thu từ phút đầu, tối thiểu một giờ theo đơn giá
đã lưu trên vé. Giờ lẻ tiếp theo làm tròn lên. Ví dụ đơn giá 12.000đ: 45 giây
thu 12.000đ, 60 phút thu 12.000đ, 61 phút thu 24.000đ. Biểu giá 0đ vẫn là 0đ.

Migration `202611120007_paid_checkout.sql` đã áp dụng trên Cloud sau 006.
Máy chủ dùng cùng công thức cho mọi check-out mới, kể cả vé đang hoạt động đã
lưu số phút miễn phí theo quy tắc cũ. Cấu hình giá mới luôn lưu phút miễn phí=0.
Không sửa tiền trên vé đã kết thúc, khoản thu hoặc doanh thu lịch sử.

Staff hiển thị tiền cần thu, đơn giá và hộp xác nhận có số tiền cụ thể. Thời điểm
tính tiền ở hộp xác nhận được gửi làm thời điểm check-out để không lệch một giờ
khi người dùng chờ xác nhận qua mốc làm tròn. Máy chủ vẫn kiểm tra quyền, QR,
biển số, version và thời gian thiết bị. Thu tiền và tạo payment trong cùng giao
dịch, giữ receipt để không tạo hai khoản thu khi retry.

Offline hiển thị khoản thu chờ đồng bộ; chưa cộng vào doanh thu máy chủ. Admin
tổng hợp từ payment đã ghi, theo ngày thu tiền, không cộng vé mới đặt hoặc khoản
tạm tính đang đỗ. Không sửa các giao dịch 0đ trước đây thành doanh thu giả.

Sau khi xác nhận xe vào/ra thành công (hoặc đã lưu thao tác offline), Staff quay
về màn `/staff/scan` đang có trong navigation stack; scanner được tiếp tục qua
luồng resume hiện có. Nếu mở vé từ danh sách thay vì scanner, tạo màn quét sau
khi hoàn tất. Xóa QR vừa dùng để thao tác mới phải quét lại. Hủy hoặc thất bại
giữ nguyên màn xác nhận. Test `staff_scan_flow_test.dart` kiểm tra vào, ra,
hủy và sai biển số, gồm tái sử dụng đúng scanner và mở lại nhận QR tiếp theo.

Kiểm thử: 150 Flutter tests, 39 Playwright tests, TypeScript kiểm tra kiểu và bộ
PostgreSQL migration/RPC/concurrency/demo đều qua. `paid_checkout.sql` kiểm tra
lượt 45 giây có phí, check-out idempotent và snapshot chủ bãi có đúng khoản thu.
`checkout_payment_test.dart` kiểm tra số tiền trong hộp xác nhận, hủy không thu,
offline giữ tiền chờ đồng bộ. Xác minh Cloud chỉ gọi hàm tính phí, không tạo vé
hoặc khoản thu thử. Lượt sửa này không push/pull, không build APK hay phát hành.
