import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/domain/parking_rules.dart';
import 'package:smartpark/domain/plate_recognition_service.dart';
import 'package:smartpark/presentation/features/staff/operational_screens.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class AvailabilityRepository extends TestRepository {
  AvailabilityRepository({super.offline, super.staff});
  List<Json> rows = [];
  bool fail = false, delay = false;
  Json? vehicleConflict;
  final requests = <Completer<ReservationAvailability>>[];
  @override
  Future<ReservationAvailability> availability(
    String lotId,
    DateTime start,
    DateTime end, {
    String? vehicleId,
  }) {
    if (fail) {
      return Future.error(const ParkFailure('Không tải được chỗ trống'));
    }
    if (!delay) {
      return Future.value(
        ReservationAvailability(slots: rows, vehicleConflict: vehicleConflict),
      );
    }
    final request = Completer<ReservationAvailability>();
    requests.add(request);
    return request.future;
  }
}

class Recognition implements PlateRecognitionService {
  List<String>? result = ['59X112345'];
  @override
  Future<List<String>?> captureAndRecognize() async => result;
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'no-show boundary is the scheduled end; early admission preserves the end',
    () {
      final start = DateTime(2026, 11, 12, 14),
          end = DateTime(2026, 11, 12, 16);
      expect(noShowDeadline(end), DateTime(2026, 11, 12, 16));
      expect(admissionPeriod(start, end, start).end, end);
      expect(
        admissionPeriod(
          start,
          end,
          start.subtract(const Duration(minutes: 10)),
        ).start,
        start.subtract(const Duration(minutes: 10)),
      );
    },
  );

  test(
    'quick durations cross midnight and discard the previous slot',
    () async {
      final backend = AvailabilityRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      state.slot = 'A001';
      state.setReservationPeriod(
        DateTime(2026, 11, 12, 23, 30),
        DateTime(2026, 11, 13, 1, 30),
      );
      state.setDuration(8);
      expect(state.endsAt, DateTime(2026, 11, 13, 7, 30));
      expect(state.durationMinutes, 480);
      expect(state.selectedSlotId, isNull);
      expect(state.canContinueBooking, false);
    },
  );

  test(
    'empty and failed availability never fall back to current free slots',
    () async {
      final backend = AvailabilityRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.slots, isNotEmpty);
      expect(state.availabilityReady, true);
      expect(state.bookingSlots, isEmpty);
      state.slot = 'A001';
      expect(state.canContinueBooking, false);
      backend.rows = backend.fixture().rows('slots');
      await state.loadAvailability();
      state.slot = 'A001';
      expect(state.canContinueBooking, true);
      backend.rows = [
        {...backend.rows.single, 'occupied': true},
      ];
      await state.loadAvailability();
      expect(state.selectedSlotId, isNull);
      backend.fail = true;
      await state.loadAvailability();
      expect(state.availabilityError, isNotNull);
      expect(state.bookingSlots, isEmpty);
      expect(state.canContinueBooking, false);
    },
  );

  test(
    'out-of-order availability cannot replace the latest chosen interval',
    () async {
      final backend = AvailabilityRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      backend.delay = true;
      final first = state.loadAvailability();
      state.setReservationPeriod(
        state.startsAt.add(const Duration(days: 1)),
        state.endsAt.add(const Duration(days: 1)),
      );
      final second = state.loadAvailability();
      backend.requests.last.complete(const ReservationAvailability(slots: []));
      await second;
      backend.requests.first.complete(
        ReservationAvailability(slots: backend.fixture().rows('slots')),
      );
      await first;
      expect(state.bookingSlots, isEmpty);
      expect(state.availabilityLoading, false);
    },
  );

  test(
    'offline valid admission preserves the end; expired tickets never queue',
    () async {
      final backend = TestRepository(offline: true, staff: true);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final now = DateTime.now().toUtc();
      final b = state.bookings.single;
      state.snapshot = ParkingSnapshot({
        ...state.snapshot.data,
        'bookings': [
          {
            ...b,
            'starts_at':
                now.subtract(const Duration(minutes: 121)).toIso8601String(),
            'ends_at': now.add(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      });
      state.selectedBookingId = b['id'] as String;
      state.scannedQr =
          TicketIdentity(b['id'] as String, b['qr_token'] as String).encoded;
      await state.staffAction(true, b['plate'] as String);
      expect(state.ticket!['status'], 'parked');
      expect(
        DateTime.parse(state.ticket!['ends_at'] as String),
        now.add(const Duration(hours: 2)),
      );
      backend.queued.clear();
      state.operations = [];
      state.snapshot = ParkingSnapshot({
        ...state.snapshot.data,
        'bookings': [
          {
            ...b,
            'starts_at':
                now.subtract(const Duration(hours: 3)).toIso8601String(),
            'ends_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
        ],
      });
      await expectLater(
        state.staffAction(true, b['plate'] as String),
        throwsA(isA<ParkFailure>()),
      );
      expect(backend.queued, isEmpty);
    },
  );

  testWidgets(
    'customer chooses time, quick duration and available slot before confirmation',
    (tester) async {
      final backend = AvailabilityRepository();
      backend.rows = backend.fixture().rows('slots');
      final state = ParkController(backend, monitorConnectivity: false);
      await state.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [parkControllerProvider.overrideWith((ref) => state)],
          child: const SmartParkApp(initialRoute: '/parking/detail'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt chỗ đỗ xe'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn thời gian'), findsOneWidget);
      await tester.ensureVisible(find.text('+4 giờ'));
      await tester.tap(find.text('+4 giờ'));
      await tester.pumpAndSettle();
      expect(state.durationMinutes, 240);
      await tester.tap(find.text('Tìm chỗ trống'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn chỗ đỗ'), findsOneWidget);
      await tester.ensureVisible(find.text('A001'));
      await tester.tap(find.text('A001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đặt chỗ'), findsOneWidget);
      expect(backend.executions, 0);
    },
  );

  testWidgets('OCR vibrates only after a nonempty successful recognition', (
    tester,
  ) async {
    final recognition = Recognition();
    final state = ParkController(
      TestRepository(staff: true),
      monitorConnectivity: false,
      plateService: recognition,
    );
    addTearDown(state.dispose);
    await state.initialize();
    state.selectedBookingId = state.bookings.single['id'] as String;
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: StaffConfirmationScreen(repository: state)),
    );
    await tester.tap(find.text('Chụp biển số · AI OCR'));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
    expect(find.text('59X112345'), findsWidgets);
    recognition.result = [];
    await tester.tap(find.text('Chụp biển số · AI OCR'));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
    recognition.result = null;
    await tester.tap(find.text('Chụp biển số · AI OCR'));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
  });

  testWidgets('QR feedback follows successful ticket validation only', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final state = ParkController(
      TestRepository(staff: true),
      monitorConnectivity: false,
    );
    addTearDown(state.dispose);
    await state.initialize();
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StaffScannerScreen(repository: state),
        routes: {
          '/staff/confirm': (_) => const Scaffold(body: Text('Vé hợp lệ')),
        },
      ),
    );
    final dynamic scannerState = tester.state(find.byType(StaffScannerScreen));
    final invalid = scannerState.open('invalid') as Future<void>;
    await tester.pumpAndSettle();
    await invalid;
    expect(haptics, isEmpty);
    final ticket = state.bookings.single;
    final valid =
        scannerState.open(
              TicketIdentity(
                ticket['id'] as String,
                ticket['qr_token'] as String,
              ).encoded,
            )
            as Future<void>;
    await tester.pumpAndSettle();
    expect(find.text('Vé hợp lệ'), findsOneWidget);
    expect(haptics, hasLength(1));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await valid;
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final width in [320.0, 390.0]) {
    for (final route in ['/booking/time', '/booking/slots']) {
      testWidgets(
        '$route remains readable at $width with dark mode and larger text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.platformDispatcher.textScaleFactorTestValue =
              width == 320 ? 1.4 : 1;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final backend = AvailabilityRepository();
          final slot = backend.fixture().rows('slots').single;
          backend.rows = List.generate(
            12,
            (i) => {
              ...slot,
              'id': 'slot-$i',
              'code': 'A${(i + 1).toString().padLeft(3, '0')}',
              'occupied': i % 3 == 1,
            },
          );
          final state = ParkController(backend, monitorConnectivity: false);
          await state.initialize();
          const boundaryKey = ValueKey('reservation-review');
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: ProviderScope(
                overrides: [
                  parkControllerProvider.overrideWith((ref) => state),
                  themeModeProvider.overrideWith(
                    (ref) => width == 320 ? ThemeMode.dark : ThemeMode.light,
                  ),
                ],
                child: SmartParkApp(initialRoute: route),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (route.endsWith('slots')) {
            await tester.ensureVisible(find.text('A001'));
            await tester.tap(find.text('A001'));
            await tester.pumpAndSettle();
            expect(state.slot, 'A001');
            expect(state.canContinueBooking, true);
          }
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('SMARTPARK_CAPTURE_REVIEW')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(boundaryKey),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '.smartpark/ui-review/reservation-${route.split('/').last}-${width.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
