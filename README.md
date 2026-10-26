# SmartPark

Flutter/Dart implementation from the SmartPark Figma file `oJJUHIXnHwSQpH3hjtFMXI`.
Customer: 17 Flutter design frames. Staff: 5 Flutter design frames. Admin Web: 6 React/TypeScript design frames in [admin-web](admin-web/README.md).

## Chạy nhanh cả ba giao diện

Nhấp đúp **Run-SmartPark.cmd** ở thư mục gốc. File tự chạy Customer, Staff và Admin, rồi mở trình duyệt. Giữ cửa sổ điều khiển mở; nhấn **Ctrl+C** để dừng cả ba.

- Customer: http://127.0.0.1:8081
- Staff: http://127.0.0.1:8082
- Admin: http://127.0.0.1:5173

Chỉ chạy server và tự mở link: `Run-SmartPark.cmd --no-open`. [Hướng dẫn chi tiết](docs/RUNNING.md).

## Run

```powershell
flutter pub get
flutter run -d chrome -t lib/main.dart
flutter run -d chrome -t lib/main_staff.dart
```

For a connected Android device, replace `chrome` with the device ID from `flutter devices`.
Both applications share theme, widgets and feature modules, with separate entrypoints. These are two app modes in one Flutter project, not Android product flavors or distinct store application IDs yet.

## Structure

```text
lib/
  app/                 App composition and named routes
  core/
    theme/             Inter, colors and form styling
    data/              In-memory mock repository and models
  shared/widgets/      Cards, buttons, page shell, navigation, SVG assets
  features/
    auth/              Splash, onboarding, customer/staff login, registration
    parking/           Home, offline map, list, detail
    booking/           Slots, time, confirmation, payment demonstration
    tickets/           QR illustration and history
    account/           Vehicles, profile, notifications, supplementary forms
    staff/             Shift home, scanner demo, confirmation, slot status
assets/
  figma/               176 original SVG exports downloaded via Figma MCP
  fonts/               Bundled Inter font with OFL license
```

## Design references and review

- [Frame inventory and implementation notes](docs/DESIGN.md)
- [Interactive visual comparison](docs/visual_review.html): open locally in a browser.
- `docs/figma/reference_*.png`: 22 Figma reference screenshots.
- `test/goldens/*.png`: 22 Flutter renders at 390 × 844.
- `docs/figma/*.txt`: high fidelity design context captured from Figma MCP.

Layouts use native Flutter Row/Column/GridView, scroll for short displays, SafeArea, and a maximum mobile content width of 480. Decorative maps and illustrations use positioned geometry where the design requires it. The operating system supplies the real status bar; no fake clock is rendered in the app.

## Mock boundaries

No Firebase, real authentication, payment gateway, camera permission, GPS service, QR validation or gate integration is configured. All state is in memory and resets on restart. Any valid email and password of at least 8 characters opens the demo; this is not secure authentication.

Booking selections, dates, times, prices and payment choice flow through the mock repository. Payment requires a clearly labeled simulation confirmation and never charges money. The QR is the exact geometric illustration from Figma and does not encode a usable ticket. Staff manual entry accepts `SP-1022-007` only as a demonstration. Check-in/out and occupancy changes are local simulations. History and offers are sample data.

Supplementary profile editing, help and staff account views make navigation usable; these three views are not additional Figma screens. The first three parking lots are the mock dataset, so the result count reflects three results rather than the design's illustrative twelve.

## Verify and build

```powershell
flutter analyze
flutter test
flutter build web --release -t lib/main.dart --output build/customer_web
flutter build web --release -t lib/main_staff.dart --output build/staff_web
flutter build apk --debug -t lib/main.dart
```

The screenshot regression baselines were generated from Flutter and manually reviewed against Figma. Golden tests detect subsequent changes; they are not a pixel-equality assertion against Figma. Fonts, native form controls, system status bars and adaptive spacing can differ between platforms. Widget tests cover all 22 screens at 320, 390 and 480 logical pixels, plus booking/payment and staff validation flows.

Both Android debug APKs and both Web entrypoints build successfully. APKs are in `build/apk/customer-debug.apk` and `build/apk/staff-debug.apk`; Web outputs are in `build/customer_web` and `build/staff_web`. Android doctor still reports missing command-line tools and unknown license status. iOS builds require macOS and Xcode and have not been verified.

## Admin Web

```powershell
cd D:\LapTrinhDaNenTang\SmartPark\admin-web
npm.cmd run dev
```

Open http://127.0.0.1:5173. See [Admin setup and mock boundaries](admin-web/README.md) and [Figma comparison](admin-web/docs/visual-review.html).
