import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/presentation/features/tickets/booking_history_data.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'package:smartpark/shared/widgets/park_widgets.dart';
import 'support/history_repository.dart';

const reviewKey = ValueKey('history-review-frame');
Future<ParkController> mountHistory(
  WidgetTester tester, {
  HistoryRepository? backend,
  String route = '/tickets',
  double width = 390,
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ParkController(
    backend ?? HistoryRepository(),
    monitorConnectivity: false,
  );
  await controller.initialize();
  await tester.pumpWidget(
    RepaintBoundary(
      key: reviewKey,
      child: ProviderScope(
        overrides: [
          parkControllerProvider.overrideWith((ref) => controller),
          themeModeProvider.overrideWith(
            (ref) => dark ? ThemeMode.dark : ThemeMode.light,
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SmartParkApp(initialRoute: route),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> captureReview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SMARTPARK_CAPTURE_REVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(reviewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.smartpark/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'history is account-scoped and prioritizes parked vehicles before reservations',
    () {
      final backend = HistoryRepository();
      backend.bookingRows = [
        historyBooking('future', 'confirmed', start: DateTime(2026, 10, 24)),
        historyBooking('stranger', 'completed', customerId: 'other-customer'),
        historyBooking(
          'parked',
          'parked',
          checkedIn: DateTime(2026, 10, 22, 14),
        ),
        historyBooking('sooner', 'confirmed', start: DateTime(2026, 10, 23)),
        historyBooking('ended', 'completed'),
        historyBooking('cancelled', 'cancelled'),
      ];
      final history = BookingHistoryData.fromSnapshot(
        backend.fixture(),
        backend.account,
        now: DateTime(2026, 10, 22, 15),
      );
      expect(history.active.map((b) => b.id), ['parked', 'sooner', 'future']);
      expect(history.ended.map((b) => b.id).toSet(), {'ended', 'cancelled'});
      expect(
        BookingHistoryData.fromSnapshot(backend.fixture(), null).active,
        isEmpty,
      );
    },
  );

  test(
    'estimated and actual prices are distinguished without inventing charges',
    () {
      final backend =
          HistoryRepository()
            ..bookingRows = [
              historyBooking('reserved', 'confirmed'),
              historyBooking(
                'parked',
                'parked',
                checkedIn: DateTime(2026, 10, 22, 14, 1),
              ),
              historyBooking('paid', 'completed', amount: 27000),
              historyBooking('cancelled', 'cancelled', amount: 99999),
            ];
      final data = BookingHistoryData.fromSnapshot(
        backend.fixture(),
        backend.account,
        now: DateTime(2026, 10, 22, 15, 30),
      );
      final rows = {
        for (final b in [...data.active, ...data.ended]) b.id: b,
      };
      expect(rows['reserved']!.amount, 30000);
      expect(rows['reserved']!.priceCaption, 'Dự kiến');
      expect(rows['parked']!.amount, 30000);
      expect(rows['parked']!.priceCaption, 'Tạm tính');
      expect(rows['paid']!.amount, 27000);
      expect(rows['cancelled']!.amount, 0);
    },
  );

  test(
    'dates remain readable across midnight and invalid records are skipped',
    () {
      final backend =
          HistoryRepository()
            ..bookingRows = [
              historyBooking(
                'overnight',
                'completed',
                start: DateTime(2026, 10, 22, 23, 30),
                end: DateTime(2026, 10, 23, 1, 45),
              ),
              {
                ...historyBooking('invalid', 'confirmed'),
                'starts_at': 'invalid',
              },
            ];
      final data = BookingHistoryData.fromSnapshot(
        backend.fixture(),
        backend.account,
      );
      expect(data.active, isEmpty);
      expect(
        data.ended.single.timeLabel,
        '22/10/2026 · 23:30 – 23/10/2026 01:45',
      );
      expect(data.ended.single.durationLabel, '2 giờ 15 phút');
    },
  );

  testWidgets('healthy app has no connection toolbar or technical timestamp', (
    tester,
  ) async {
    final state = await mountHistory(tester, route: '/home');
    expect(find.textContaining('Đã kết nối'), findsNothing);
    expect(
      find.text(state.snapshot.data['server_time'] as String),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('sync-retry-button')), findsNothing);
    expect(find.text('Bạn muốn đỗ xe\nở đâu hôm nay?'), findsOneWidget);
  });

  testWidgets('sync failure shows a concise notice and retry clears it', (
    tester,
  ) async {
    final backend = HistoryRepository();
    final state = await mountHistory(tester, backend: backend);
    backend.offline = true;
    await state.refresh();
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa thể đồng bộ. Đang hiển thị dữ liệu đã lưu.'),
      findsOneWidget,
    );
    expect(find.text(state.error!), findsNothing);
    backend.offline = false;
    await tester.tap(find.byKey(const ValueKey('sync-retry-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-retry-button')), findsNothing);
  });

  testWidgets(
    'active page highlights current ticket and shows two recent visits',
    (tester) async {
      await mountHistory(tester);
      expect(find.text('ĐANG SỬ DỤNG'), findsOneWidget);
      expect(find.text('Vị trí A07'), findsOneWidget);
      expect(find.text('Tạm tính'), findsOneWidget);
      expect(find.text('Gần đây'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-ended-recent-one')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-ended-recent-two')),
        findsOneWidget,
      );
      expect(find.text('24.000đ'), findsOneWidget);
      expect(find.text('60.000đ'), findsOneWidget);
      await captureReview(tester, 'history-active-390');
    },
  );

  testWidgets(
    'archive can filter cancellations and search without leaking old query',
    (tester) async {
      await mountHistory(tester);
      await tester.tap(find.text('Đã hoàn thành'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        'Sông Hàn',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('history-ended-recent-one')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-ended-recent-two')),
        findsNothing,
      );
      await tester.enterText(find.byKey(const ValueKey('history-search')), '');
      await tester.tap(find.text('Đã hủy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Đã hủy · Không thu phí'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-ended-recent-one')),
        findsNothing,
      );
      await tester.tap(find.text('Đang hoạt động'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã hoàn thành'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('history-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('history-ended-recent-one')),
        findsOneWidget,
      );
      await captureReview(tester, 'history-completed-390');
    },
  );

  testWidgets('tap current ticket opens its actual QR detail', (tester) async {
    final state = await mountHistory(tester);
    await tester.tap(find.byKey(const ValueKey('history-active-active')));
    await tester.pumpAndSettle();
    expect(state.selectedBookingId, 'active');
    expect(find.text('Vé điện tử SmartPark'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('long archive builds visible cards lazily', (tester) async {
    final backend =
        HistoryRepository()
          ..bookingRows = [
            for (var i = 0; i < 1000; i++)
              historyBooking(
                'history-$i',
                'completed',
                start: DateTime(2026, 10, 22).subtract(Duration(days: i)),
              ),
          ];
    await mountHistory(tester, backend: backend);
    await tester.tap(find.text('Đã hoàn thành'));
    await tester.pumpAndSettle();
    final cards = find.byWidgetPredicate(
      (w) => w is ParkCard && w.key.toString().contains('history-ended-'),
    );
    expect(cards.evaluate().length, lessThan(15));
    expect(
      find.byKey(const ValueKey('history-ended-history-999')),
      findsNothing,
    );
  });

  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('history is readable at $width in dark mode and larger text', (
      tester,
    ) async {
      await mountHistory(tester, width: width, dark: true, textScale: 1.35);
      expect(tester.takeException(), isNull);
      await captureReview(tester, 'history-dark-${width.toInt()}');
      await tester.tap(find.text('Đã hoàn thành'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty account has helpful text instead of sample tickets', (
    tester,
  ) async {
    await mountHistory(tester, backend: HistoryRepository()..bookingRows = []);
    expect(find.text('Chưa có vé đang hoạt động'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-active-active')), findsNothing);
    await tester.tap(find.text('Đã hoàn thành'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lượt gửi xe hoàn thành'), findsOneWidget);
    await captureReview(tester, 'history-empty-390');
  });
}
