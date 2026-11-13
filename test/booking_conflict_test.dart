import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';
import 'support/test_payos_repository.dart';

class ConflictRepository extends TestRepository {
  String mode = 'success';
  bool occupied = false;
  Json? conflict, receipt;
  final submitted = <({String id, Json payload})>[];
  int writes = 0;
  Json overlappingTicket() => {
    'id': super.fixture().rows('bookings').single['id'],
    'lot_name': 'Công viên 29/3',
    'slot_code': 'A011',
    'status': 'confirmed',
    'starts_at': DateTime.now().toUtc().toIso8601String(),
    'ends_at':
        DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String(),
  };
  @override
  ParkingSnapshot fixture() {
    final original = super.fixture();
    return receipt == null
        ? original
        : ParkingSnapshot({
          ...original.data,
          'bookings': [receipt!],
        });
  }

  @override
  Future<ReservationAvailability> availability(
    String lotId,
    DateTime start,
    DateTime end, {
    String? vehicleId,
  }) async => ReservationAvailability(
    capacities: [
      for (final row in fixture().rows('capacities'))
        {...row, 'remaining': occupied ? 0 : 1},
    ],
    vehicleConflict: conflict,
  );
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    if (kind != 'booking.pay') return super.execute(id, kind, payload);
    submitted.add((id: id, payload: Map.of(payload)));
    if (mode == 'race_slot') {
      occupied = true;
      throw const ParkFailure(
        'Ô đỗ đã có lịch trùng khoảng giờ bạn chọn.',
        code: 'CAPACITY_FULL',
      );
    }
    if (mode == 'race_vehicle') {
      conflict = overlappingTicket();
      throw const ParkFailure(
        'Xe đã có lịch trùng giờ.',
        code: 'VEHICLE_TIME_CONFLICT',
      );
    }
    if (receipt == null) {
      writes++;
      receipt = {
        ...super.fixture().rows('bookings').single,
        ...payload,
        'prepaid': true,
        'amount': payload['expected_amount'],
      };
      if (mode == 'lost_ack') {
        conflict = {...overlappingTicket(), 'id': payload['id']};
        throw const ParkFailure('Mất phản hồi sau khi tạo vé', retryable: true);
      }
    }
    return receipt!;
  }
}

class DelayedBookingRepository extends ConflictRepository {
  Completer<void>? availabilityGate;
  Completer<void>? writeGate;
  ParkFailure? availabilityFailure;
  @override
  Future<ReservationAvailability> availability(
    String lotId,
    DateTime start,
    DateTime end, {
    String? vehicleId,
  }) async {
    await availabilityGate?.future;
    if (availabilityFailure != null) throw availabilityFailure!;
    return super.availability(lotId, start, end, vehicleId: vehicleId);
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    if (kind == 'booking.pay') await writeGate?.future;
    return super.execute(id, kind, payload);
  }
}

Future<ParkController> controller(ConflictRepository backend) async {
  final state = ParkController(backend, monitorConnectivity: false);
  addTearDown(state.dispose);
  await state.initialize();
  return state;
}

