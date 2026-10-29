// Domain contains no Flutter, persistence, networking or platform dependencies.
typedef Json = Map<String, dynamic>;

class ParkFailure implements Exception {
  const ParkFailure(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
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

class TicketIdentity {
  const TicketIdentity(this.id, this.token);
  final String id, token;
  String get encoded => 'smartpark:v1:$id:$token';
  static TicketIdentity parse(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 4 ||
        parts[0] != 'smartpark' ||
        parts[1] != 'v1' ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(parts[2]) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[3])) {
      throw const ParkFailure('QR SmartPark không hợp lệ.');
    }
    return TicketIdentity(parts[2], parts[3]);
  }
}
