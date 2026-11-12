import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'package:smartpark/presentation/sync_queue_screen.dart';
import 'package:smartpark/core/theme/park_theme.dart';
import 'support/test_repository.dart';

class AutoSyncRepository extends TestRepository {
  AutoSyncRepository() : super(offline: true);
  int acknowledged = 0;
  bool delayPending = false;
  Completer<ParkingSnapshot>? snapshotGate;
  @override
  Future<ParkingSnapshot> refresh() => snapshotGate?.future ?? super.refresh();
  @override
  Future<bool> synchronize({bool retryPendingNow = false}) async {
    if (offline || (delayPending && !retryPendingNow)) return false;
    final hadPending = queued.isNotEmpty;
    acknowledged += queued.length;
    queued.clear();
    return hadPending;
  }
}

void seedPending(AutoSyncRepository backend) => backend.queued.add(
  PendingOperation(
    id: 'pending-command',
    userId: backend.account,
    kind: 'staff.check_in',
    payload: const {},
  ),
);

void main() {
  testWidgets('periodic checks recover Internet without a connectivity event', (
    tester,
  ) async {
    final backend = AutoSyncRepository();
    seedPending(backend);
    final events = StreamController<bool>.broadcast();
    final state = ParkController(backend, connectionChanges: events.stream);
    try {
      await state.initialize();
      backend.offline = false;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(state.operations, isEmpty);
      expect(backend.acknowledged, 1);
    } finally {
      state.dispose();
      await events.close();
    }
  });

  testWidgets(
    'resume automatically flushes pending commands and paused polling stops',
    (tester) async {
      final backend = AutoSyncRepository();
      seedPending(backend);
      final events = StreamController<bool>.broadcast();
      final state = ParkController(backend, connectionChanges: events.stream);
      try {
        await state.initialize();
        state.didChangeAppLifecycleState(AppLifecycleState.paused);
        backend.offline = false;
        await tester.pump(const Duration(minutes: 1));
        expect(backend.acknowledged, 0);
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(state.operations, isEmpty);
        expect(backend.acknowledged, 1);
      } finally {
        state.dispose();
        await events.close();
      }
    },
  );

  testWidgets('resume event is retained while another refresh is in flight', (
    tester,
  ) async {
    final backend = AutoSyncRepository()..offline = false;
    final state = ParkController(backend, monitorConnectivity: false);
    addTearDown(state.dispose);
    await state.initialize();
    seedPending(backend);
    backend.delayPending = true;
    final gate = Completer<ParkingSnapshot>();
    backend.snapshotGate = gate;
    final current = state.refresh();
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    backend.snapshotGate = null;
    gate.complete(backend.fixture());
    await current;
    expect(state.operations, isEmpty);
    expect(backend.acknowledged, 1);
  });

  testWidgets(
    'queue explains automatic sending and has no routine manual sync button',
    (tester) async {
      final backend = AutoSyncRepository();
      seedPending(backend);
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: SyncQueueScreen(repository: state),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đồng bộ tự động'), findsOneWidget);
      expect(find.text('Sẽ tự động gửi lại khi có kết nối'), findsOneWidget);
      expect(find.text('Xác nhận xe vào bãi'), findsOneWidget);
      expect(find.text('Đồng bộ ngay'), findsNothing);
      expect(find.text('Thử lại cùng mã'), findsNothing);
      expect(find.text('Bỏ thao tác'), findsNothing);
    },
  );
}
