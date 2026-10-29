# SmartPark

Ứng dụng đặt chỗ và quản lý bãi đỗ xe tích hợp nhận diện biển số on-device.
Flutter cho khách/nhân viên; React + TypeScript cho chủ bãi. Supabase Cloud là
backend và CSDL online duy nhất. Drift/SQLite lưu cache và hàng đợi offline.

Source đã chuyển từ prototype sang repository thật; không tự tạo dữ liệu demo.
Các assets, màu sắc, shell và bố cục chính từ Figma được giữ lại; form/quét/vé và
biểu đồ được điều chỉnh để thể hiện dữ liệu, trạng thái và lỗi thật.

## Chuẩn bị backend

Xem [thiết lập Supabase và tài khoản](docs/SUPABASE_SETUP.md). Migration 001 đã được
chủ project xác nhận chạy thành công, cùng migration 002; cần đăng ký và cấp tài khoản owner.
Không chạy fixture trong `supabase/tests` lên Cloud.

## Chạy trên Windows

`Run-SmartPark.cmd` mở Customer Web, Staff Web và Admin; camera OCR ML Kit chỉ có
trên Android/iOS. Lần đầu launcher chuẩn bị SQLite WASM/worker cho Flutter Web.

```powershell
flutter pub get
dart run tools/prepare_web.dart
flutter run -d chrome -t lib/main.dart
flutter run -d chrome -t lib/main_staff.dart
```

Trên Android, hai flavor cài được cùng lúc:

```powershell
flutter run -d DEVICE_ID --flavor customer -t lib/main.dart
flutter run -d DEVICE_ID --flavor staff -t lib/main_staff.dart
```

Admin:

```powershell
cd admin-web
npm.cmd ci
npm.cmd run dev
```

## Tài liệu

- [Kiến trúc, đồng bộ và quy tắc nghiệp vụ](docs/ARCHITECTURE.md).
- [Kiểm thử tự động và checklist thiết bị](docs/TESTING.md).
- [Build/ký Android bằng Fastlane và GitHub Actions](docs/RELEASE_BUILD.md).
- [Trạng thái triển khai và giới hạn kiểm chứng](docs/IMPLEMENTATION_STATUS.md).

Chỉ cấu hình client public được đưa vào app. Không có secret/service_role key.
Chưa phát hành, upload GitHub Releases hay triển khai production.
