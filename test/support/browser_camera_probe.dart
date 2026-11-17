// Browser integration target only; never used by the shipped app.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:smartpark/data/scan_feedback.dart';
import 'package:smartpark/presentation/features/staff/automatic_scanner_screen.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'test_repository.dart';

class _Feedback implements ScanFeedback {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> speak(String message) async {}
  @override
  Future<void> success() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Repository extends TestRepository {
  _Repository() : super(staff: true);
  @override
  Future<Json> execute(String id, String kind, Json payload) async {
    if (kind == 'kiosk.open') return {'session_id': id, ...payload};
    if (kind != 'kiosk.scan') throw StateError('Unexpected command: $kind');
    debugPrint('KIOSK_SCAN:${jsonEncode(payload)}');
    return {
      'action': payload['direction'] == 'entry' ? 'entered' : 'exited',
      'booking': {
        ...fixture().rows('bookings').single,
        'status': payload['direction'] == 'entry' ? 'parked' : 'completed',
      },
    };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  final state = ParkController(_Repository(), monitorConnectivity: false);
  await state.initialize();
  runApp(
    MaterialApp(
      home: StaffScannerScreen(
        repository: state,
        feedbackFactory: _Feedback.new,
      ),
    ),
  );
}
