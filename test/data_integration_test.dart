import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartpark/data/local/parking_database.dart';
import 'package:smartpark/data/supabase_parking_repository.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'dart:async';
import 'support/supabase_simulator.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open('winsqlite3.dll'),
      );
    }
  });
  test(
    'availability HTTP contract sends the selected vehicle and parses its private conflict',
    () async {
      final env = await syncEnvironment();
      final from = DateTime.utc(2026, 11, 12, 4, 48),
          until = DateTime.utc(2026, 11, 12, 6, 48);
      env.server.availabilityResponse = {
        'capacities': [
          {'kind': 'car', 'capacity': 1, 'remaining': 1},
        ],
        'vehicle_conflict': {
          'id': 'own-ticket',
          'lot_name': 'Other lot',
          'slot_code': 'A011',
          'status': 'confirmed',
          'starts_at': from.toIso8601String(),
          'ends_at': until.toIso8601String(),
        },
      };
      final result = await env.repo.availability(
        'lot',
        from,
        until,
        vehicleId: 'selected-vehicle',
      );
      expect(env.server.lastAvailabilityParameters, {
        'p_lot_id': 'lot',
        'p_start': from.toIso8601String(),
        'p_end': until.toIso8601String(),
        'p_vehicle_id': 'selected-vehicle',
      });
      expect(result.capacities.single['remaining'], 1);
      expect(result.vehicleConflict!['id'], 'own-ticket');
      env.server.failureStatus = 409;
      env.server.failureCode = '23P01';
      env.server.failureMessage = 'VEHICLE_TIME_CONFLICT';
      await expectLater(
        env.repo.execute('operation', 'booking.create', {}),
        throwsA(
          isA<ParkFailure>()
              .having((e) => e.code, 'code', 'VEHICLE_TIME_CONFLICT')
              .having((e) => e.message, 'message', contains('Xe này đã có vé')),
        ),
      );
    },
  );
  test(
    'missing booking availability migration never falls back to misleading green slots',
    () async {
      final env = await syncEnvironment();
      env.server.availabilityFailureStatus = 404;
      await expectLater(
        env.repo.availability(
          'lot',
          DateTime.now(),
          DateTime.now().add(const Duration(hours: 1)),
          vehicleId: 'vehicle',
        ),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.code,
            'code',
            'BOOKING_SCHEMA_REQUIRED',
          ),
        ),
      );
      expect(env.server.availabilityRequests, 1);
    },
  );
  test(
    'offline editable rejection becomes a durable notice, never a retry queue conflict',
    () async {
      final env = await syncEnvironment();
      await env.repo.enqueue(
        PendingOperation(
          id: 'invalid-edit',
          userId: env.repo.userId!,
          kind: 'vehicle.save',
          payload: const {'id': 'vehicle'},
        ),
      );
      env.server.failureStatus = 400;
      env.server.failureCode = 'P0001';
      await env.repo.synchronize();
      expect(await env.repo.pending(), isEmpty);
      final notice = (await env.repo.rejected()).single;
      expect(notice.id, 'invalid-edit');
      expect(notice.state, 'rejected');
      final requests = env.server.requests;
      await env.repo.synchronize(retryPendingNow: true);
      expect(
        env.server.requests,
        requests,
        reason: 'terminal rejection is never replayed',
      );
      expect(await env.db.rejected('another-user'), isEmpty);
      await env.repo.discard(notice.id);
      expect(await env.repo.rejected(), isEmpty);
    },
  );
  test(
    'old vehicle conflicts migrate to notices without blocking unrelated pending commands',
    () async {
      final env = await syncEnvironment();
      await env.repo.enqueue(
        PendingOperation(
          id: 'old-conflict',
          userId: env.repo.userId!,
          kind: 'vehicle.save',
          payload: const {},
        ),
      );
      await env.db.fail(
        env.repo.userId!,
        'old-conflict',
        'Xe đang được gửi trong bãi.',
        true,
        1,
        DateTime.now(),
      );
      await env.repo.enqueue(
        PendingOperation(
          id: 'read-notices',
          userId: env.repo.userId!,
          kind: 'notifications.read',
          payload: const {},
        ),
      );
      await env.repo.synchronize();
      expect(await env.repo.pending(), isEmpty);
      expect((await env.repo.rejected()).single.id, 'old-conflict');
      expect(env.server.mutations, 1);
    },
  );
  test(
    'Drift persists scoped snapshots, outbox and retries across reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp('smartpark-test-'),
          file = File('${temp.path}/db.sqlite');
      var db = ParkingDatabase(NativeDatabase(file));
      await db.saveSnapshot(
        'user-a',
        const ParkingSnapshot({
          'lots': [
            {'id': 'a'},
          ],
        }),
      );
      await db.enqueue(
        const PendingOperation(
          id: 'one',
          userId: 'user-a',
          kind: 'staff.check_in',
          payload: {'booking_id': 'ticket'},
        ),
      );
      await db.fail('user-a', 'one', 'conflict', true, 1, DateTime.now());
      await db.enqueue(
        const PendingOperation(
          id: 'rejected-edit',
          userId: 'user-a',
          kind: 'vehicle.save',
          payload: {},
        ),
      );
      await db.reject('user-a', 'rejected-edit', 'Xe đang được gửi trong bãi.');
      await db.close();
      db = ParkingDatabase(NativeDatabase(file));
      expect((await db.snapshot('user-a'))!.rows('lots').single['id'], 'a');
      expect(await db.snapshot('user-b'), isNull);
      expect(await db.pending('user-b'), isEmpty);
      expect((await db.pending('user-a')).single.state, 'conflict');
      expect(
        (await db.rejected('user-a')).single.error,
        'Xe đang được gửi trong bãi.',
      );
      expect(await db.rejected('user-b'), isEmpty);
      await db.retry('user-a', 'one');
      expect((await db.pending('user-a')).single.nextAttempt, isNull);
      await db.clearUser('user-b');
      expect((await db.pending('user-a')).length, 1);
      await db.close();
      await temp.delete(recursive: true);
    },
  );
  test(
    'real Supabase HTTP client retries durably and preserves an operation id',
    () async {
      final server = SupabaseSimulator();
      await server.start();
      final client = SupabaseClient(
        server.url,
        'test-publishable',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final db = ParkingDatabase(NativeDatabase.memory()),
          repo = SupabaseParkingRepository(client, db);
      addTearDown(() async {
        await repo.dispose();
        await client.dispose();
        await server.close();
      });
      await client.auth.signInWithPassword(
        email: 'test@example.invalid',
        password: 'test-password',
      );
      final op = PendingOperation(
        id: '40000000-0000-0000-0000-000000000001',
        userId: repo.userId!,
        kind: 'staff.check_in',
        payload: const {'booking_id': 'test'},
      );
      await repo.enqueue(op);
      server.failureStatus = 503;
      await repo.synchronize();
      expect((await repo.pending()).single.attempts, 1);
      expect(server.mutations, 0);
      server.failureStatus = null;
      final requestsBeforeRecovery = server.requests;
      await repo.synchronize();
      expect(
        server.requests,
        requestsBeforeRecovery,
        reason: 'normal retries respect the backoff',
      );
      await repo.synchronize(retryPendingNow: true);
      expect(await repo.pending(), isEmpty);
      expect(server.mutations, 1);
      expect(server.receipts.keys, hasLength(1));
      // Simulate a lost acknowledgement: resend the identical durable command.
      await repo.enqueue(op);
      await repo.synchronize();
      expect(server.mutations, 1);
      expect(await repo.pending(), isEmpty);
    },
  );
  test(
    'server conflicts stop ordered replay and remain available for review',
    () async {
      final server = SupabaseSimulator();
      await server.start();
      final client = SupabaseClient(
        server.url,
        'test-publishable',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repo = SupabaseParkingRepository(
        client,
        ParkingDatabase(NativeDatabase.memory()),
      );
      addTearDown(() async {
        await repo.dispose();
        await client.dispose();
        await server.close();
      });
      await client.auth.signInWithPassword(
        email: 'test@example.invalid',
        password: 'test-password',
      );
      for (final id in ['first', 'second']) {
        await repo.enqueue(
          PendingOperation(
            id: id,
            userId: repo.userId!,
            kind: 'staff.check_in',
            payload: {'booking_id': id},
          ),
        );
      }
      server.failureStatus = 400;
      server.failureCode = 'P0001';
      await repo.synchronize();
      expect((await repo.pending()).first.state, 'conflict');
      expect((await repo.pending()).last.attempts, 0);
      final requests = server.requests;
      await repo.synchronize(retryPendingNow: true);
      expect(
        server.requests,
        requests,
        reason: 'reconnect must not silently reapply a conflict',
      );
      await expectLater(repo.signOut(), throwsA(isA<ParkFailure>()));
    },
  );
  test(
    'a network event automatically drains Drift commands without a manual retry',
    () async {
      final env = await syncEnvironment();
      final events = StreamController<bool>.broadcast();
      final state = ParkController(
        env.repo,
        monitorConnectivity: false,
        connectionChanges: events.stream,
      );
      addTearDown(() async {
        state.dispose();
        await events.close();
      });
      final userId = env.repo.userId!;
      const operationId = '40000000-0000-0000-0000-000000000011';
      await env.repo.enqueue(
        PendingOperation(
          id: operationId,
          userId: userId,
          kind: 'staff.check_in',
          payload: const {'booking_id': 'ticket'},
        ),
      );
      await env.db.fail(
        userId,
        operationId,
        'network error',
        false,
        6,
        DateTime.now().add(const Duration(hours: 1)),
      );
      await env.db.enqueue(
        const PendingOperation(
          id: 'other-account',
          userId: 'other-user',
          kind: 'vehicle.save',
          payload: {},
        ),
      );
      await env.db.fail(
        'other-user',
        'other-account',
        'network error',
        false,
        2,
        DateTime.now().add(const Duration(hours: 1)),
      );
      env.server.snapshotFailureStatus = 503;
      await state.initialize();
      expect(state.online, isFalse);
      expect(env.server.mutations, 0);
      events.add(false);
      await Future<void>.delayed(Duration.zero);
      env.server.snapshotFailureStatus = null;
      events.add(true);
      await waitUntil(() => state.online && state.operations.isEmpty);
      expect(env.server.mutations, 1);
      expect(env.server.receipts.keys, [operationId]);
      expect(
        (await env.db.pending('other-user')).single.nextAttempt,
        isNotNull,
      );
    },
  );

  test(
    'opening the app sends saved commands despite an old retry delay',
    () async {
      final env = await syncEnvironment();
      final state = ParkController(env.repo, monitorConnectivity: false);
      addTearDown(state.dispose);
      const id = '40000000-0000-0000-0000-000000000012';
      await env.repo.enqueue(
        PendingOperation(
          id: id,
          userId: env.repo.userId!,
          kind: 'vehicle.save',
          payload: const {},
        ),
      );
      await env.db.fail(
        env.repo.userId!,
        id,
        'temporary failure',
        false,
        8,
        DateTime.now().add(const Duration(hours: 1)),
      );
      await state.initialize();
      expect(state.operations, isEmpty);
      expect(env.server.mutations, 1);
    },
  );

  test(
    'server recovery on the same Wi-Fi releases delayed pending operations',
    () async {
      final env = await syncEnvironment();
      final state = ParkController(env.repo, monitorConnectivity: false);
      addTearDown(state.dispose);
      const id = '40000000-0000-0000-0000-000000000013';
      await env.repo.enqueue(
        PendingOperation(
          id: id,
          userId: env.repo.userId!,
          kind: 'notifications.read',
          payload: const {},
        ),
      );
      await env.db.fail(
        env.repo.userId!,
        id,
        'temporary failure',
        false,
        8,
        DateTime.now().add(const Duration(hours: 1)),
      );
      env.server.snapshotFailureStatus = 503;
      await state.initialize();
      env.server.snapshotFailureStatus = null;
      // The regular polling path, without a new connection event or manual retry.
      await state.refresh();
      expect(state.operations, isEmpty);
      expect(env.server.mutations, 1);
    },
  );

  test(
    'overlapping reconnect syncs preserve command ids and acknowledge once',
    () async {
      final env = await syncEnvironment();
      const id = '40000000-0000-0000-0000-000000000014';
      await env.repo.enqueue(
        PendingOperation(
          id: id,
          userId: env.repo.userId!,
          kind: 'vehicle.save',
          payload: const {},
        ),
      );
      await Future.wait([
        env.repo.synchronize(retryPendingNow: true),
        env.repo.synchronize(retryPendingNow: true),
      ]);
      expect(await env.repo.pending(), isEmpty);
      expect(env.server.mutations, 1);
      expect(env.server.requests, 1);
    },
  );
}

class QuietSyncRepository extends SupabaseParkingRepository {
  QuietSyncRepository(super.client, super.local);
  Future<void>? closing;
  @override
  void subscribe() {} // Realtime isn't part of these local HTTP tests.
  @override
  Future<void> dispose() => closing ??= super.dispose();
}

Future<
  ({SupabaseSimulator server, ParkingDatabase db, QuietSyncRepository repo})
>
syncEnvironment() async {
  final server = SupabaseSimulator();
  await server.start();
  final client = SupabaseClient(
    server.url,
    'test-publishable',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await client.auth.signInWithPassword(
    email: 'test@example.invalid',
    password: 'test-password',
  );
  final db = ParkingDatabase(NativeDatabase.memory());
  final repo = QuietSyncRepository(client, db);
  addTearDown(() async {
    await repo.dispose();
    await client.dispose();
    await server.close();
  });
  return (server: server, db: db, repo: repo);
}

Future<void> waitUntil(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Automatic synchronization did not finish');
}
