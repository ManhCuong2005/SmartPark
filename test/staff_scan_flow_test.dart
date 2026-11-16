import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpark/presentation/features/staff/automatic_scanner_screen.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'package:smartpark/domain/plate_scanning.dart';
import 'automatic_scanning_test.dart' show TestScanFeedback;
import 'support/test_repository.dart';

class KioskRepository extends TestRepository {
  KioskRepository() : super(staff: true);
  final scans = <Json>[];
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    if (kind == 'kiosk.open') return {'session_id': id, ...payload};
    expect(kind, 'kiosk.scan');
    scans.add(payload);
    return {
      'action': payload['direction'] == 'entry' ? 'entered' : 'exited',
      'booking': {
        ...fixture().rows('bookings').single,
        'status': payload['direction'] == 'entry' ? 'parked' : 'completed',
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final resume in [false, true]) {
    for (final direction in ScanDirection.values) {
      testWidgets(
        'kiosk ${direction.name} ${resume ? 'resumes saved lot and direction' : 'starts after selecting lot and direction'} without manual confirmation',
        (tester) async {
          final backend = KioskRepository();
          final state = ParkController(backend, monitorConnectivity: false);
          addTearDown(state.dispose);
          await state.initialize();
          if (resume) {
            SharedPreferences.setMockInitialValues({
              'kiosk:lot:${state.userId}': state.staffLots.single.id,
              'kiosk:direction:${state.userId}': direction.name,
            });
          }
          final feedback = TestScanFeedback();
          late Future<void> Function(List<String>?) accept;
          await tester.pumpWidget(
            MaterialApp(
              home: StaffScannerScreen(
                repository: state,
                feedbackFactory: () => feedback,
                cameraBuilder: (_, onFrame) {
                  accept = onFrame;
                  return const ColoredBox(color: Colors.black);
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!resume) {
            expect(find.text('Chọn bãi quét'), findsOneWidget);
            await tester.tap(find.text('Test Parking'));
            await tester.pumpAndSettle();
            expect(backend.scans, isEmpty);
            expect(find.text('Chọn chức năng camera'), findsOneWidget);
            await tester.tap(find.text(direction.label));
            await tester.pumpAndSettle();
          }
          expect(find.text('Chụp biển số · AI OCR'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          for (var i = 0; i < 3; i++) {
            await accept(['43A12345']);
          }
          await tester.pumpAndSettle();
          expect(backend.scans, hasLength(1));
          expect(backend.scans.single['lot_id'], state.staffLots.single.id);
          expect(backend.scans.single['direction'], direction.name);
          expect(backend.scans.single['session_id'], isNotEmpty);
          expect(
            find.text(
              direction == ScanDirection.entry
                  ? 'Xe vào hợp lệ'
                  : 'Đã thanh toán · Xe ra hợp lệ',
            ),
            findsOneWidget,
          );
          expect(feedback.chimes, 1);
          expect(
            state.bookings.single['status'],
            direction == ScanDirection.entry ? 'parked' : 'completed',
          );
          expect(backend.queued, isEmpty);
          for (var i = 0; i < 10; i++) {
            await accept(['43A12345']);
          }
          expect(backend.scans, hasLength(1));
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
