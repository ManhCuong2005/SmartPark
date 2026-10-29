> Tài liệu lịch sử của bản prototype Figma. Trạng thái backend và kiểm thử hiện tại xem [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

# Figma analysis and implementation map

Source: https://www.figma.com/design/oJJUHIXnHwSQpH3hjtFMXI

Read through Figma MCP using session `d35b7597-d14e-47a5-9992-7f25e474858a`. Pages: Customer `9:2`, Staff `25:2`, Admin `25:3`. Admin was excluded from implementation.

## Foundations

- Design canvas: 390 × 844 logical pixels.
- Inter, regular/medium/semibold/bold.
- Navy `#10233E`, primary blue `#315FEA`, teal `#17B29A`.
- Text `#13243B`, secondary `#738197`, surface `#F5F7FB`, border `#E8EDF4`.
- Typical horizontal margins 22–24, cards 18–22 radius, controls 13–16 radius, primary buttons 54–56 high.
- Shared elements: four-item bottom navigation, input fields, parking cards, slot grid, booking summary rows, primary and secondary buttons.

## Frame inventory

| Group | Node | Frame | Route |
|---|---|---|---|
| Auth | 13:3 | Splash | `/` |
| Auth | 13:25 | Khám phá SmartPark | `/onboarding` |
| Auth | 13:61 | Đăng nhập | `/login` |
| Auth | 13:96 | Đăng ký | `/register` |
| Parking | 13:139 | Trang chủ | `/home` |
| Parking | 13:236 | Bản đồ bãi đỗ | `/parking/map` |
| Parking | 13:333 | Danh sách bãi đỗ | `/parking/list` |
| Parking | 13:429 | Chi tiết bãi đỗ | `/parking/detail` |
| Booking | 16:7 | Chọn vị trí đỗ | `/booking/slots` |
| Booking | 16:73 | Chọn thời gian | `/booking/time` |
| Booking | 16:134 | Xác nhận đặt chỗ | `/booking/confirm` |
| Booking | 16:176 | Thanh toán | `/booking/payment` |
| Booking | 16:228 | Vé QR đặt chỗ | `/tickets/qr` |
| Account | 16:390 | Lịch sử đặt chỗ | `/tickets` |
| Account | 16:451 | Phương tiện | `/vehicles` |
| Account | 16:508 | Cá nhân | `/profile` |
| Account | 16:590 | Thông báo | `/notifications` |
| Staff | 27:7 | Đăng nhập nhân viên | `/staff/login` |
| Staff | 27:42 | Trang chủ ca trực | `/staff/home` |
| Staff | 27:110 | Quét mã QR | `/staff/scan` |
| Staff | 27:144 | Xác nhận xe vào / ra | `/staff/confirm` |
| Staff | 27:191 | Sơ đồ chỗ đỗ | `/staff/slots` |

## Implementation and review

All 22 frames have high fidelity MCP context archived in `figma/` and matching reference PNGs. Original SVG files are local, never loaded from temporary Figma URLs at runtime. The QR module coordinates were translated directly from Figma rectangles into a CustomPainter; no QR encoding service is implied.

Five comparison sheets show Figma above Flutter. `visual_review.html` offers side-by-side and adjustable overlay review for every frame. Native Flutter layouts preserve design hierarchy and adapt to screen width; cards and forms can scroll on shorter devices rather than clipping controls. Maximum content width is 480 on larger displays.

Visual review corrected: home hero width; avatar and scanner icon background contrast; active/inactive navigation asset selection; green occupancy metric; customer grid slot state, dimensions, legend and booking progress; payment method icon badges and summary alignment; compact parking list cards.

Known intentional differences: native status bar instead of Figma's fake 9:41; native editable text fields/radios/time picker; demo labels and confirmation dialogs; three mock results; local sample history; flexible vertical spacing and text wrapping. Golden-test rendering may lack platform emoji fallback, although native devices provide their own fallback. No pixel-perfect claim is made. Screenshots are review artifacts, not runtime screen images.

## Validation

- Dart analyzer.
- All 22 screens rendered at widths 320, 390 and 480, detecting overflow and missing assets.
- Golden baseline renders at 390 × 844.
- Empty login validation.
- Mock duration/rate calculation.
- Selected slot propagation into confirmation and QR illustration.
- Cancelled payment stays on payment; explicit simulation confirmation opens demo ticket.
- Staff rejects an invalid manual code and opens the sample ticket for `SP-1022-007`.
- Mark notifications read.

Web and Android debug builds are checked for both entrypoints. No native device/emulator interaction or iOS build was performed on this Windows machine.
