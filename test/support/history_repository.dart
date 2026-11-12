import 'package:smartpark/domain/models.dart';
import 'test_repository.dart';

class HistoryRepository extends TestRepository {
  HistoryRepository() {
    final now = DateTime.now();
    bookingRows = [
      historyBooking(
        'active',
        'parked',
        lotId: 'lot-center',
        checkedIn: now.subtract(const Duration(minutes: 89)),
        start: now.subtract(const Duration(hours: 2)),
        end: now.add(const Duration(hours: 1)),
      ),
      historyBooking(
        'recent-one',
        'completed',
        lotId: 'lot-song-han',
        amount: 24000,
        start: DateTime(2026, 10, 18, 14),
        end: DateTime(2026, 10, 18, 16),
      ),
      historyBooking(
        'recent-two',
        'completed',
        lotId: 'lot-vincom',
        amount: 60000,
        start: DateTime(2026, 10, 12, 10),
        end: DateTime(2026, 10, 12, 13),
      ),
      historyBooking(
        'cancelled',
        'cancelled',
        lotId: 'lot-center',
        start: DateTime(2026, 10, 20, 10),
        end: DateTime(2026, 10, 20, 12),
      ),
    ];
  }
  late List<Json> bookingRows;
  @override
  ParkingSnapshot fixture() {
    final base = super.fixture().data;
    return ParkingSnapshot({
      ...base,
      'lots': [
        for (final pair in [
          ('lot-center', 'Bãi xe Trung tâm'),
          ('lot-song-han', 'Bãi xe Sông Hàn'),
          ('lot-vincom', 'Bãi xe Vincom'),
        ])
          {
            'id': pair.$1,
            'name': pair.$2,
            'area': 'Đà Nẵng',
            'car_rate': 15000,
            'motorcycle_rate': 5000,
          },
      ],
      'slots': [
        {
          'id': 'slot-history',
          'lot_id': 'lot-center',
          'code': 'A07',
          'enabled': true,
          'occupied': true,
        },
      ],
      'bookings': bookingRows,
    });
  }
}

Json historyBooking(
  String id,
  String status, {
  String lotId = 'lot-center',
  DateTime? start,
  DateTime? end,
  DateTime? checkedIn,
  int amount = 0,
  String? customerId,
}) {
  final begins = start ?? DateTime(2026, 10, 22, 14, 30);
  final finishes = end ?? begins.add(const Duration(hours: 2));
  return {
    'id': id,
    'customer_id': customerId ?? '10000000-0000-0000-0000-000000000001',
    'vehicle_id': '50000000-0000-0000-0000-000000000001',
    'lot_id': lotId,
    'slot_id': 'slot-history',
    'plate': '43A12345',
    'status': status,
    'starts_at': begins.toIso8601String(),
    'ends_at': finishes.toIso8601String(),
    'created_at': begins.subtract(const Duration(hours: 1)).toIso8601String(),
    'checked_in_at':
        (checkedIn ?? (status == 'completed' ? begins : null))
            ?.toIso8601String(),
    'checked_out_at': status == 'completed' ? finishes.toIso8601String() : null,
    'hourly_rate': 15000,
    'free_minutes': 10,
    'amount': amount,
    'qr_token': 'a' * 64,
    'version':
        status == 'completed'
            ? 3
            : status == 'parked'
            ? 2
            : 1,
  };
}
