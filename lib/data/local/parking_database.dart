import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models.dart';
import 'connection.dart';

/// Drift custom SQL keeps a small durable snapshot + command outbox. All access
/// is partitioned by authenticated user, including failures and retry metadata.
class ParkingDatabase extends GeneratedDatabase {
  ParkingDatabase([QueryExecutor? executor])
    : super(executor ?? openLocalDatabase());
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE snapshots (user_id TEXT PRIMARY KEY, data TEXT NOT NULL)',
      );
      await customStatement(
        '''CREATE TABLE outbox (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
      kind TEXT NOT NULL, payload TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
      state TEXT NOT NULL DEFAULT 'pending', error TEXT, next_attempt TEXT,
      sequence INTEGER NOT NULL)''',
      );
      await customStatement(
        'CREATE INDEX outbox_user ON outbox(user_id,sequence)',
      );
    },
  );
  Future<void> saveSnapshot(String userId, ParkingSnapshot snapshot) =>
      customStatement('INSERT OR REPLACE INTO snapshots VALUES (?,?)', [
        userId,
        jsonEncode(snapshot.data),
      ]);
  Future<ParkingSnapshot?> snapshot(String userId) async {
    final rows =
        await customSelect(
          'SELECT data FROM snapshots WHERE user_id=?',
          variables: [Variable.withString(userId)],
        ).get();
    return rows.isEmpty
        ? null
        : ParkingSnapshot(jsonDecode(rows.first.read<String>('data')) as Json);
  }

  Future<void> enqueue(PendingOperation op) => customStatement(
    '''INSERT INTO outbox
    (id,user_id,kind,payload,attempts,state,sequence) VALUES (?,?,?,?,0,'pending',?)''',
    [
      op.id,
      op.userId,
      op.kind,
      jsonEncode(op.payload),
      DateTime.now().microsecondsSinceEpoch,
    ],
  );
  Future<List<PendingOperation>> pending(String userId) async {
    final rows =
        await customSelect(
          'SELECT * FROM outbox WHERE user_id=? ORDER BY sequence,id',
          variables: [Variable.withString(userId)],
        ).get();
    return rows
        .map(
          (r) => PendingOperation(
            id: r.read('id'),
            userId: r.read('user_id'),
            kind: r.read('kind'),
            payload: jsonDecode(r.read<String>('payload')) as Json,
            attempts: r.read('attempts'),
            state: r.read('state'),
            error: r.readNullable('error'),
            nextAttempt: DateTime.tryParse(
              r.readNullable<String>('next_attempt') ?? '',
            ),
          ),
        )
        .toList();
  }

  Future<void> remove(String userId, String id) => customStatement(
    'DELETE FROM outbox WHERE id=? AND user_id=?',
    [id, userId],
  );
  Future<void> fail(
    String userId,
    String id,
    String error,
    bool conflict,
    int attempts,
    DateTime next,
  ) => customStatement(
    'UPDATE outbox SET state=?,error=?,attempts=?,next_attempt=? WHERE id=? AND user_id=?',
    [
      conflict ? 'conflict' : 'pending',
      error,
      attempts,
      next.toUtc().toIso8601String(),
      id,
      userId,
    ],
  );
  Future<void> retry(String userId, String id) => customStatement(
    "UPDATE outbox SET state='pending',next_attempt=NULL,error=NULL WHERE id=? AND user_id=?",
    [id, userId],
  );
  Future<void> clearUser(String userId) async {
    await customStatement('DELETE FROM snapshots WHERE user_id=?', [userId]);
    await customStatement('DELETE FROM outbox WHERE user_id=?', [userId]);
  }
}
