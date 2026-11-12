# Bản đồ khách hàng

## Nguồn ảnh và dữ liệu bãi

- `flutter_map` 8.3.2 dựng bản đồ raster, không thêm SDK Google Maps hoặc API key.
- Ảnh nền mặc định: `https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png`.
- Dữ liệu bản đồ: OpenStreetMap; kiểu bản đồ: HOT; dịch vụ tile: OSM France.
  Attribution và liên kết nguồn luôn nằm ở góc dưới bản đồ.
- Tên bãi, giá, chỗ trống và tọa độ vẫn lấy từ Supabase/cache theo quyền tài khoản,
  không lấy từ danh sách mock. Bãi thiếu tọa độ không có marker, nhưng nền bản đồ
  vẫn hiển thị. Dữ liệu đến sau lần dựng đầu được đưa vào khung nhìn một lần.
- Bản đồ nền được mở trước đăng nhập bằng nút **Xem bản đồ** trong màn hình đăng
  nhập khách. Dữ liệu bãi từ API và thao tác đặt vé vẫn theo Auth/RLS hiện có.

Nguồn cũ `tile.openstreetmap.org` không kết nối được trong kiểm tra tại máy này.
Nguồn OSM France trả ảnh PNG 200 và CORS `*`; việc này giải quyết trường hợp có
marker nhưng toàn bộ nền xám trên cả Web và Android. Không suy ra nguyên nhân
DNS/tường lửa chính xác trên điện thoại từ phép kiểm tra ở máy phát triển.

Điều kiện dịch vụ: <https://www.openstreetmap.fr/usage/>. Nguồn cộng đồng dùng
cho ứng dụng miễn phí, phi lợi nhuận, truy cập công khai và lưu lượng vừa phải,
phù hợp đồ án hiện tại; không có SLA. Khi chuyển sang kinh doanh hoặc tăng tải,
dùng nhà cung cấp có gói phù hợp. Không mặc định dùng dịch vụ yêu cầu key mà
không cấu hình key (ví dụ CARTO hiện yêu cầu key cho raster).

## Giảm tải

- Giữ nguyên TileLayer/provider khi chọn bãi hoặc nhận snapshot Realtime; chỉ
  cập nhật marker/thẻ bãi, không tái tạo HTTP client.
- Tile chỉ tải trong khung nhìn (`panBuffer=0`), giữ đệm một hàng, tắt retina
  nhân bốn request, giới hạn zoom 3–18 và giới hạn cập nhật tile mỗi 100ms.
- Hủy request tile không còn dùng bằng chức năng của NetworkTileProvider;
  dựng tile ngay khi có ảnh, không tạo animation fade cho từng ảnh.
- Dùng cache tích hợp theo HTTP headers. Native đặt ngân sách cache 64 MiB thay
  cho mặc định 1 GB; đây là giới hạn mềm, cache được dọn ở lần khởi tạo sau và
  có thể vượt ngân sách trong phiên đang chạy. Web sử dụng cache trình duyệt.
- RepaintBoundary cô lập bản đồ. Chỉ lấy một lần GPS khi bấm **Vị trí của tôi**,
  độ chính xác vừa phải và thời hạn 12 giây, không theo dõi nền/liên tục.
- Có trạng thái tải, lỗi, thử lại và thông báo từ chối GPS. Mất mạng vẫn có thể
  xem danh sách bãi đã lưu; không hứa cung cấp bản đồ offline đầy đủ.
- Không tải trước cả thành phố/vùng hoặc bỏ attribution.

Không cam kết 60fps trên mọi thiết bị; cần đo frame times trong profile mode
trên điện thoại mục tiêu. Cache và throttling giúp giảm chi phí nhưng không
thay thế việc đo thực tế hoặc đảm bảo tốc độ Internet.

## Đổi dịch vụ tile

Biến build public, không chứa khóa quản trị Supabase:

```text
MAP_TILE_URL=https://YOUR_PROVIDER/{z}/{x}/{y}.png
MAP_ATTRIBUTION=YOUR_PROVIDER attribution
MAP_ATTRIBUTION_URL=https://YOUR_PROVIDER/attribution
```

Truyền qua `--dart-define` / file JSON build và cập nhật attribution theo nhà
cung cấp. Nếu có key client công khai, hạn chế key theo khả năng nhà cung cấp;
không dùng secret backend. Nguồn tile phải dùng HTTPS, hỗ trợ CORS cho Web và
cho phép use case của ứng dụng. Không thay URL ở database/migrations.

## Kiểm chứng

- `test/map_test.dart`: 12 test cho tải lỗi/thử lại, timeout và phục hồi, dữ liệu
  bãi đến muộn, không tải lại nền khi chọn marker, tọa độ sai/thiếu, từ chối GPS,
  GPS một lần, giao diện 320/390/480px, sáng/tối và truy cập nền không đăng nhập.
- Toàn bộ Flutter suite hiện tại: 98 test đạt (12 test bản đồ); analyzer sạch.
- Web release đã build và kiểm tra Chrome với tile trực tiếp. Dữ liệu bãi Cloud
  không bị thay đổi bởi kiểm tra này. Ảnh/lưu vết cục bộ ở `.smartpark/map-check`.
- Android: kiểm tra build/ký release; chưa kiểm tra GPS và tốc độ render trên
  điện thoại thật. Không suy ra độ mượt native từ kết quả Chrome/headless.
