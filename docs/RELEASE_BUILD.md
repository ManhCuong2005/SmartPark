# Build và ký Android, chưa phát hành

Hai flavor có application ID riêng để có thể cài đồng thời:

- Customer: `vn.smartpark.smartpark.customer`, entrypoint `lib/main.dart`.
- SmartPark Camera: `vn.smartpark.smartpark.staff`, entrypoint `lib/main_kiosk.dart`.
  Giữ flavor/package `staff` để cập nhật app đã cài; không có vai trò nhân viên.

Android yêu cầu JDK 17+, SDK 36, NDK 27.0.12077973. Cấu hình đã nâng Gradle/AGP/Kotlin
để khớp các plugin hiện dùng. `kotlin.incremental=false` tránh lỗi cache khi Pub
cache trên C và source trên D. ML Kit và QR dùng model bundled để hoạt động offline.

## Kiểm thử cục bộ

```powershell
./tools/build_android.ps1 -Role customer -Mode debug
./tools/build_android.ps1 -Role staff -Mode debug
```

Script đặt cache Gradle/temp riêng trong `.smartpark` trên ổ của dự án, tránh đầy
ổ C. Không thay đổi SDK hay cache của các dự án khác. APK debug nằm tại
`build/app/outputs/flutter-apk/app-customer-debug.apk` và `app-staff-debug.apk`.
Đây là build kiểm thử cục bộ, không phải bản phát hành.

## Ký release khi bạn quyết định kiểm tra

1. Tự tạo và giữ keystore riêng; không commit hay gửi mật khẩu vào chat.
2. Sao chép `android/key.properties.example` thành `android/key.properties`, điền
   đường dẫn keystore và thông tin ký trên máy. Các file ký được gitignore.
3. Chạy `bundle install` trong `android`, sau đó
   `bundle exec fastlane android build_release`.

Fastlane tạo APK/AAB cho cả hai flavor vào `build/signed/customer` và
`build/signed/staff`. Lane không có lệnh upload, publish hoặc tạo GitHub Release.
Build release không có key.properties sẽ thất bại, không tự dùng debug key.
Phiên bản và versionCode lấy từ `pubspec.yaml`, không dùng số thứ tự GitHub run
thay thế versionCode. Bản hiện tại là `1.2.1+12002`.

## GitHub Actions

- `ci.yml`: analyze, Flutter tests, Web build, Admin build/Playwright và kiểm thử
  PostgreSQL cục bộ; chạy khi push lên main/master hoặc `release/booking-fix-v1.2.1`.
  Không deploy schema lên Cloud. Android SDK được chuẩn bị trước sdkmanager.
- `build-signed.yml`: chỉ chạy thủ công bằng workflow_dispatch. Cần Repository
  Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` do bạn tự cấu hình.
- Workflow ký chỉ lưu build bằng Actions artifacts trong 7 ngày, không tạo GitHub
  Release, không upload Play Store, không triển khai production. Quyền contents chỉ read.

Build trực tiếp sau khi có key.properties:

```powershell
flutter build apk --release --flavor customer -t lib/main.dart
flutter build apk --release --flavor staff -t lib/main_kiosk.dart
```

APK nằm trong `build/app/outputs/flutter-apk/`. Build lại cùng flavor/mode ghi đè
file APK mặc định cùng tên; không tự xóa APK/Release đã upload trên GitHub.
Sao lưu hoặc đổi tên bộ bàn giao trước khi build lại. Bản 12002 dùng tên
`smartpark-v1.2.1-build12002-customer.apk` và `smartpark-v1.2.1-build12002-camera.apk`
trong thư mục riêng `.smartpark/releases/v1.2.1-build12002/`, kèm SHA-256 và biên bản kiểm tra.
APK cũ được sao lưu tại `.smartpark/releases/v1.2.1/build-12001-backup-20261117/`.

Không thay tag/release `v1.2.1` chỉ bằng việc push nhánh; APK release cũ trên GitHub
vẫn giữ nguyên cho đến khi bạn chủ động upload/thay thế. Ghi chú bản mới:
[build 12002](RELEASE_NOTES_v1.2.1-build12002.md).

Camera hiện tại cần migration 015–016 sau 014; xem
[quét tự động](AUTOMATIC_SCANNING.md). Không chạy lại migration đã thành công.
Fastlane/AAB và workflow ký cần được xác minh riêng; build APK local không chứng minh
các pipeline đó đã qua. Kiểm tra camera/âm thanh trên thiết bị thật trước khi vận hành.
