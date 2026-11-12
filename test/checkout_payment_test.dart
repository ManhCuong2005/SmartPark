import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/features/staff/operational_screens.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class ShortVisitRepository extends TestRepository {
  ShortVisitRepository() : super(staff: true, offline: true);
  @override
  ParkingSnapshot fixture() {
    final original = super.fixture(), now = DateTime.now().toUtc();
    return ParkingSnapshot({
      ...original.data,
      'bookings': [
        {
          ...original.rows('bookings').single,
          'status': 'parked',
          'free_minutes': 15,
          'checked_in_at':
              now.subtract(const Duration(seconds: 45)).toIso8601String(),
        },
      ],
    });
  }
}

class AcknowledgedCheckoutRepository extends ShortVisitRepository {
  bool acknowledged = false;
  AcknowledgedCheckoutRepository() {
    offline = false;
  }
  @override
  Future<ParkingSnapshot> refresh() async {
    if (acknowledged) {
      throw const ParkFailure('Snapshot unavailable', retryable: true);
    }
    return fixture();
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    acknowledged = true;
    return {
      ...fixture().rows('bookings').single,
      'status': 'completed',
      'amount': 15000,
      'checked_out_at': payload['occurred_at'],
      'version': 2,
    };
  }
}

void main() {
  test(
    'acknowledged collection keeps its amount when the next snapshot is offline',
    () async {
      final backend = AcknowledgedCheckoutRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final b = state.bookings.single;
      state.selectedBookingId = b['id'] as String;
      state.scannedQr =
          TicketIdentity(b['id'] as String, b['qr_token'] as String).encoded;
      await state.staffAction(false, b['plate'] as String);
      expect(state.ticket!['status'], 'completed');
      expect(state.ticket!['amount'], 15000);
      expect(state.operations, isEmpty);
      expect(backend.queued, isEmpty);
    },
  );
  testWidgets(
    'short visit shows minimum fee, asks exact cash amount, and queues it without claiming settled revenue',
    (tester) async {
      final backend = ShortVisitRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final booking = state.bookings.single;
      state.selectedBookingId = booking['id'] as String;
      state.scannedQr =
          TicketIdentity(
            booking['id'] as String,
            booking['qr_token'] as String,
          ).encoded;
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/staff/scan':
                (_) => const Scaffold(body: Text('Quét QR tiếp theo')),
          },
          home: AnimatedBuilder(
            animation: state,
            builder: (_, __) => StaffConfirmationScreen(repository: state),
          ),
        ),
      );
      expect(find.text('Số tiền cần thu'), findsOneWidget);
      expect(find.text('15.000đ'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '43A12345');
      final action = find.text('Xác nhận thu tiền mặt và xe ra');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.textContaining('Xác nhận đã thu 15.000đ'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(backend.queued, isEmpty);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận').last);
      await tester.pumpAndSettle();
      expect(backend.queued.single.kind, 'staff.check_out');
      expect(state.ticket!['amount'], 15000);
      expect(state.ticket!['local_pending'], true);
      expect(find.text('Quét QR tiếp theo'), findsOneWidget);
      expect(state.scannedQr, isNull);
      expect(find.text('Đã thu'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