Future<ParkController> mountSlotPicker(
  WidgetTester tester,
  DelayedBookingRepository backend,
) async {
  final state = ParkController(backend, monitorConnectivity: false);
  await state.initialize();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        parkControllerProvider.overrideWith((ref) => state),
        payosTopupRepositoryProvider.overrideWithValue(TestPayosRepository()),
      ],
      child: const SmartParkApp(initialRoute: '/booking/time'),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  test(
    'booking response cannot populate a different signed-in account',
    () async {
      final backend = DelayedBookingRepository()..writeGate = Completer<void>();
      final state = await controller(backend);
      final request = state.book();
      await Future<void>.delayed(Duration.zero);
      backend.loggedIn = false;
      state.snapshot = ParkingSnapshot.empty;
      backend.writeGate!.complete();
      await expectLater(request, throwsA(isA<ParkFailure>()));
      expect(state.snapshot.rows('bookings'), isEmpty);
      expect(state.selectedBookingId, isNull);
    },
  );
  setUpAll(() async {
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'delayed booking flow advances each step and writes only at final confirmation',
    (tester) async {
      final backend = DelayedBookingRepository();
      final state = await mountSlotPicker(tester, backend);
      final gate = Completer<void>();
      backend.availabilityGate = gate;
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(state.availabilityLoading, true);
      expect(find.text('Đang xử lý…'), findsOneWidget);
      expect(backend.submitted, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đặt chỗ'), findsOneWidget);
      expect(backend.submitted, isEmpty);
      expect(state.selectedBookingId, isNull);
      final confirmGate = Completer<void>();
      backend.availabilityGate = confirmGate;
      await tester.tap(find.text('Thanh toán'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Đang xử lý…'), findsOneWidget);
      expect(backend.submitted, isEmpty);
      confirmGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán vé'), findsOneWidget);
      await tester.tap(find.text('Số dư gửi xe'));
      await tester.pumpAndSettle();

      final paymentGate = Completer<void>(), writeGate = Completer<void>();
      backend.availabilityGate = paymentGate;
      backend.writeGate = writeGate;
      await tester.tap(
        find.widgetWithText(FilledButton, 'Thanh toán ${money(state.total)}'),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(backend.writes, 0);
      paymentGate.complete();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Đang xử lý…'), findsOneWidget);
      expect(backend.writes, 0);
      state.update(() {}); // A normal data refresh must not cancel navigation.
      await tester.pump();
      writeGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Vé điện tử SmartPark'), findsOneWidget);
      expect(backend.writes, 1);
      expect(backend.submitted, hasLength(1));
      expect(state.selectedBookingId, backend.receipt!['id']);
      expect(tester.takeException(), isNull);
    },
  );
  for (final failure in ['slot', 'vehicle', 'network']) {
    testWidgets(
      'delayed $failure check gives visible feedback and never silently abandons the action',
      (tester) async {
        final backend = DelayedBookingRepository();
        final state = await mountSlotPicker(tester, backend);
        final gate = Completer<void>();
        backend.availabilityGate = gate;
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Đang xử lý…'), findsOneWidget);
        if (failure == 'slot') backend.occupied = true;
        if (failure == 'vehicle') {
          backend.conflict = backend.overlappingTicket();
        }
        if (failure == 'network') {
          backend.availabilityFailure = const ParkFailure(
            'Kết nối tạm thời gián đoạn. Vui lòng thử lại.',
            retryable: true,
          );
        }
        gate.complete();
        await tester.pumpAndSettle();
        expect(backend.submitted, isEmpty);
        expect(state.selectedBookingId, isNull);
        if (failure == 'vehicle') {
          expect(find.text('Chọn thời gian'), findsOneWidget);
          expect(find.text('Xe đã có lịch trùng giờ'), findsOneWidget);
        } else if (failure == 'slot') {
          expect(find.text('Chọn thời gian'), findsOneWidget);
          expect(find.textContaining('Bãi đã hết chỗ'), findsOneWidget);
          expect(state.remainingCapacity, 0);
        } else {
          expect(
            find.textContaining('Kết nối tạm thời gián đoạn'),
            findsWidgets,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          backend.availabilityFailure = null;
          backend.availabilityGate = null;
          await tester.tap(find.text('Tiếp tục'));
          await tester.pumpAndSettle();
          expect(find.text('Xác nhận đặt chỗ'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'free slot never masks an overlapping vehicle booking at another lot',
    () async {
      final backend =
          ConflictRepository()
            ..conflict = ConflictRepository().overlappingTicket();
      final state = await controller(backend);
      expect(state.bookingCapacities.first['remaining'], 1);
      expect(state.canContinueBooking, false);
      await expectLater(
        state.prepareBooking(),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.code,
            'code',
            'VEHICLE_TIME_CONFLICT',
          ),
        ),
      );
      expect(backend.submitted, isEmpty);
      expect(
        state.vehicleConflictMessage,
        contains('đã có vé trùng thời gian'),
      );
      expect(state.canContinueBooking, false);
    },
  );

  test(
    'preflight detects a slot taken since selection before sending a write',
    () async {
      final backend = ConflictRepository();
      final selected = await controller(backend);
      expect(selected.canContinueBooking, true);
      backend.occupied = true;
      await expectLater(
        selected.book(),
        throwsA(
          isA<ParkFailure>().having((e) => e.code, 'code', 'CAPACITY_FULL'),
        ),
      );
      expect(backend.submitted, isEmpty);
      expect(selected.vehicleConflict, isNull);
    },
  );

  for (final mode in ['race_slot', 'race_vehicle']) {
    test(
      '$mode refreshes the correct conflict instead of keeping a selectable stale slot',
      () async {
        final backend = ConflictRepository();
        final selected = await controller(backend);
        expect(selected.canContinueBooking, true);
        backend.mode = mode;
        await expectLater(
          selected.book(),
          throwsA(
            isA<ParkFailure>().having(
              (e) => e.code,
              'code',
              mode == 'race_slot' ? 'CAPACITY_FULL' : 'VEHICLE_TIME_CONFLICT',
            ),
          ),
        );
        expect(selected.canContinueBooking, false);
        expect(selected.selectedBookingId, isNull);
        expect(backend.writes, 0);
      },
    );
  }

  test(
    'lost acknowledgement retries the same receipt even when its own new ticket clears the selected slot',
    () async {
      final backend = ConflictRepository();
      final state = await controller(backend);
      backend.mode = 'lost_ack';
      await expectLater(
        state.book(),
        throwsA(
          isA<ParkFailure>().having((e) => e.retryable, 'retryable', true),
        ),
      );
      await state.loadAvailability();
      expect(state.vehicleConflict, isNotNull);
      await state.book();
      expect(backend.writes, 1);
      expect(backend.submitted, hasLength(2));
      expect(backend.submitted.first.id, backend.submitted.last.id);
      expect(backend.submitted.first.payload, backend.submitted.last.payload);
      expect(state.selectedBookingId, backend.receipt!['id']);
    },
  );

  testWidgets('customer sees the conflicting lot before choosing a slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = ConflictRepository();
    backend.conflict = backend.overlappingTicket();
    final state = ParkController(backend, monitorConnectivity: false);
    await state.initialize();
    const review = ValueKey('conflict-review');
    await tester.pumpWidget(
      RepaintBoundary(
        key: review,
        child: ProviderScope(
          overrides: [parkControllerProvider.overrideWith((ref) => state)],
          child: const SmartParkApp(initialRoute: '/booking/time'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn thời gian'), findsOneWidget);
    expect(find.text('Xe đã có lịch trùng giờ'), findsOneWidget);
    expect(find.text('Xem vé đang trùng'), findsNothing);
    expect(backend.submitted, isEmpty);
    await tester.ensureVisible(find.text('Xe đã có lịch trùng giờ'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('SMARTPARK_CAPTURE_REVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(review),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('.smartpark/ui-review/booking-vehicle-conflict.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets(
    'a concurrent slot booking returns payment screen to the refreshed slot picker',
    (tester) async {
      final backend = ConflictRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      await state.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parkControllerProvider.overrideWith((ref) => state),
            payosTopupRepositoryProvider.overrideWithValue(
              TestPayosRepository(),
            ),
          ],
          child: const SmartParkApp(initialRoute: '/booking/time'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Số dư gửi xe'));
      await tester.pumpAndSettle();
      backend.mode = 'race_slot';
      await tester.tap(
        find.widgetWithText(FilledButton, 'Thanh toán ${money(state.total)}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán vé'), findsOneWidget);
      expect(state.remainingCapacity, 0);
      expect(state.vehicleConflict, isNull);
      expect(find.text('Vé điện tử SmartPark'), findsNothing);
      await tester.tap(find.text('Đổi thời gian'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn thời gian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
