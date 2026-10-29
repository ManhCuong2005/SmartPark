import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

void main() {
  test(
    'offline booking never creates success or queues a reservation',
    () async {
      final backend = TestRepository(offline: true);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      state.slot = 'A001';
      await expectLater(state.book(), throwsA(isA<ParkFailure>()));
      expect(state.selectedBookingId, isNull);
      expect(backend.queued, isEmpty);
    },
  );
  test(
    'staff verifies the actual plate and retains offline commands',
    () async {
      final backend = TestRepository(offline: true, staff: true),
          state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await state.openTicket(
        TicketIdentity(
          '60000000-0000-0000-0000-000000000001',
          'a' * 64,
        ).encoded,
      );
      await expectLater(
        state.staffAction(true, '43A99999'),
        throwsA(isA<ParkFailure>()),
      );
      expect(backend.queued, isEmpty);
      await state.staffAction(true, '43A-123.45');
      expect(backend.queued.single.kind, 'staff.check_in');
      expect(state.ticket!['status'], 'parked');
      expect(state.ticket!['local_pending'], true);
      await expectLater(
        state.staffAction(true, '43A12345'),
        throwsA(isA<ParkFailure>()),
      );
      expect(backend.queued.length, 1);
    },
  );
  test(
    'sign up requiring email confirmation does not navigate as authenticated',
    () async {
      final state = ParkController(
        TestRepository(loggedIn: false),
        monitorConnectivity: false,
      );
      addTearDown(state.dispose);
      expect(
        await state.authenticate(
          'a@test.invalid',
          'testpassword',
          fullName: 'A',
        ),
        isFalse,
      );
      expect(state.signedIn, isFalse);
      expect(state.error, contains('xác nhận'));
    },
  );
}
