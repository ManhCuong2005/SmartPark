// Domain contains no Flutter, persistence, networking or platform dependencies.
typedef Json = Map<String, dynamic>;

class ParkFailure implements Exception {
  const ParkFailure(this.message, {this.retryable = false, this.code});
  final String message;
  final bool retryable;
  final String? code;
  @override
  String toString() => message;
}

class ReservationAvailability {
  const ReservationAvailability({
    required this.capacities,
    this.vehicleConflict,
  });
  final List<Json> capacities;

  /// Only the signed-in customer's selected vehicle; never another customer's ticket.
  final Json? vehicleConflict;
  factory ReservationAvailability.fromJson(Json data) {
    if (data['capacities'] is! List) {
      throw const ParkFailure(
        'Máy chủ chưa cập nhật quản lý sức chứa. Cần áp dụng migration 009–010 trước khi dùng phiên bản này.',
        code: 'BOOKING_SCHEMA_REQUIRED',
      );
    }
    return ReservationAvailability(
      capacities:
          (data['capacities'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
      vehicleConflict:
          data['vehicle_conflict'] == null
              ? null
              : Map<String, dynamic>.from(data['vehicle_conflict'] as Map),
    );
  }
}

class ParkingSnapshot {
  const ParkingSnapshot(this.data);
  final Json data;
  List<Json> rows(String name) =>
      (data[name] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static const empty = ParkingSnapshot({});
}

class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.userId,
    required this.kind,
    required this.payload,
    this.attempts = 0,
    this.state = 'pending',
    this.error,
    this.nextAttempt,
  });
  final String id, userId, kind, state;
  final Json payload;
  final int attempts;
  final String? error;
  final DateTime? nextAttempt;
}
