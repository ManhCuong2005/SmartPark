import '../../../domain/models.dart';
import '../../../domain/parking_rules.dart';

/// View data is prepared once per snapshot, instead of scanning lots/slots for
/// every card while a long history is scrolling.
class BookingHistoryData {
  const BookingHistoryData(this.active, this.ended);
  final List<HistoryBooking> active, ended;

  factory BookingHistoryData.fromSnapshot(
    ParkingSnapshot snapshot,
    String? userId, {
    DateTime? now,
  }) {
    final lots = {for (final row in snapshot.rows('lots')) row['id']: row};
    final slots = {for (final row in snapshot.rows('slots')) row['id']: row};
    final vehicles = {
      for (final row in snapshot.rows('vehicles')) row['id']: row,
    };
    final active = <HistoryBooking>[], ended = <HistoryBooking>[];
    final clock = now ?? DateTime.now();
    for (final row in snapshot.rows('bookings')) {
      if (userId == null || row['customer_id'] != userId) continue;
      final status = row['status'];
      if (![
        'confirmed',
        'parked',
        'completed',
        'cancelled',
        'expired',
      ].contains(status)) {
        continue;
      }
      final start = _date(row['starts_at']), end = _date(row['ends_at']);
      if (start == null || end == null) continue;
      final checkedIn = _date(row['checked_in_at']);
      final checkedOut = _date(row['checked_out_at']);
      final rate = (row['hourly_rate'] as num?)?.toInt() ?? 0;
      final free = (row['free_minutes'] as num?)?.toInt() ?? 0;
      var amount = 0;
      if (row['prepaid'] == true || status == 'completed') {
        amount = (row['amount'] as num?)?.toInt() ?? 0;
      } else if (status == 'confirmed' && end.isAfter(start)) {
        amount = calculateFee(start, end, rate, free);
      } else if (status == 'parked' &&
          checkedIn != null &&
          clock.isAfter(checkedIn)) {
        amount = calculateFee(checkedIn, clock, rate, free);
      }
      final booking = HistoryBooking(
        id: row['id'] as String,
        status: status as String,
        lotName: lots[row['lot_id']]?['name'] as String? ?? 'Bãi đỗ',
        slotCode: slots[row['slot_id']]?['code'] as String? ?? '',
        plate: row['plate'] as String? ?? '',
        motorcycle:
            (row['vehicle_kind'] ?? vehicles[row['vehicle_id']]?['kind']) ==
            'motorcycle',
        startsAt: start,
        endsAt: end,
        checkedInAt: checkedIn,
        checkedOutAt: checkedOut,
        sortTime: checkedOut ?? _date(row['created_at']) ?? start,
        amount: amount,
        prepaid: row['prepaid'] == true,
      );
      (booking.isActive ? active : ended).add(booking);
    }
    active.sort((a, b) {
      if (a.status != b.status) return a.status == 'parked' ? -1 : 1;
      return a.startsAt.compareTo(b.startsAt);
    });
    ended.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return BookingHistoryData(active, ended);
  }
}

class HistoryBooking {
  const HistoryBooking({
    required this.id,
    required this.status,
    required this.lotName,
    required this.slotCode,
    required this.plate,
    required this.motorcycle,
    required this.startsAt,
    required this.endsAt,
    required this.sortTime,
    required this.amount,
    this.prepaid = false,
    this.checkedInAt,
    this.checkedOutAt,
  });
  final String id, status, lotName, slotCode, plate;
  final bool motorcycle, prepaid;
  final DateTime startsAt, endsAt, sortTime;
  final DateTime? checkedInAt, checkedOutAt;
  final int amount;
  bool get isActive => status == 'confirmed' || status == 'parked';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  String get dateLabel => historyDate(startsAt);
  String get timeLabel {
    final end =
        historyDate(endsAt) == dateLabel
            ? historyTime(endsAt)
            : '${historyDate(endsAt)} ${historyTime(endsAt)}';
    return '$dateLabel · ${historyTime(startsAt)} – $end';
  }

  String get durationLabel => historyDuration(
    (checkedOutAt ?? endsAt).difference(checkedInAt ?? startsAt),
  );
  String get priceCaption =>
      prepaid
          ? isCancelled
              ? 'Đã hoàn vào số dư'
              : 'Đã thanh toán'
          : status == 'parked'
          ? 'Tạm tính'
          : 'Dự kiến';
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
String _two(int value) => value.toString().padLeft(2, '0');
String historyDate(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year}';
String historyTime(DateTime value) =>
    '${_two(value.hour)}:${_two(value.minute)}';
String historyDuration(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil().clamp(0, 1000000);
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60, rest = minutes % 60;
  return rest == 0 ? '$hours giờ' : '$hours giờ $rest phút';
}
