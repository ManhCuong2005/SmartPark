import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/presentation/features/booking/payment_screen.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';
import 'support/test_payos_repository.dart';
import 'booking_extension_test.dart' show ExtensionRepository;

class PayLaterWallet extends TestPayosRepository {
  PayLaterWallet(this.amount);
  final int amount;
  @override
  Future<int> balance() async => amount;
}

class PayLaterRepository extends TestRepository {
  final requests = <Json>[];
  Json? reservation;
  bool loseAcknowledgement = false;
  @override
  ParkingSnapshot fixture() {
    final original = super.fixture();
    return ParkingSnapshot({
      ...original.data,
      'bookings': [if (reservation != null) reservation!],
    });
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    requests.add({'id': id, 'kind': kind, 'payload': payload});
    expect(kind, 'booking.reserve');
    reservation ??= {
      ...super.fixture().rows('bookings').single,
      ...payload,
      'prepaid': false,
      'amount': 0,
    };
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw const ParkFailure('Timeout', retryable: true);
    }
    return reservation!;
  }
}

void main() {
  for (final balance in [100000, 100001]) {
    testWidgets(
      'deferred extension requires strictly more than 100k ($balance)',
      (tester) async {
        final backend = ExtensionRepository();
        final state = ParkController(backend, monitorConnectivity: false);
        addTearDown(state.dispose);
        await state.initialize();
        final booking = state.bookings.single;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              payosTopupRepositoryProvider.overrideWithValue(
                PayLaterWallet(balance),
              ),
            ],
            child: MaterialApp(
              home: PaymentScreen(
                repository: state,
                booking: booking,
                newEnd: DateTime.parse(
                  booking['ends_at'] as String,
                ).add(const Duration(hours: 1)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Thanh toán sau khi xe ra'));
        await tester.tap(find.text('Thanh toán sau khi xe ra'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Xác nhận gia hạn · Trả khi xe ra',
        );
        expect(
          tester.widget<FilledButton>(button).onPressed != null,
          balance > 100000,
        );
        expect(backend.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final balance in [99999, 100000, 100001]) {
    testWidgets('pay later requires the 100000 balance threshold ($balance)', (
      tester,
    ) async {
      final backend = PayLaterRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      final wallet = PayLaterWallet(balance);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [payosTopupRepositoryProvider.overrideWithValue(wallet)],
          child: MaterialApp(
            home: PaymentScreen(repository: state),
            routes: {
              '/tickets/detail':
                  (_) => const Scaffold(body: Text('Reserved ticket')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thanh toán sau khi xe ra'));
      await tester.tap(find.text('Thanh toán sau khi xe ra'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(
        FilledButton,
        'Xác nhận đặt chỗ · Trả khi xe ra',
      );
      expect(
        tester.widget<FilledButton>(confirm).onPressed != null,
        balance > 100000,
      );
      if (balance > 100000) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('Reserved ticket'), findsOneWidget);
        expect(backend.requests.single['kind'], 'booking.reserve');
        expect(state.bookings.single['prepaid'], false);
        expect(state.bookings.single['amount'], 0);
      } else {
        expect(backend.requests, isEmpty);
        expect(find.text('Nạp thêm vào số dư'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'pay-later retry keeps the receipt ID even when its own ticket now occupies capacity',
    () async {
      final backend = PayLaterRepository()..loseAcknowledgement = true;
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await expectLater(state.reservePayLater(), throwsA(isA<ParkFailure>()));
      await state.reservePayLater();
      expect(backend.requests, hasLength(2));
      expect(backend.requests[0], backend.requests[1]);
      expect(state.selectedBookingId, backend.reservation!['id']);
    },
  );
}
