# Quét tự động tại cổng

Admin đăng nhập máy quét, chọn bãi của mình từ CSDL, chọn **Cam vào** hoặc
**Cam ra**, rồi camera tự chạy. Bãi và chiều được lưu theo tài khoản;
Web lưu riêng trong từng tab để mở đồng thời hai chiều và tải lại không đổi nhầm làn.
Nếu có nhiều webcam, chọn đúng thiết bị ở danh sách phía trên hình; lựa chọn
thiết bị được lưu riêng theo bãi/chiều. Lần đầu có nhiều camera, app chờ chọn
thiết bị trước khi đọc ảnh, không tự đoán camera nào nhìn làn vào hay làn ra.
Nếu camera đã lưu bị tháo, app yêu cầu chọn lại. Không có bước nhập biển số hoặc
xác nhận thủ công trong luồng kiosk. Quyền camera và âm thanh của hệ điều hành/
trình duyệt vẫn cần được cấp. `Đổi bãi / cam` chỉ khả dụng khi không có lượt đang xử lý.

## Cập nhật backend

Sau khi các migration 001–012 đã được áp dụng, chạy **một lần**
`supabase/migrations/202611160013_automatic_scanning.sql` trong SQL Editor.
Sau đó chạy `supabase/migrations/202611160014_extension_payment_choices.sql`
để thêm lựa chọn thanh toán gia hạn và áp dụng điều kiện trả sau **trên 100.000đ**.
Nếu đã chạy 013 thì chỉ chạy thêm 014, không chạy lại 013.
Sau 014, áp dụng 015 để gỡ vai trò/phân công nhân viên và thêm giao diện cộng/trừ
ví của admin; xem `docs/ADMIN_WALLET.md`.
Sau 015, chạy `supabase/migrations/202611160016_directional_kiosk.sql` để tách quyền
cam vào/ra. Không chạy lại migration đã thành công. Bản quét tự suy luận chiều cũ
không còn được backend chấp nhận; tải lại bản Camera mới sau khi cập nhật.
Migration giữ nguyên vé và giao dịch hiện có; thêm `paid_until` để phân biệt
giờ đã trả tiền với giờ đã gia hạn. Không chạy các file `supabase/tests` lên Cloud.

Máy quét dùng RPC hiện có `apply_operation`. Trước tiên mở phiên bằng `kiosk.open`,
`p_operation_id` là UUID phiên cố định, payload gồm `lot_id` và `direction` (`entry`/`exit`).
Backend ràng buộc UUID với admin, bãi và chiều; không thể đổi chiều của UUID đã mở.
Sau đó quét bằng:

```json
{
  "p_operation_id": "UUID cố định cho một lượt, dùng lại khi timeout",
  "p_kind": "kiosk.scan",
  "p_payload": {"session_id": "UUID phiên", "direction": "entry", "lot_id": "UUID bãi", "plate": "43A12345"}
}
```

Kết quả là `{ "action": "entered|exited|duplicate", "booking": { ... } }`.
`entered`/`exited` phát một tiếng ting sau khi máy chủ xác nhận. `duplicate`
không phát lại. Tất cả yêu cầu phải đăng nhập và có quyền vận hành bãi.

- **Cam vào:** vé `confirmed` chỉ vào khi `starts_at <= giờ máy chủ < ends_at`, đúng biển và bãi.
  Xe `parked` chỉ trả `duplicate`, kể cả đứng trước cam quá 30 giây; không thanh toán/cho ra.
- **Cam ra:** chỉ xử lý vé `parked`; xe chưa vào bãi bị từ chối, không tự nhận xe vào.
  Backend tính phí, kiểm tra số dư, ghi giao dịch,
  cập nhật vé và lưu biên nhận trong cùng transaction. Không dựa vào giờ thiết bị.
- Số dư thiếu: giữ vé `parked`, không trừ một phần, không báo xe ra thành công.
- Sai vé/bãi/giờ: đọc “Xe chưa đăng ký đỗ online hoặc quét nhầm, vui lòng thử lại”.
- Quá giờ và thiếu tiền: đọc “Bạn đã gửi quá giờ, và số dư không đủ, vui lòng nạp thêm tiền”.
- Sau khi giọng nói hoàn tất, chờ đủ 5 giây mới tiếp tục OCR và đối chiếu.
- Thông báo là các file MP3 tiếng Việt đóng gói trong `assets/audio`, không dùng
  giọng mặc định của trình duyệt. Lỗi loa vẫn hiện thông báo và cho phép thử lại,
  không khóa camera hoặc gửi lại một lượt đã thành công.
