import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openLocalDatabase() => DatabaseConnection.delayed(
  Future(() async {
    final opened = await WasmDatabase.open(
      databaseName: 'smartpark',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return opened.resolvedExecutor;
  }),
);
