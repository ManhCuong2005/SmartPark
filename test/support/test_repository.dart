// Test fixtures only; production contains no mock repository or sample records.
import 'dart:async';
import 'package:smartpark/domain/models.dart';
import 'package:smartpark/domain/parking_repository.dart';

class TestRepository implements ParkingRepository {
  TestRepository({
    this.loggedIn = true,
    this.offline = false,
    this.staff = false,
  });
  bool loggedIn, offline, staff;
  int executions = 0;
  final queued = <PendingOperation>[];
  String get account => '10000000-0000-0000-0000-000000000001';
  @override
  String? get userId => loggedIn ? account : null;
  @override
  String? get email => loggedIn ? 'test@example.invalid' : null;
  @override
  Stream<void> get authChanges => const Stream.empty();
  @override
  Stream<void> get changes => const Stream.empty();
  ParkingSnapshot fixture() {
    final now = DateTime.now();
    return ParkingSnapshot({
      'server_time': now.toIso8601String(),
      'profiles': [
        {
          'id': account,
          'name': 'Test User',
          'phone': '',
          'role': staff ? 'staff' : 'customer',
        },
      ],
      'lots': [
        {
          'id': '20000000-0000-0000-0000-000000000001',
          'name': 'Test Parking',
          'area': 'Test area',
          'owner_id': 'owner',
          'car_rate': 15000,
          'motorcycle_rate': 5000,
          'free_minutes': 0,
          'version': 1,
        },
      ],
      'slots': [
        {
          'id': '30000000-0000-0000-0000-000000000001',
          'lot_id': '20000000-0000-0000-0000-000000000001',
          'code': 'A001',
          'enabled': true,
          'occupied': false,
        },
      ],
      'memberships':
          staff
              ? [
                {
                  'lot_id': '20000000-0000-0000-0000-000000000001',
                  'user_id': account,
                  'active': true,
                },
              ]
              : [],
      'vehicles': [
        {
          'id': '50000000-0000-0000-0000-000000000001',
          'user_id': account,
          'label': 'Test car',
          'plate': '43A12345',
          'kind': 'car',
          'is_default': true,
          'version': 1,
        },
      ],
      'bookings': [
        {
          'id': '60000000-0000-0000-0000-000000000001',
          'customer_id': account,
          'lot_id': '20000000-0000-0000-0000-000000000001',
          'slot_id': '30000000-0000-0000-0000-000000000001',
          'plate': '43A12345',
          'status': 'confirmed',
          'starts_at':
              now.add(const Duration(minutes: 5)).toUtc().toIso8601String(),
          'ends_at':
              now.add(const Duration(hours: 2)).toUtc().toIso8601String(),
          'qr_token': 'a' * 64,
          'hourly_rate': 15000,
          'free_minutes': 0,
          'amount': 0,
          'version': 1,
        },
      ],
      'payments': [],
      'notifications': [],
    });
  }

  @override
  Future<ParkingSnapshot?> cachedSnapshot() async =>
      loggedIn ? fixture() : null;
  @override
  Future<ParkingSnapshot> refresh() async {
    if (offline) throw const ParkFailure('Offline', retryable: true);
    return fixture();
  }

  @override
  Future<List<Json>> availability(
    String lotId,
    DateTime start,
    DateTime end,
  ) async => fixture().rows('slots');
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    executions++;
    if (offline) throw const ParkFailure('Offline', retryable: true);
    if (kind == 'booking.create') {
      return {...fixture().rows('bookings').first, ...payload};
    }
    return {};
  }

  @override
  Future<void> enqueue(PendingOperation operation) async {
    queued.add(operation);
  }

  @override
  Future<List<PendingOperation>> pending() async => List.of(queued);
  @override
  Future<void> retry(String id) async {}
  @override
  Future<void> discard(String id) async {
    queued.removeWhere((o) => o.id == id);
  }

  @override
  Future<void> synchronize() async {}
  @override
  Future<void> signIn(String email, String password) async {
    loggedIn = true;
  }

  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String phone,
  ) async => false;
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async {
    loggedIn = false;
  }

  @override
  void subscribe() {}
  @override
  Future<void> dispose() async {}
}
