import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/presentation/features/staff/operational_screens.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class ScanRepository extends TestRepository {
  ScanRepository(this.parked) : super(staff: true, offline: true);
  final bool parked;
  @override
  ParkingSnapshot fixture() {
    final original = super.fixture();
    return ParkingSnapshot({
      ...original.data,
      'bookings': [
        {
          ...original.rows('bookings').single,
          'status': parked ? 'parked' : 'confirmed',
          if (parked)
            'checked_in_at':
                DateTime.now()
                    .subtract(const Duration(minutes: 2))
                    .toUtc()
                    .toIso8601String(),
        },
      ],
    });
  }
}

void main() {
  for (final scenario in ['enter', 'exit', 'cancel', 'invalid_plate']) {
    testWidgets(
      '$scenario returns to the existing scanner only after successful confirmation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        try {
          final backend = ScanRepository(scenario == 'exit');
          final state = ParkController(backend, monitorConnectivity: false);
          addTearDown(state.dispose);
          await state.initialize();
          await tester.pumpWidget(
            MaterialApp(
              initialRoute: '/staff/scan',
              routes: {
                '/': (_) => const Scaffold(body: Text('Staff home')),
                '/staff/scan': (_) => StaffScannerScreen(repository: state),
                '/staff/confirm':
                    (_) => AnimatedBuilder(
                      animation: state,
                      builder:
                          (_, __) => StaffConfirmationScreen(repository: state),
                    ),
              },
            ),
          );
          await tester.pumpAndSettle();
          final dynamic scanner = tester.state(find.byType(StaffScannerScreen));
          final booking = state.bookings.single;
          final pending =
              scanner.open(
                    TicketIdentity(
                      booking['id'] as String,
                      booking['qr_token'] as String,
                    ).encoded,
                  )
                  as Future<void>;
          await tester.pumpAndSettle();
          expect(find.text('Xác nhận vé'), findsOneWidget);
          await tester.enterText(
            find.byType(TextField),
            scenario == 'invalid_plate' ? '43A99999' : '43A12345',
          );
          final button = find.text(
            scenario == 'exit'
                ? 'Xác nhận thu tiền mặt và xe ra'
                : 'Xác nhận xe vào',
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(scenario == 'cancel' ? 'Hủy' : 'Xác nhận').last,
          );
          await tester.pumpAndSettle();
          if (scenario == 'enter' || scenario == 'exit') {
            await pending;
            expect(find.text('Quét mã QR'), findsOneWidget);
            expect(
              tester.state(find.byType(StaffScannerScreen)),
              same(scanner),
            );
            expect(scanner.processing, false);
            expect(state.scannedQr, isNull);
            expect(backend.queued, hasLength(1));
            expect(
              backend.queued.single.kind,
              scenario == 'enter' ? 'staff.check_in' : 'staff.check_out',
            );
          } else {
            expect(find.text('Xác nhận vé'), findsOneWidget);
            expect(backend.queued, isEmpty);
            expect(state.scannedQr, isNotNull);
            if (scenario == 'invalid_plate') {
              expect(find.text('Biển số không khớp vé.'), findsOneWidget);
            }
            tester.state<NavigatorState>(find.byType(Navigator)).pop();
            await tester.pumpAndSettle();
            await pending;
          }
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
