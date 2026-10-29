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
  Future<void>? _syncing;
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
  Future<List<Json>> availability(
    String lotId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final rows =
          await client
                  .rpc(
                    'slot_availability',
                    params: {
                      'p_lot_id': lotId,
                      'p_start': start.toUtc().toIso8601String(),
                      'p_end': end.toUtc().toIso8601String(),
                    },
                  )
                  .timeout(const Duration(seconds: 12))
              as List;
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
  Future<void> discard(String id) async {
    if (userId != null) await local.remove(userId!, id);
  }

  @override
  Future<void> retry(String id) async {
    if (userId != null) await local.retry(userId!, id);
  }

  @override
  Future<void> synchronize() =>
      _syncing ??= _flush().whenComplete(() => _syncing = null);
  Future<void> _flush() async {
    final id = userId;
    if (id == null) return;
    for (final op in await local.pending(id)) {
      if (userId != id || _disposed) break;
      // Preserve command order. A conflict must be reviewed before later events.
      if (op.state == 'conflict' ||
          (op.nextAttempt?.isAfter(DateTime.now()) ?? false)) {
        break;
      }
      try {
        await execute(op.id, op.kind, op.payload);
        await local.remove(id, op.id);
      } on ParkFailure catch (e) {
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
      return ParkFailure(
        backendMessage(
          error.code == 'P0001' ? error.message : error.code ?? error.message,
        ),
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
