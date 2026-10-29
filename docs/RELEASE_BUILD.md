# Build và ký Android, chưa phát hành

Hai flavor có application ID riêng để có thể cài đồng thời:

- Customer: `vn.smartpark.smartpark.customer`, entrypoint `lib/main.dart`.
- Staff: `vn.smartpark.smartpark.staff`, entrypoint `lib/main_staff.dart`.

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

## GitHub Actions

- `ci.yml`: analyze, Flutter tests, Web build, Admin build/Playwright và kiểm thử
  PostgreSQL cục bộ. Không deploy schema lên Cloud.
- `build-signed.yml`: chỉ chạy thủ công bằng workflow_dispatch. Cần Repository
  Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` do bạn tự cấu hình.
- Workflow ký chỉ lưu build bằng Actions artifacts trong 7 ngày, không tạo GitHub
  Release, không upload Play Store, không triển khai production. Quyền contents chỉ read.

Pipeline chưa chạy trên GitHub trong phiên này; chưa có keystore để xác minh chữ
ký release thật. Cấu hình Fastlane chưa được thực thi cục bộ vì máy chưa có Ruby.
Không coi APK debug đã build thành công là bằng chứng release đã được ký.
