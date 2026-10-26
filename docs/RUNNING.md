# Chạy cả ba giao diện SmartPark trên Windows

Nhấp đúp **Run-SmartPark.cmd** trong thư mục gốc dự án. Chỉ cần một cửa sổ điều khiển; Customer, Staff và Admin sẽ được chạy, sau đó mở bằng trình duyệt mặc định.

| Giao diện | Địa chỉ cố định |
|---|---|
| Customer | http://127.0.0.1:8081 |
| Staff | http://127.0.0.1:8082 |
| Admin | http://127.0.0.1:5173 |

Giữ cửa sổ này mở trong lúc kiểm tra. Nhấn **Ctrl+C** tại cửa sổ đó để dừng cả ba server. Đóng tab trình duyệt không tự dừng server.

`127.0.0.1` là địa chỉ máy hiện tại, tương đương mục đích dùng `localhost`. Bạn có thể mở các link bằng tay hoặc mở lại tab bất cứ lúc nào khi server đang chạy. Script chỉ mở trình duyệt sau khi cả hai bản Flutter đã biên dịch xong và cả ba server sẵn sàng.

## Chỉ chạy server, không tự mở trình duyệt

Mở PowerShell trong thư mục dự án:

```powershell
.\Run-SmartPark.cmd --no-open
```

Sau đó tự truy cập các link ở bảng trên. Nếu chạy từ thư mục khác, chuyển vào thư mục dự án trước:

```powershell
cd D:\LapTrinhDaNenTang\SmartPark
.\Run-SmartPark.cmd
```

## Kiểm tra môi trường mà không chạy ứng dụng

```powershell
.\Run-SmartPark.cmd --check
```

Launcher cần Flutter, Node.js và npm trong PATH. Các công cụ này đã có trên máy đang dùng. Script sẽ lấy package Flutter hoặc cài dependency Admin nếu thiếu hoặc cần cập nhật theo file cấu hình.

Lần đầu có thể cần chờ một vài phút để Flutter biên dịch. Hai entrypoint Flutter khởi động lần lượt để tránh ghi đồng thời vào thư mục build dùng chung trên Windows. Khi sửa mã Flutter, dừng và chạy lại launcher; Admin Vite tự cập nhật khi sửa mã React.

Nếu cổng đã có chương trình khác sử dụng, launcher báo cổng bị chiếm và không dừng chương trình đó. Hãy dừng phiên SmartPark cũ trước khi chạy phiên mới. Log chẩn đoán nằm trong `.smartpark/logs/`.

Các giao diện vẫn dùng mock riêng, chưa đồng bộ qua backend.

## Kiểm tra đã thực hiện

- Kiểm tra Node syntax và chế độ `--check`.
- Chạy đồng thời cả ba server bằng `--no-open`, với hai lượt biên dịch Flutter được tuần tự hóa.
- Đợi thông báo Flutter thực sự sẵn sàng thay vì chỉ kiểm tra cổng HTTP đã mở.
- Nhận HTTP 200 và mở cả ba địa chỉ bằng Chrome headless; đối chiếu ảnh Customer Splash, Staff Login và Admin Overview.
- Xác nhận các cổng 8081, 8082 và 5173 không còn lắng nghe sau khi dừng phiên kiểm tra.
