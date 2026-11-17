import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpark/data/scan_feedback.dart';
import 'package:smartpark/domain/models.dart';
import 'package:smartpark/domain/plate_scanning.dart';
import 'package:smartpark/presentation/automatic_scan_controller.dart';

class TestScanFeedback implements ScanFeedback {
  final spoken = <String>[];
  int chimes = 0;
  Completer<void>? speaking;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> speak(String message) async {
    spoken.add(message);
    await speaking?.future;
  }

  @override
  Future<void> success() async {
    chimes++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('joins aligned motorcycle rows and ignores text outside the guide', () {
    expect(
      scanCandidates(const [
        PlateLine('59-X1', .35, .40, .65, .46),
        PlateLine('123.45', .34, .49, .66, .55),
        PlateLine('43A-999.99', .1, .05, .8, .1),
      ]),
      ['59X112345'],
    );
    expect(
      scanCandidates(const [
        PlateLine('59-X1', .10, .4, .35, .46),
        PlateLine('123.45', .65, .49, .9, .55),
      ]),
      isEmpty,
    );
    expect(
      scanCandidates(const [PlateLine('43O-12I.45', .3, .4, .7, .5)]),
      isEmpty,
    );
  });
  test(
    'selects the visibly closer plate, rejects distant text and waits on equal targets',
    () {
      const near = PlateLine('43A-123.45', .2, .46, .65, .55);
      const far = PlateLine('43A-999.99', .6, .28, .8, .30);
      expect(scanCandidates([far]), isEmpty);
      expect(scanCandidates([near, far]), ['43A12345']);
      const second = PlateLine('43B-678.90', .4, .28, .7, .33);
      expect(scanCandidates([near, second]), ['43A12345']);
      const equal = PlateLine('43B-678.90', .4, .28, .85, .37);
      expect(
        scanCandidates([near, equal]),
        unorderedEquals(['43A12345', '43B67890']),
      );
      expect(
        scanCandidates([const PlateLine('43A-123.45', .05, .4, .5, .5)]),
        isEmpty,
      );
    },
  );
  test(
    'two-row plate size uses character height instead of total rectangle height',
    () {
      expect(
        scanCandidates(const [
          PlateLine('59-X1', .3, .40, .65, .46),
          PlateLine('123.45', .3, .49, .65, .55),
          PlateLine('43B-678.90', .1, .28, .4, .32),
        ]),
        ['59X112345'],
      );
      expect(
        scanCandidates(const [
          PlateLine('59-X1', .3, .40, .5, .42),
          PlateLine('123.45', .3, .45, .5, .47),
        ]),
        isEmpty,
      );
    },
  );
  test(
    'alternating two processed vehicles cannot clear each other duplicate protection',
    () {
      final consensus = PlateConsensus();
      var now = DateTime.utc(2026);
      consensus.block('43A12345', now);
      consensus.block('43B67890', now);
      for (var i = 0; i < 40; i++) {
        now = now.add(const Duration(milliseconds: 250));
        expect(
          consensus.observe([i.isEven ? '43A12345' : '43B67890'], now),
          isNull,
        );
      }
    },
  );
  test(
    'slow browser OCR still confirms three frames but stale observations expire',
    () {
      final consensus = PlateConsensus();
      var now = DateTime.utc(2026);
      expect(consensus.observe(['43A12345'], now), isNull);
      now = now.add(const Duration(seconds: 3));
      expect(consensus.observe(['43A12345'], now), isNull);
      now = now.add(const Duration(seconds: 3));
      expect(consensus.observe(['43A12345'], now), '43A12345');
      now = now.add(const Duration(seconds: 8));
      expect(consensus.observe(['43A12345'], now), isNull);
    },
  );
  test(
    'requires three matching recent observations; multiple plates cannot decide',
    () {
      final consensus = PlateConsensus();
      var now = DateTime.utc(2026);
      String? observe(List<String> p) {
        now = now.add(const Duration(milliseconds: 250));
        return consensus.observe(p, now);
      }

      expect(observe(['43A12345']), isNull);
      expect(observe(['43A12345', '43A99999']), isNull);
      expect(observe(['43A99999']), isNull);
      expect(observe(['43A12345']), isNull);
      expect(observe(['43A12345']), '43A12345');
      consensus.block('43A12345', now);
      for (var i = 0; i < 160; i++) {
        expect(observe(['43A12345']), isNull);
      }
      for (var i = 0; i < 10; i++) {
        observe([]);
      }
      expect(observe(['43A12345']), isNull);
      expect(observe(['43A12345']), isNull);
      expect(observe(['43A12345']), '43A12345');
    },
  );
  test(
    'unusable frames reset consensus rather than confirming noisy OCR',
    () async {
      var calls = 0;
      final feedback = TestScanFeedback();
      final scanner = AutomaticScanController(
        execute: (_, __) async {
          calls++;
          return {'action': 'entered'};
        },
        feedback: feedback,
        preferences: await SharedPreferences.getInstance(),
        storageKey: 'scan',
      );
      addTearDown(scanner.dispose);
      await scanner.acceptFrame(['43A12345']);
      await scanner.acceptFrame(['43A12345']);
      await scanner.acceptFrame(null);
      await scanner.acceptFrame(['43A12345']);
      expect(calls, 0);
      await scanner.acceptFrame(['43A12345']);
      await scanner.acceptFrame(['43A12345']);
      expect(calls, 1);
      expect(feedback.chimes, 1);
      for (var i = 0; i < 10; i++) {
        await scanner.acceptFrame(['43A12345']);
      }
      expect(calls, 1);
      expect(scanner.status, 'Đã xử lý biển số này · Chờ xe tiếp theo');
    },
  );
  test(
    'rejection waits for speech completion and then five full seconds',
    () async {
      var now = DateTime.utc(2026), calls = 0;
      final feedback = TestScanFeedback()..speaking = Completer<void>();
      final scanner = AutomaticScanController(
        execute: (_, __) async {
          calls++;
          throw const ParkFailure('No ticket', code: 'VALID_TICKET_REQUIRED');
        },
        feedback: feedback,
        preferences: await SharedPreferences.getInstance(),
        storageKey: 'scan',
        clock: () => now,
      );
      addTearDown(scanner.dispose);
      await scanner.acceptFrame(['43A12345']);
      await scanner.acceptFrame(['43A12345']);
      final processing = scanner.acceptFrame(['43A12345']);
      await Future<void>.delayed(Duration.zero);
      expect(
        feedback.spoken.single,
        'Xe chưa đăng ký đỗ online hoặc quét nhầm, vui lòng thử lại',
      );
      now = now.add(const Duration(seconds: 20));
      await scanner.acceptFrame(['43A12345']);
      expect(calls, 1);
      expect(scanner.retryAfter, isNull);
      feedback.speaking!.complete();
      await processing;
      expect(scanner.retryAfter, now.add(const Duration(seconds: 5)));
      now = now.add(const Duration(milliseconds: 4999));
      for (var i = 0; i < 3; i++) {
        await scanner.acceptFrame(['43A12345']);
      }
      expect(calls, 1);
      now = now.add(const Duration(milliseconds: 1));
      for (var i = 0; i < 3; i++) {
        await scanner.acceptFrame(['43A12345']);
      }
      expect(calls, 2);
      expect(feedback.chimes, 0);
    },
  );
  test(
    'unknown server outcome survives restart with the identical operation ID',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final ids = <String>[];
      final first = AutomaticScanController(
        execute: (id, _) async {
          ids.add(id);
          throw const ParkFailure('Timeout', retryable: true);
        },
        feedback: TestScanFeedback(),
        preferences: preferences,
        storageKey: 'scan',
      );
      for (var i = 0; i < 3; i++) {
        await first.acceptFrame(['43A12345']);
      }
      expect(first.hasPending, true);
      expect(jsonDecode(preferences.getString('scan')!)['id'], ids.single);
      first.dispose();
      final feedback = TestScanFeedback();
      final second = AutomaticScanController(
        execute: (id, plate) async {
          ids.add(id);
          expect(plate, '43A12345');
          return {'action': 'entered'};
        },
        feedback: feedback,
        preferences: preferences,
        storageKey: 'scan',
      )..restore();
      addTearDown(second.dispose);
      await second.acceptFrame([]);
      expect(ids, [ids.first, ids.first]);
      expect(second.hasPending, false);
      expect(feedback.chimes, 1);
      final third = AutomaticScanController(
        execute: (_, __) async => fail('Repeated standing vehicle'),
        feedback: TestScanFeedback(),
        preferences: preferences,
        storageKey: 'scan',
      )..restore();
      addTearDown(third.dispose);
      for (var i = 0; i < 3; i++) {
        await third.acceptFrame(['43A12345']);
      }
    },
  );
  test(
    'overdue insufficient funds speaks the requested message without a chime',
    () async {
      final feedback = TestScanFeedback();
      final scanner = AutomaticScanController(
        execute:
            (_, __) async =>
                throw const ParkFailure(
                  'Insufficient',
                  code: 'OVERDUE_INSUFFICIENT_BALANCE',
                ),
        feedback: feedback,
        preferences: await SharedPreferences.getInstance(),
        storageKey: 'scan',
      );
      addTearDown(scanner.dispose);
      for (var i = 0; i < 3; i++) {
        await scanner.acceptFrame(['43A12345']);
      }
      expect(
        feedback.spoken.single,
        'Bạn đã gửi quá giờ, và số dư không đủ, vui lòng nạp thêm tiền',
      );
      expect(feedback.chimes, 0);
      expect(scanner.hasPending, false);
    },
  );
  test(
    'account switch during an unknown server outcome retains the durable request silently',
    () async {
      final reply = Completer<Json>();
      final preferences = await SharedPreferences.getInstance();
      final feedback = TestScanFeedback();
      final scanner = AutomaticScanController(
        execute: (_, __) => reply.future,
        feedback: feedback,
        preferences: preferences,
        storageKey: 'scan',
      );
      await scanner.acceptFrame(['43A12345']);
      await scanner.acceptFrame(['43A12345']);
      final processing = scanner.acceptFrame(['43A12345']);
      await Future<void>.delayed(Duration.zero);
      scanner.dispose();
      reply.completeError(
        const ParkFailure(
          'Account changed',
          code: 'ACCOUNT_CHANGED',
          retryable: true,
        ),
      );
      await processing;
      expect(preferences.getString('scan'), isNotNull);
      expect(feedback.spoken, isEmpty);
      expect(feedback.chimes, 0);
    },
  );
}