- Mỗi lượt ổn định gọi `kiosk.scan` trên máy chủ, không lọc bằng danh sách booking
  cũ trong trang. Sau từ chối, lần thử mới dùng UUID mới để thấy booking vừa tạo;
  chỉ khi chưa biết kết quả mạng mới giữ UUID cũ để chống thu tiền trùng.
- Lượt chưa biết kết quả do mất kết nối được lưu trước khi gửi; khi thử lại hoặc
  khởi động lại, dùng cùng UUID, không chuyển một lần vào thành một lần ra.

Camera chặn biển vừa xử lý cho đến khi vắng khỏi vùng quét ít nhất 2 giây và đã
qua tối thiểu 30 giây từ lần xử lý. Backend chống lặp theo chiều: cam vào không bao giờ
thành cam ra; cam ra không bao giờ thành cam vào. Xe có thể ra ngay sau khi vào
nếu được cam ra ghi nhận và đủ tiền. Không công khai lệnh check-in/out thủ công cũ
để vượt kiểm tra phiên. Đây là bảo vệ phần mềm, không phải cảm biến xác nhận
xe đã đi qua. Tích hợp cảm biến và mở cổng nằm ngoài thay đổi này.

## Thanh toán và gia hạn

- `booking.pay`: giữ luồng trả trước bằng ví hoặc QR payOS đang có.
- `booking.reserve`: trả sau, yêu cầu **số dư khả dụng lớn hơn 100.000đ tại lúc đặt**.
  Không thu hoặc khóa 100.000đ; đây không phải tiền cọc cho mỗi vé. Backend kiểm
  tra lại ngưỡng, không chỉ giao diện. Vé trả sau vẫn phải đủ tiền khi xe ra.
- Khi gia hạn, khách chọn trả ngay bằng ví/QR hoặc thu khi xe ra.
- `booking.extend.deferred`: yêu cầu số dư **lớn hơn 100.000đ**, chỉ cập nhật giờ ra
  nếu còn sức chứa và không trùng lịch xe; không trừ tiền ngay. Không đổi `paid_until`.
  Đúng 100.000đ chưa đủ điều kiện. Máy chủ kiểm tra cả lúc đặt và lúc gia hạn trả sau.
- `booking.extend.pay`: trả ngay toàn bộ phần còn thiếu đến giờ ra mới. Vé trả
  trước tính từ `paid_until`, gồm cả gia hạn đã chọn trả sau trước đó; vé trả sau
  tính từ lúc xe vào. Sau thanh toán, `paid_until` được cập nhật đến giờ ra mới,
  không thu lại phần này khi xe ra. Trả ngay không yêu cầu giữ số dư trên 100.000đ,
  chỉ cần đủ tiền thanh toán hoặc dùng QR.
- Vé trả sau tính theo thời gian từ lúc vào thực tế đến lúc ra thực tế.
- Vé trả trước không thu lại tiền gốc; chỉ thu thời gian sau `paid_until`.
- Tiếp tục dùng đơn giá chốt trên vé, làm tròn lên từng giờ, tối thiểu một giờ
  cho phần phải thu. Không thêm hệ số phạt quá giờ. Trả trước không hoàn phần
  thời gian không sử dụng khi lấy xe sớm.

Lịch nhắc hiện có được giữ lại: nhắc khi còn 10 phút và nhắc quá giờ, chống trùng
theo vé/giờ ra. Thông báo mở vào vé, khách có thể chọn gia hạn hoặc bỏ qua để ra
đúng giờ. Gia hạn tạo mốc nhắc mới. Để nhắc khi app đóng, Cloud cần scheduler và
Firebase/push đã cấu hình theo `docs/NOTIFICATIONS.md` và
`supabase/setup-reminder-scheduler.sql`; kiểm thử local không xác nhận cấu hình Cloud.

## Camera và giới hạn đã biết

- Android/iOS: camera stream, crop vùng giữa khung trước OCR ML Kit Latin;
  xử lý hướng ảnh và NV21/YUV/BGRA với row stride/pixel stride.
