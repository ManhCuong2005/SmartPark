> Tài liệu lịch sử của bản prototype Figma. Trạng thái backend và kiểm thử hiện tại xem [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

# Validation — 26 October 2026

- Flutter 3.29.0 / Dart 3.7.0.
- Dart analyzer: no issues.
- Flutter test: 71 tests passed, including fixed golden regression baselines.
- All 22 screens checked at widths 320, 390 and 480 logical pixels.
- 22 Flutter screenshots and 22 Figma screenshots saved for comparison.
- Customer and Staff Android debug APK builds successful.
- Customer and Staff Web release builds successful.
- No physical-device or emulator interaction performed; iOS not built on Windows.

See flutter_regression.log, customer_apk_build.log, staff_apk_build.log, customer_web_build.log and staff_web_build.log for command results. Review visual_review.html or comparison_1.png through comparison_5.png (top: Figma, bottom: Flutter).

Payment, authentication, QR scanning/validation, GPS and Firebase are not live integrations. The runnable apps are UI prototypes with in-memory state and explicitly labeled simulations.
