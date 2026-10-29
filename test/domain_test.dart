import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/domain/models.dart';
import 'package:smartpark/domain/parking_rules.dart';

void main() {
  test(
    'Vietnamese car and two-line motorcycle plates normalize without guessing',
    () {
      expect(normalizePlate('43A-123.45'), '43A12345');
      expect(plateCandidates('BIEN SO\n59-X1\n123.45'), contains('59X112345'));
      expect(plateCandidates('43A-123.45'), contains('43A12345'));
      expect(plateCandidates('30A-1234'), contains('30A1234'));
      expect(isValidPlate('43O-12I.45'), isFalse);
    },
  );
  test(
    'fee matches server: grace period then full elapsed hours rounded up',
    () {
      final start = DateTime.utc(2026, 1, 1);
      expect(
        calculateFee(start, start.add(const Duration(minutes: 10)), 15000, 10),
        0,
      );
      expect(
        calculateFee(start, start.add(const Duration(minutes: 11)), 15000, 10),
        15000,
      );
      expect(
        calculateFee(start, start.add(const Duration(minutes: 60)), 15000, 10),
        15000,
      );
      expect(
        calculateFee(
          start,
          start.add(const Duration(minutes: 60, seconds: 1)),
          15000,
          10,
        ),
        30000,
      );
      expect(
        () => calculateFee(
          start,
          start.subtract(const Duration(seconds: 1)),
          15000,
          0,
        ),
        throwsA(isA<ParkFailure>()),
      );
    },
  );
  test('QR validates version, ticket and capability format', () {
    final ticket = TicketIdentity(
      '60000000-0000-0000-0000-000000000001',
      'a' * 64,
    );
    expect(TicketIdentity.parse(ticket.encoded).token, ticket.token);
    for (final invalid in [
      'SP-1022-007',
      'smartpark:v2:x:y',
      'https://example.com',
    ]) {
      expect(() => TicketIdentity.parse(invalid), throwsA(isA<ParkFailure>()));
    }
  });
  test('reservation duration and timestamps are validated', () {
    final now = DateTime(2026, 10, 28, 12);
    expect(
      () => validateReservation(now, now.add(const Duration(hours: 2)), now),
      returnsNormally,
    );
    expect(
      () => validateReservation(now, now, now),
      throwsA(isA<ParkFailure>()),
    );
    expect(
      () => validateReservation(now, now.add(const Duration(days: 8)), now),
      throwsA(isA<ParkFailure>()),
    );
  });
  test('retry is bounded and authorization/conflicts are not transient', () {
    expect(retryDelay(100), const Duration(seconds: 512));
    expect(isTransientCode('40001'), isTrue);
    expect(isTransientCode('42501'), isFalse);
    expect(isTransientCode('23P01'), isFalse);
  });
}
