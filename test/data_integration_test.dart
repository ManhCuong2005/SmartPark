import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartpark/data/local/parking_database.dart';
import 'package:smartpark/data/supabase_parking_repository.dart';
import 'package:smartpark/domain/models.dart';
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
      await db.close();
      db = ParkingDatabase(NativeDatabase(file));
      expect((await db.snapshot('user-a'))!.rows('lots').single['id'], 'a');
      expect(await db.snapshot('user-b'), isNull);
      expect(await db.pending('user-b'), isEmpty);
      expect((await db.pending('user-a')).single.state, 'conflict');
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
      await repo.retry(op.id);
      await repo.synchronize();
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
      await repo.synchronize();
      expect(server.requests, requests);
      await expectLater(repo.signOut(), throwsA(isA<ParkFailure>()));
    },
  );
}
