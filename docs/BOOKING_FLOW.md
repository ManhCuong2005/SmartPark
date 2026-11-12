# Đặt chỗ và xử lý khách đến trễ

## Quy tắc đã thống nhất ngày 12/11/2026

- Khách chọn ngày/giờ và phương tiện, bấm **Tìm chỗ trống**, chọn ô rồi xác nhận.
  Các nút +1h/+2h/+4h/+8h đặt thời lượng tính từ giờ vào; tự chuyển ngày khi qua đêm.
- Xe đang đỗ hôm nay chỉ chặn lịch tương lai nếu khoảng đỗ dự kiến giao nhau.
  Xe chưa ra dù quá giờ vẫn chặn đặt ngay và check-in vào cùng ô.
- Theo lựa chọn mới tại migration 008, vé chưa dùng hết hiệu lực ngay tại giờ ra
  dự kiến và bị xóa khỏi DB ở lượt cron/request cleanup kế tiếp. Không giữ thêm
  1 tiếng. Ví dụ 14h–16h: từ 16h không thể check-in, khách cần đặt vé mới.
- Vé của xe đã check-in không tự xóa. Khách có thể gia hạn +1/+2/+4 giờ nếu ô và
  xe không trùng lịch khác. Nhắc trước 10 phút để gia hạn hoặc ra đúng giờ; xem
  [xóa vé và gia hạn](EXPIRY_AND_EXTENSIONS.md).
- Tính phí từ check-in thực tế đến check-out theo đơn giá trên vé. Theo lựa chọn
  mới ngày 12/11/2026, thu từ phút đầu, tối thiểu 1 giờ, không áp dụng phút miễn
  phí cho check-out mới; xem [quy tắc thu tiền](CHECKOUT_PAYMENTS.md).
  Nhận sớm tối đa 15 phút, đồng thời kiểm tra khoảng nhận sớm không trùng lịch.
- Offline hiển thị lịch đã dời với nhãn chờ máy chủ. Không phục hồi vé đã tự hủy;
  nếu cron xử lý trước khi lệnh offline được đồng bộ, nhân viên phải kiểm tra lại
  xung đột. Thời gian thiết bị vẫn chịu giới hạn kiểm tra cũ của máy chủ.

## Áp dụng

Chạy một lần `supabase/migrations/202611120005_booking_flow.sql` sau migration
004, trước khi phát hành app chứa luồng mới. Không chạy lại migration cũ.
Migration mới không cài extension, không xóa dữ liệu và không thay đổi bảng giá.
Các vé đã `expired` từ quy tắc cũ được giữ nguyên, không tự phục hồi.

Lịch `smartpark-booking-deadlines` hiện có tiếp tục gọi cùng hàm và tự dùng quy
tắc mới. Nếu chưa cài lịch, chạy `supabase/setup-reminder-scheduler.sql` một lần.
Cron chạy mỗi phút nên trạng thái được ghi ở lượt chạy kế tiếp sau hạn nhận;
availability bỏ vé đã quá hạn ngay theo giờ máy chủ. Khi đặt chỗ, máy chủ cũng
dọn vé bỏ hẹn trên ô đó, kể cả vé khách khác, trước khi kiểm tra ràng buộc.

Các lệnh đặt chỗ/check-in/out/hủy khóa theo xe rồi ô đỗ; cron dùng khóa ô trước
khóa vé và bỏ qua hàng đang bận. Giữ nguyên receipt idempotency, version, kiểm
tra quyền theo bãi, QR, biển số, ràng buộc overlap và một khoản thu mỗi vé.

## Kiểm chứng

### Xung đột xe và ô đỗ (migration 006)

Chạy `202611120006_booking_availability.sql` sau 005. RPC
`booking_availability(p_lot_id,p_start,p_end,p_vehicle_id)` nhận cùng giờ UTC và
cùng xe mà lệnh đặt chỗ sẽ gửi, trả về `{slots, vehicle_conflict}`. `slots` chỉ
thể hiện lịch của bãi; `vehicle_conflict` mô tả vé của chính xe đang chọn, kể cả
ở bãi khác. Phản hồi không chứa QR hoặc thông tin vé của khách khác. RPC cũ
`slot_availability` vẫn giữ nguyên để không ảnh hưởng các client khác.

Giao diện hiển thị rõ bãi/ô/giờ của vé đang trùng và cho mở vé đó. Đổi xe làm mất
hiệu lực kết quả cũ; chỉ nhận phản hồi khớp bãi, xe, giờ và tài khoản hiện tại.
Trước khi chuyển bước hoặc gửi đặt chỗ, kiểm tra lại khả dụng. Nếu có người đặt
trong khoảng giữa kiểm tra và ghi, máy chủ phân biệt `VEHICLE_TIME_CONFLICT`
với `SLOT_TIME_CONFLICT`, giao diện tải lại rồi quay về bước tương ứng.

Lỗi `23P01` chung không còn bị diễn giải chắc chắn là người khác đã đặt ô.
Lần gửi mất phản hồi giữ nguyên ID và replay receipt trước khi kiểm tra lịch,
tránh tự xung đột với vé đã tạo thành công. Không có RPC mới thì báo cần cập
nhật máy chủ, không dùng dữ liệu cũ để tô ô xanh.

`test/booking_conflict_test.dart`, các HTTP contract test trong
`test/data_integration_test.dart` và `supabase/tests/booking_availability.sql`
kiểm tra xung đột chéo bãi, quyền xem thông tin, chính sách 005/006, preflight, race
và mất ACK. HTTP simulator hiện có chạy SDK Supabase thật trên localhost;
không tạo thêm workspace hoặc phụ thuộc Postman CLI để chạy bộ test dự án.

### Đặt chỗ và nhận xe

Nút Tiếp tục ở bước chọn ô giữ nguyên `AsyncParkButton` khi RPC đang chạy;
chỉ đổi thuộc tính `enabled`, không thay bằng một widget khác. Việc thay widget
giữa request làm dispose nút cũ và bỏ qua callback chuyển màn hình khi phản hồi
trễ. Các test có gate chờ trong `booking_conflict_test.dart` kiểm tra chuyển
từng bước qua độ trễ, chỉ gửi tạo vé ở xác nhận cuối, báo rõ lỗi mạng/trùng xe/ô
và phục hồi sau khi thử lại. Bước chọn ô không ghi vé vào DB.

`test/reservation_flow_test.dart`: qua đêm, chọn nhanh, luồng màn hình, dữ liệu
chỗ trống rỗng/lỗi/phản hồi ngược thứ tự, dời lịch offline và phản hồi rung OCR.
`test/domain_test.dart` đã có nhận diện biển xe máy hai dòng bằng chuẩn hóa kết
quả OCR; không thay mô hình ML Kit hay suy ra độ chính xác camera từ regex.

`supabase/tests/booking_flow.sql`: SQL/RPC thật trên PostgreSQL tạm cho đặt ngày
sau, xe quá giờ vẫn chiếm ô, hạn nhận 59/60 phút, tự hủy và thông báo một lần,
cleanup chéo khách, check-in trễ idempotent, phí thực tế và rollback khi trùng
lịch tiếp theo. Bộ `tools/test_backend.mjs` cũng chạy lại các kiểm thử cũ và hai
phiên tranh cùng một ô. Không chạy fixture test trên Supabase Cloud.

Kiểm tra QR/camera/rung trên điện thoại thật và Cron trên Cloud sau triển khai;
test widget chứng minh gọi kênh haptic, không chứng minh phần cứng thực sự rung.
