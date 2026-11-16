import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/domain/parking_rules.dart';

void main() {
  final entered = DateTime.utc(2026, 11, 12, 14);
  final plannedEnd = entered.add(const Duration(hours: 2));
  final booking = <String, dynamic>{
    'checked_in_at': entered.toIso8601String(),
    'ends_at': plannedEnd.toIso8601String(),
    'hourly_rate': 15000,
    'free_minutes': 0,
    'amount': 30000,
    'prepaid': true,
  };

  test('prepaid exit collects only time beyond the paid coverage', () {
    expect(checkoutAmount(booking, entered), 0);
    expect(
      checkoutAmount(booking, plannedEnd.add(const Duration(hours: 1))),
      15000,
    );
  });

  test('pay-later tickets use actual-time wallet checkout', () {
    expect(checkoutAmount({...booking, 'prepaid': false}, entered), 15000);
    expect(checkoutAmount({...booking, 'prepaid': false}, plannedEnd), 30000);
  });

  test('extending the planned end does not make unpaid hours free', () {
    final extended = {
      ...booking,
      'paid_until': plannedEnd.toIso8601String(),
      'ends_at': plannedEnd.add(const Duration(hours: 2)).toIso8601String(),
    };
    expect(checkoutAmount(extended, plannedEnd), 0);
    expect(
      checkoutAmount(extended, plannedEnd.add(const Duration(minutes: 1))),
      15000,
    );
    expect(
      checkoutAmount(extended, plannedEnd.add(const Duration(minutes: 61))),
      30000,
    );
  });

  test('extension charges only the extra duration, rounded up to one hour', () {
    expect(
      extensionFee(booking, plannedEnd.add(const Duration(minutes: 1))),
      15000,
    );
    expect(
      extensionFee(booking, plannedEnd.add(const Duration(hours: 2))),
      30000,
    );
    expect(
      extensionFee(booking, plannedEnd.add(const Duration(minutes: 61))),
      30000,
    );
  });
  test(
    'pay-now extension includes earlier deferred hours and unpaid original time',
    () {
      final deferred = {
        ...booking,
        'paid_until': plannedEnd.toIso8601String(),
        'ends_at': plannedEnd.add(const Duration(hours: 1)).toIso8601String(),
      };
      expect(
        extensionFee(deferred, plannedEnd.add(const Duration(hours: 2))),
        30000,
      );
      expect(
        extensionFee({
          ...booking,
          'prepaid': false,
        }, plannedEnd.add(const Duration(hours: 1))),
        45000,
      );
    },
  );
}
