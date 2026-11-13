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

  test(
    'prepaid exit never collects the booked fee again, including overtime',
    () {
      expect(checkoutAmount(booking, entered), 0);
      expect(
        checkoutAmount(booking, plannedEnd.add(const Duration(hours: 1))),
        0,
      );
    },
  );

  test('legacy tickets keep actual-time cash checkout', () {
    expect(checkoutAmount({...booking, 'prepaid': false}, entered), 15000);
    expect(checkoutAmount({...booking, 'prepaid': false}, plannedEnd), 30000);
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
}
