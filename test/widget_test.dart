import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

Future<void> mount(
  WidgetTester tester,
  String route, {
  bool loggedIn = true,
  bool staff = false,
  double width = 390,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ParkController(
    TestRepository(loggedIn: loggedIn, staff: staff),
    monitorConnectivity: false,
  );
  await controller.initialize();
  controller.selectedBookingId = '60000000-0000-0000-0000-000000000001';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        parkControllerProvider.overrideWith((ref) => controller),
        themeModeProvider.overrideWith(
          (ref) =>
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        ),
      ],
      child: SmartParkApp(initialRoute: route, staff: staff),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('protected route shows real login form to signed-out user', (
    tester,
  ) async {
    await mount(tester, '/home', loggedIn: false);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Bạn muốn đỗ xe\nở đâu hôm nay?'), findsNothing);
    await tester.ensureVisible(find.text('Đăng nhập').last);
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập Địa chỉ email'), findsOneWidget);
  });
  testWidgets('active route reacts to Riverpod data updates and sign-out', (
    tester,
  ) async {
    await mount(tester, '/parking/list');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final state = container.read(parkControllerProvider);
    final data = Map<String, dynamic>.from(state.snapshot.data);
    final lots = state.snapshot.rows('lots');
    lots.first['name'] = 'Updated from realtime';
    data['lots'] = lots;
    state.update(() => state.snapshot = ParkingSnapshot(data));
    await tester.pumpAndSettle();
    expect(find.text('Updated from realtime'), findsOneWidget);
    await state.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
  for (final width in [320.0, 390.0, 480.0]) {
    for (final route in [
      '/home',
      '/parking/list',
      '/parking/detail',
      '/booking/slots',
      '/booking/time',
      '/booking/confirm',
      '/booking/payment',
      '/tickets/qr',
      '/tickets',
      '/vehicles',
      '/profile',
      '/profile/edit',
      '/notifications',
      '/sync',
      '/staff/home',
      '/staff/slots',
      '/staff/account',
    ]) {
      testWidgets('$route responds without overflow at $width', (tester) async {
        await mount(
          tester,
          route,
          width: width,
          staff: route.startsWith('/staff'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('dark mode retains readable ticket and form screens', (
    tester,
  ) async {
    await mount(tester, '/tickets/qr', brightness: Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(find.text('Vé điện tử SmartPark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