- Web: webcam qua `camera`, Tesseract.js 6.0.1 trong browser worker; ảnh không
  gửi lên dịch vụ OCR. Runtime/model tải từ CDN lúc khởi tạo, có thể được cache.
  Cần HTTPS hoặc localhost. Webcam trước được bỏ lật ngang cả preview và trước OCR.
  Nhịp lấy khung là 80 ms, chỉ một OCR chạy tại một thời điểm; ảnh crop giới hạn
  chiều rộng 960 px, phóng tối đa 2 lần. Giữ nguyên ba khung khớp trong năm khung,
  ngưỡng tin cậy và chọn biển gần để tăng tốc mà vẫn kiểm tra biển số nhiều lần.
  Tìm vùng sáng dạng biển trắng/vàng trong khung, crop sát vùng đó và thêm viền trắng
  trước OCR. Nếu chưa đọc được, thử nhị phân cục bộ rồi đọc chữ rời trong khung.
  Biển một/hai dòng đều đi qua bước ghép theo vị trí. Giao diện hiển thị số khung
  đã đọc và vẽ viền xanh quanh biển đang chọn, viền cam nếu có nhiều biển tương đương.
- Mục tiêu xử lý tối đa 4 khung/giây; bỏ khung khi đang bận. Cần 3 kết quả giống
  nhau trong 5 lần quan sát gần nhất, không chốt nếu khung hiện tại có nhiều ứng viên.
  Khoảng cách giữa hai lần đọc từ 8 giây trở lên sẽ xóa đồng thuận; không còn xóa
  ở mốc 2 giây khiến OCR chậm không bao giờ đủ ba khung.
- Bỏ khung quá tối/thiếu tương phản; lọc dòng nhỏ và độ tin cậy OCR thấp nếu có.
  Ghép biển hai dòng theo vị trí và khoảng cách; không đoán hàng loạt O/0, I/1,
  không ép biển thành một biển gần giống trong CSDL.
- Chỉ xét chữ nằm trọn trong khung, cao ít nhất 3,5% chiều cao ảnh, vùng chữ rộng
  ít nhất 12% chiều rộng ảnh. Nếu chiều cao chữ của biển lớn nhất gấp ít nhất 1,5 lần
  biển thứ hai, chọn biển lớn nhất. Hai biển tương đương thì chờ. Với biển hai dòng,
  so chiều cao ký tự từng dòng để tránh ưu tiên nhầm chỉ vì biển có hai dòng.
  Kích thước hiển thị ước lượng độ gần, cần hiệu chỉnh theo camera và loại biển.
- Chặn riêng từng biển vừa xử lý, kể cả khi xe khác xuất hiện xen kẽ. Biển đó chỉ
  được quét lại khi thỏa điều kiện vắng mặt/30 giây nêu trên. Giao diện giữ thông báo
  đã xử lý khi biển vẫn xuất hiện, không đổi lại thành đang kiểm tra.
- Đây là bản tìm vùng sáng + OCR + đồng thuận nhiều khung hình. Chưa có model chuyên
  phát hiện biển Việt Nam, nắn phối cảnh hoặc bộ đo độ nhòe đã hiệu chỉnh ngoài bãi.
  Ngưỡng ảnh phải được kiểm chứng trên camera lắp thật. Đồng thuận có thể lặp lại
  một lỗi OCR; không thể hứa độ chính xác hoặc thời gian 1–2 giây trước phép đo đó.

## Kiểm chứng

```powershell
flutter test
flutter analyze
node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin
node tools/test_browser_plate_ocr.mjs
flutter build web --no-pub -t test/support/browser_camera_probe.dart --output build/camera-probe
node tools/test_browser_camera.mjs
flutter build web --no-pub -t lib/main_kiosk.dart --output build/kiosk
```

Test PostgreSQL tạo database tạm local, không chạm Cloud. Bài kiểm tra browser
cần Playwright đã cài trong `admin-web`, Chrome và kết nối tải model; dùng ảnh
biển tự tạo một dòng/hai dòng/lật ngang, biển trắng/vàng, chữ nhỏ và chữ nhiễu
quanh biển. Cần đưa biển đủ lớn vào khung để qua ngưỡng chọn biển gần.
`test_browser_camera.mjs` chạy Flutter/camera_web/OCR thật với video tổng hợp,
backend giả chỉ trong target kiểm thử, xác minh ảnh đúng chiều, tự quét cả hai làn,
chọn thiết bị, từ chối biển xa/hai biển tương đương, chặn lặp và khôi phục đúng làn
trong hai tab. Bộ SQL riêng xác minh quyền và tiền.
Các bài này không thay thế benchmark ngoài thực tế hoặc thử với camera lắp thật.
