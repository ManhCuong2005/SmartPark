import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/features/tickets/live_tickets.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class ExtensionRepository extends TestRepository {
  Json? saved;
  bool conflict = false;
  final calls = <Json>[];
  @override
  ParkingSnapshot fixture() {
    final source = super.fixture();
    final now = DateTime.now().toUtc();
    saved ??= {
      ...source.rows('bookings').single,
      'status': 'parked',
      'checked_in_at':
          now.subtract(const Duration(minutes: 20)).toIso8601String(),
      'ends_at': now.add(const Duration(minutes: 5)).toIso8601String(),
    };
    return ParkingSnapshot({
      ...source.data,
      'bookings': [saved!],
    });
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    calls.add(payload);
    expect(kind, 'booking.extend');
    if (conflict) {
      throw const ParkFailure(
        'Ô đỗ đã có lịch trùng khoảng giờ bạn chọn.',
        code: 'SLOT_TIME_CONFLICT',
      );
    }
    saved = {...saved!, 'ends_at': payload['ends_at'], 'version': 2};
    return saved!;
  }
}

void main() {
  for (final conflict in [false, true]) {
    testWidgets(
      'extension ${conflict ? 'conflict stays editable' : 'success refreshes planned end'} without checkout or payment',
      (tester) async {
        final backend = ExtensionRepository()..conflict = conflict;
        final state = ParkController(backend, monitorConnectivity: false);
        addTearDown(state.dispose);
        await state.initialize();
        state.selectedBookingId = state.bookings.single['id'] as String;
        final original = DateTime.parse(state.ticket!['ends_at'] as String);
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, __) => TicketScreen(repository: state),
            ),
          ),
        );
        await tester.ensureVisible(find.text('Gia hạn thời gian'));
        await tester.tap(find.text('Gia hạn thời gian'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+2 giờ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận gia hạn'));
        await tester.pumpAndSettle();
        expect(backend.calls, hasLength(1));
        expect(state.ticket!['status'], 'parked');
        expect(state.ticket!['amount'], 0);
        expect(state.snapshot.rows('payments'), isEmpty);
        if (conflict) {
          expect(DateTime.parse(state.ticket!['ends_at'] as String), original);
          expect(find.text('Xác nhận gia hạn'), findsOneWidget);
          expect(find.textContaining('Ô đỗ đã có lịch trùng'), findsOneWidget);
        } else {
          expect(
            DateTime.parse(state.ticket!['ends_at'] as String),
            original.add(const Duration(hours: 2)),
          );
          expect(find.text('Xác nhận gia hạn'), findsNothing);
          expect(find.textContaining('Gia hạn thành công'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'local check-in is rejected exactly at the planned end, without creating a command',
    () async {
      final backend = TestRepository(staff: true, offline: true);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final b = state.bookings.single, now = DateTime.now().toUtc();
      state.snapshot = ParkingSnapshot({
        ...state.snapshot.data,
        'bookings': [
          {
            ...b,
            'starts_at':
                now.subtract(const Duration(hours: 1)).toIso8601String(),
            'ends_at': now.toIso8601String(),
          },
        ],
      });
      state.selectedBookingId = b['id'] as String;
      state.scannedQr =
          TicketIdentity(b['id'] as String, b['qr_token'] as String).encoded;
      await expectLater(
        state.staffAction(true, b['plate'] as String),
        throwsA(isA<ParkFailure>()),
      );
      expect(backend.queued, isEmpty);
    },
  );
}
