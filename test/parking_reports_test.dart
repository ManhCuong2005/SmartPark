import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/features/parking/parking_reports_screen.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class ReportsRepository extends TestRepository {
  ReportsRepository({super.staff});
  final reports = <Json>[];
  final submissions = <({String id, String kind, Json payload})>[];
  bool loseAck = false;
  @override
  ParkingSnapshot fixture() =>
      ParkingSnapshot({...super.fixture().data, 'reports': reports});
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    submissions.add((id: id, kind: kind, payload: Map.of(payload)));
    if (loseAck) {
      loseAck = false;
      throw const ParkFailure('Lost acknowledgement', retryable: true);
    }
    if (kind == 'report.create') {
      reports.add({
        ...payload,
        'status': 'open',
        'version': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    if (kind == 'report.progress') {
      reports[0] = {...reports[0], 'status': payload['status'], 'version': 2};
    }
    return {'ok': true};
  }
}

void main() {
  testWidgets(
    'report validates input and preserves the command ID on a lost response',
    (tester) async {
      final backend = ReportsRepository();
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, __) => ParkingReportsScreen(repository: state),
          ),
        ),
      );
      final send = find.text('Xác nhận biển số và gửi báo cáo');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(backend.submissions, isEmpty);
      await tester.enterText(find.byType(TextField).first, '43a-123.45');
      await tester.enterText(find.byType(TextField).last, 'Chắn lối đi');
      for (var attempt = 0; attempt < 2; attempt++) {
        backend.loseAck = attempt == 0;
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận').last);
        await tester.pumpAndSettle();
      }
      expect(backend.submissions, hasLength(2));
      expect(backend.submissions.first.id, backend.submissions.last.id);
      expect(
        backend.submissions.first.payload,
        backend.submissions.last.payload,
      );
      expect(backend.submissions.last.payload['plate'], '43A12345');
      expect(find.text('Mới gửi'), findsOneWidget);
      expect(state.operations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('assigned staff can resolve and sees the refreshed status', (
    tester,
  ) async {
    final backend = ReportsRepository(staff: true);
    backend.reports.add({
      'id': 'report',
      'lot_id': backend.fixture().rows('lots').first['id'],
      'plate': '43A12345',
      'description': 'Chắn lối',
      'assigned_to': backend.account,
      'status': 'assigned',
      'version': 1,
    });
    final state = ParkController(backend, monitorConnectivity: false);
    addTearDown(state.dispose);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, __) => ParkingReportsScreen(repository: state),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Đã giải quyết'));
    await tester.tap(find.text('Đã giải quyết'));
    await tester.pumpAndSettle();
    expect(backend.submissions.single.kind, 'report.progress');
    expect(backend.submissions.single.payload, {
      'report_id': 'report',
      'expected_version': 1,
      'status': 'resolved',
    });
    expect(find.text('Đã giải quyết'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
