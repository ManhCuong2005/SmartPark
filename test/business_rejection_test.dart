import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'package:smartpark/presentation/features/account/live_account.dart';
import 'package:smartpark/presentation/features/tickets/booking_history_data.dart';
import 'support/test_repository.dart';

class BusinessRepository extends TestRepository {
  BusinessRepository({
    super.offline,
    super.staff,
    this.status = 'confirmed',
    this.failure,
  });
  String status;
  ParkFailure? failure;
  bool includeBooking = true;
  final sent = <String>[];
  @override
  ParkingSnapshot fixture() {
    final original = super.fixture();
    return ParkingSnapshot({
      ...original.data,
      'bookings':
          includeBooking
              ? [
                {
                  ...original.rows('bookings').first,
                  'status': status,
                  'vehicle_id': original.rows('vehicles').first['id'],
                },
              ]
              : [],
    });
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    sent.add(id);
    if (failure != null) throw failure!;
    return super.execute(id, kind, payload);
  }
}

class DelayedVehicleRepository extends BusinessRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  int requests = 0;
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    requests++;
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.execute(id, kind, payload);
  }
}

class SignOutDuringEnqueueRepository extends BusinessRepository {
  @override
  Future<void> enqueue(PendingOperation operation) async {
    await super.enqueue(operation);
    loggedIn = false;
  }
}

