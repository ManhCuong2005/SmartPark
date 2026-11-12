import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';
import '../domain/parking_repository.dart';
import '../domain/parking_rules.dart';
import 'local/parking_database.dart';

class SupabaseParkingRepository implements ParkingRepository {
  SupabaseParkingRepository(this.client, this.local);
  final SupabaseClient client;
  final ParkingDatabase local;
  final _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  Future<bool>? _syncing;
  String? _retrySyncUser;
  bool _disposed = false;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  String? get email => client.auth.currentUser?.email;
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});
  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'phone': phone.trim()},
    );
    return response.session != null;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email.trim());
  @override
  Future<void> signOut() async {
    if ((await pending()).isNotEmpty) {
      throw const ParkFailure(
        'Còn thao tác chưa đồng bộ. Hãy xử lý hàng đợi trước khi đăng xuất.',
      );
    }
    final id = userId;
    await client.auth.signOut(scope: SignOutScope.local);
    if (id != null) await local.clearUser(id);
    if (_channel != null) await client.removeChannel(_channel!);
    _channel = null;
  }

  @override
  Future<ParkingSnapshot?> cachedSnapshot() async =>
      userId == null ? null : local.snapshot(userId!);
  @override
  Future<ParkingSnapshot> refresh() async {
    final id = userId;
    if (id == null) return ParkingSnapshot.empty;
    try {
      final data = Map<String, dynamic>.from(
        await client.rpc('park_snapshot').timeout(const Duration(seconds: 12))
            as Map,
      );
      final snapshot = ParkingSnapshot(data);
      // Never store a response under a different account after a session switch.
      if (userId == id) await local.saveSnapshot(id, snapshot);
      return snapshot;
    } catch (e) {
      throw translate(e);
    }
  }

  @override
  Future<ReservationAvailability> availability(
    String lotId,
    DateTime start,
    DateTime end, {
    String? vehicleId,
  }) async {
    try {
      final rows =
          await client
                  .rpc(
                    'booking_availability',
                    params: {
                      'p_lot_id': lotId,
                      'p_start': start.toUtc().toIso8601String(),
                      'p_end': end.toUtc().toIso8601String(),
                      'p_vehicle_id': vehicleId,
                    },
                  )
                  .timeout(const Duration(seconds: 12))
              as Map;
      return ReservationAvailability.fromJson(Map<String, dynamic>.from(rows));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw const ParkFailure(
          'Máy chủ chưa cập nhật kiểm tra lịch xe. Cần áp dụng migration 006 trên Supabase.',
          code: 'BOOKING_SCHEMA_REQUIRED',
        );
      }
      throw translate(e);
    } catch (e) {
      throw translate(e);
    }
  }

  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    try {
      return Map<String, dynamic>.from(
        await client
                .rpc(
                  'apply_operation',
                  params: {
                    'p_operation_id': id,
                    'p_kind': kind,
                    'p_payload': payload,
                  },
                )
                .timeout(const Duration(seconds: 12))
            as Map,
      );
    } catch (e) {
      throw translate(e);
    }
  }

  @override
  Future<void> enqueue(PendingOperation operation) async {
    if (userId == null || operation.userId != userId) {
      throw const ParkFailure('Vui lòng đăng nhập lại.');
    }
    // Booking creation is deliberately online-only: no optimistic success ticket.
    if (![
      'staff.check_in',
      'staff.check_out',
      'vehicle.save',
      'notifications.read',
    ].contains(operation.kind)) {
      throw const ParkFailure('Thao tác này cần máy chủ xác nhận trực tuyến.');
    }
    await local.enqueue(operation);
  }

  @override
  Future<List<PendingOperation>> pending() async =>
      userId == null ? [] : local.pending(userId!);
  @override
  Future<List<PendingOperation>> rejected() async =>
      userId == null ? [] : local.rejected(userId!);
  @override
  Future<void> discard(String id) async {
    if (userId != null) await local.remove(userId!, id);
  }

  @override
  Future<void> retry(String id) async {
    if (userId != null) await local.retry(userId!, id);
  }

  @override
  Future<bool> synchronize({bool retryPendingNow = false}) {
    if (_disposed) return Future.value(false);
    if (retryPendingNow) _retrySyncUser = userId;
    return _syncing ??= _flushRequested().whenComplete(() => _syncing = null);
  }

  Future<bool> _flushRequested() async {
    var acknowledged = false;
    do {
      final retryUser = _retrySyncUser;
      _retrySyncUser = null;
      if (retryUser != null && retryUser == userId) {
        await local.clearRetryDelay(retryUser);
      }
      acknowledged = await _flush() || acknowledged;
    } while (_retrySyncUser != null && !_disposed);
    return acknowledged;
  }

  Future<bool> _flush() async {
    final id = userId;
    if (id == null) return false;
    var acknowledged = false;
    for (final op in await local.pending(id)) {
      if (userId != id || _disposed) break;
      final editable =
          op.kind == 'vehicle.save' || op.kind == 'notifications.read';
      if (editable && op.state == 'conflict') {
        // Upgrade old editable-data conflicts to terminal notices. Parking
        // observations remain reviewable conflicts so physical events are kept.
        await local.reject(
          id,
          op.id,
          op.error ?? 'Máy chủ không chấp nhận thay đổi.',
        );
        if (!_disposed) _changes.add(null);
        continue;
      }
      // Preserve command order. A conflict must be reviewed before later events.
      if (op.state == 'conflict' ||
          (op.nextAttempt?.isAfter(DateTime.now()) ?? false)) {
        break;
      }
      try {
        await execute(op.id, op.kind, op.payload);
        await local.remove(id, op.id);
        acknowledged = true;
      } on ParkFailure catch (e) {
        if (!e.retryable && editable) {
          await local.reject(id, op.id, e.message);
          if (!_disposed) _changes.add(null);
          continue;
        }
        await local.fail(
          id,
          op.id,
          e.message,
          !e.retryable,
          op.attempts + 1,
          DateTime.now().add(retryDelay(op.attempts)),
        );
        if (!e.retryable && !_disposed) _changes.add(null);
        break;
      }
    }
    return acknowledged;
  }

  @override
  void subscribe() {
    if (userId == null) return;
    if (_channel != null) unawaited(client.removeChannel(_channel!));
    _channel = client.channel('parking:${userId!}');
    for (final table in [
      'parking_lots',
      'parking_slots',
      'lot_staff',
      'vehicles',
      'bookings',
      'payments',
      'notifications',
      'favorites',
    ]) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          if (!_disposed) _changes.add(null);
        },
      );
    }
    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed && !_disposed) {
        _changes.add(null);
      }
    });
  }

  static ParkFailure translate(Object error) {
    if (error is ParkFailure) return error;
    if (error is PostgrestException) {
      if (error.code == 'PGRST202' || error.code == '42P01') {
        return const ParkFailure(
          'Chưa có schema SmartPark. Hãy chạy migration trong Supabase SQL Editor.',
        );
      }
      final code =
          error.code == 'P0001' ||
                  [
                    'VEHICLE_TIME_CONFLICT',
                    'SLOT_TIME_CONFLICT',
                  ].contains(error.message)
              ? error.message
              : error.code == '23P01' &&
                  error.message.contains('bookings_vehicle_no_overlap')
              ? 'VEHICLE_TIME_CONFLICT'
              : error.code ?? error.message;
      return ParkFailure(
        backendMessage(code),
        code: code,
        retryable: isTransientCode(error.code),
      );
    }
    if (error is AuthException) return ParkFailure(error.message);
    return const ParkFailure(
      'Chưa kết nối được máy chủ. Dữ liệu gần nhất vẫn được lưu trên thiết bị.',
      retryable: true,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    if (_channel != null) await client.removeChannel(_channel!);
    await _changes.close();
    await local.close();
  }
}
