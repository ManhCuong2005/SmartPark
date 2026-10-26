import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/smartpark_app.dart';

const screens = <String, String>{
  '13_3': '/',
  '13_25': '/onboarding',
  '13_61': '/login',
  '13_96': '/register',
  '13_139': '/home',
  '13_236': '/parking/map',
  '13_333': '/parking/list',
  '13_429': '/parking/detail',
  '16_7': '/booking/slots',
  '16_73': '/booking/time',
  '16_134': '/booking/confirm',
  '16_176': '/booking/payment',
  '16_228': '/tickets/qr',
  '16_390': '/tickets',
  '16_451': '/vehicles',
  '16_508': '/profile',
  '16_590': '/notifications',
  '27_7': '/staff/login',
  '27_42': '/staff/home',
  '27_110': '/staff/scan',
  '27_144': '/staff/confirm',
  '27_191': '/staff/slots',
};
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
  for (final width in [390.0, 320.0, 480.0]) {
    for (final screen in screens.entries) {
      testWidgets('${screen.key} at $width has no layout or asset errors', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await tester.pumpWidget(
          SmartParkApp(key: UniqueKey(), initialRoute: screen.value),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/${screen.key}.png'),
          );
        }
      });
    }
  }
  testWidgets('Login validates empty fields', (tester) async {
    await tester.pumpWidget(const SmartParkApp(initialRoute: '/login'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng nhập').last);
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập Địa chỉ email'), findsOneWidget);
  });
}