void main() {
  test(
    'account change while staging never submits a command with another session',
    () async {
      final backend = SignOutDuringEnqueueRepository()..includeBooking = false;
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await expectLater(
        state.saveVehicle(old: state.vehicle, label: 'Xe', plate: '43A99999'),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.message,
            'reason',
            contains('Tài khoản đã thay đổi'),
          ),
        ),
      );
      expect(backend.sent, isEmpty);
      expect(backend.queued.single.userId, backend.account);
    },
  );
  for (final endedStatus in ['expired', 'completed', 'cancelled']) {
    test(
      'online vehicle edit refreshes cached active ticket after $endedStatus',
      () async {
        final backend = BusinessRepository();
        final state = ParkController(backend, monitorConnectivity: false);
        addTearDown(state.dispose);
        await state.initialize();
        expect(state.bookings.single['status'], 'confirmed');
        backend.status = endedStatus;
        await state.saveVehicle(
          old: state.vehicle,
          label: 'Xe',
          plate: '43A99999',
        );
        expect(state.bookings.single['status'], endedStatus);
        expect(backend.executions, 1);
        expect(state.operations, isEmpty);
      },
    );
  }
  test(
    'offline cache does not unlock a vehicle on a phone-clock assumption',
    () async {
      final backend = BusinessRepository(offline: true);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      backend.status = 'expired';
      await expectLater(
        state.saveVehicle(old: state.vehicle, label: 'Xe', plate: '43A99999'),
        throwsA(isA<ParkFailure>()),
      );
      expect(backend.queued, isEmpty);
    },
  );
  test(
    'concurrent saves for the same vehicle send exactly one operation',
    () async {
      final backend = DelayedVehicleRepository()..includeBooking = false;
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final first = state.saveVehicle(
        old: state.vehicle,
        label: 'Xe',
        plate: '43A99999',
      );
      await backend.started.future;
      await expectLater(
        state.saveVehicle(old: state.vehicle, label: 'Xe', plate: '43A99999'),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.message,
            'reason',
            contains('Đang lưu'),
          ),
        ),
      );
      backend.release.complete();
      await first;
      expect(backend.requests, 1);
      expect(backend.queued, isEmpty);
    },
  );
  test(
    'mismatched scanned QR never becomes an offline check-in request',
    () async {
      final backend = BusinessRepository(offline: true, staff: true);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      state.selectedBookingId = state.bookings.single['id'] as String;
      state.scannedQr =
          TicketIdentity(
            '60000000-0000-0000-0000-000000000099',
            'a' * 64,
          ).encoded;
      await expectLater(
        state.staffAction(true, state.vehicle.plate),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.message,
            'reason',
            contains('QR không khớp'),
          ),
        ),
      );
      expect(backend.queued, isEmpty);
    },
  );
  test(
    'expired QR explains the business restriction without queuing check-in',
    () async {
      final backend = BusinessRepository(
        offline: true,
        staff: true,
        status: 'expired',
      );
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final booking = state.bookings.single;
      await state.openTicket(
        TicketIdentity(
          booking['id'] as String,
          booking['qr_token'] as String,
        ).encoded,
      );
      await expectLater(
        state.staffAction(true, state.vehicle.plate),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.message,
            'reason',
            contains('Vé đã hết hạn'),
          ),
        ),
      );
      expect(backend.queued, isEmpty);
    },
  );
  for (final status in ['confirmed', 'parked']) {
    test(
      'active $status vehicle rejects identity edits locally without queue',
      () async {
        final backend = BusinessRepository(offline: true, status: status);
        final state = ParkController(backend, monitorConnectivity: false);
        addTearDown(state.dispose);
        await state.initialize();
        for (final change in ['plate', 'kind', 'delete']) {
          await expectLater(
            state.saveVehicle(
              old: state.vehicle,
              label: 'Xe',
              plate: change == 'plate' ? '43A99999' : state.vehicle.plate,
              kind: change == 'kind' ? 'motorcycle' : 'car',
              deleted: change == 'delete',
            ),
            throwsA(
              isA<ParkFailure>().having(
                (e) => e.message,
                'explanation',
                contains('Xe đang'),
              ),
            ),
          );
        }
        expect(backend.queued, isEmpty);
        expect(backend.sent, isEmpty);
      },
    );
  }
  for (final error in [
    'VEHICLE_IN_USE',
    'VERSION_CONFLICT',
    'INVALID_STATE',
    '23505',
  ]) {
    test(
      'online $error is reported and removed instead of becoming pending',
      () async {
        final backend = BusinessRepository(failure: ParkFailure(error))
          ..includeBooking = false;
        final state = ParkController(backend, monitorConnectivity: false);
        addTearDown(state.dispose);
        await state.initialize();
        await expectLater(
          state.saveVehicle(old: state.vehicle, label: 'Xe', plate: '43A99999'),
          throwsA(isA<ParkFailure>().having((e) => e.message, 'reason', error)),
        );
        expect(backend.sent.length, 1);
        expect(state.operations, isEmpty);
        expect(backend.queued, isEmpty);
      },
    );
  }
  test('label/default edits remain allowed for a booked vehicle', () async {
    final backend = BusinessRepository();
    final state = ParkController(backend, monitorConnectivity: false);
    addTearDown(state.dispose);
    await state.initialize();
    await state.saveVehicle(
      old: state.vehicle,
      label: 'Tên mới',
      plate: state.vehicle.plate,
      isDefault: true,
    );
    expect(backend.executions, 1);
    expect(backend.queued, isEmpty);
  });
  test(
    'ambiguous transport failure retains same durable ID for automatic retry',
    () async {
      final backend = BusinessRepository(
        failure: const ParkFailure('Timeout', retryable: true),
      )..includeBooking = false;
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await state.saveVehicle(
        old: state.vehicle,
        label: 'Xe',
        plate: '43A99999',
      );
      expect(backend.queued.single.id, backend.sent.single);
      expect(backend.queued.single.payload['plate'], '43A99999');
      expect(state.online, false);
    },
  );
  test(
    'expired ticket is ended with zero revenue; overdue parked stays active',
    () {
      final backend = BusinessRepository();
      final snapshot = backend.fixture();
      final rows = snapshot.rows('bookings');
      final now = DateTime.now();
      final history = BookingHistoryData.fromSnapshot(
        ParkingSnapshot({
          ...snapshot.data,
          'bookings': [
            {...rows.single, 'status': 'expired', 'amount': 999999},
            {
              ...rows.single,
              'id': 'overdue',
              'status': 'parked',
              'starts_at':
                  now.subtract(const Duration(hours: 3)).toIso8601String(),
              'ends_at':
                  now.subtract(const Duration(hours: 1)).toIso8601String(),
              'checked_in_at':
                  now.subtract(const Duration(hours: 3)).toIso8601String(),
            },
          ],
        }),
        backend.account,
        now: now,
      );
      expect(history.ended.single.isExpired, true);
      expect(history.ended.single.amount, 0);
      expect(history.active.single.id, 'overdue');
    },
  );
  testWidgets(
    'vehicle form shows business error and remains open without queue',
    (tester) async {
      final backend = BusinessRepository(status: 'parked');
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(home: VehiclesScreen(repository: state)),
      );
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '43A12345'),
        '43A99999',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Xe đang được gửi trong bãi'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(backend.queued, isEmpty);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 301));
    },
  );
  testWidgets(
    'vehicle form locks during request and becomes editable after rejection',
    (tester) async {
      final backend = DelayedVehicleRepository()..includeBooking = false;
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(home: VehiclesScreen(repository: state)),
      );
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(backend.requests, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, '43A12345'),
            )
            .enabled,
        false,
      );
      backend.release.completeError(
        const ParkFailure('Dữ liệu đã thay đổi. Vui lòng kiểm tra lại.'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Dữ liệu đã thay đổi'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(backend.queued, isEmpty);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 301));
    },
  );
}
