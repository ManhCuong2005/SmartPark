import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/core/data/mock_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('Mock price follows duration and selected lot', () {
    final repo = MockParkRepository();
    expect(repo.total, 30000);
    repo.lot = MockParkRepository.lots[1];
    expect(repo.total, 24000);
    repo.end = const TimeOfDay(hour: 17, minute: 0);
    expect(repo.total, 30000);
    expect(repo.booked, isFalse);
    repo.dispose();
  });
  testWidgets(
    'Selected slot propagates to confirmation; payment requires demo confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const SmartParkApp(initialRoute: '/booking/slots'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A03'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('A03 · Tầng 1'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận thanh toán'));
      await tester.pumpAndSettle();
      expect(find.text('Mô phỏng SmartPark'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán'), findsOneWidget);
      await tester.tap(find.text('Xác nhận thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục mô phỏng'));
      await tester.pumpAndSettle();
      expect(find.text('QR minh họa · chưa kích hoạt'), findsOneWidget);
      expect(find.textContaining('A03 · Tầng 1'), findsOneWidget);
    },
  );
  testWidgets('Staff rejects invalid manual ticket and opens demo ticket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const SmartParkApp(staff: true, initialRoute: '/staff/scan'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nhập mã vé thủ công'));
    await tester.tap(find.text('Nhập mã vé thủ công'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'INVALID');
    await tester.tap(find.text('Kiểm tra demo'));
    await tester.pumpAndSettle();
    expect(find.text('Mã vé demo không hợp lệ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'SP-1022-007');
    await tester.tap(find.text('Kiểm tra demo'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận vé'), findsOneWidget);
    expect(find.text('Trạng thái minh họa • chưa xác thực'), findsOneWidget);
  });
  testWidgets('Notifications can be marked read', (tester) async {
    await tester.pumpWidget(const SmartParkApp(initialRoute: '/notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
