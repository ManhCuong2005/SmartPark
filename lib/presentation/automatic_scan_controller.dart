import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/scan_feedback.dart';
import '../domain/models.dart';
import '../domain/plate_scanning.dart';

class AutomaticScanController extends ChangeNotifier {
  AutomaticScanController({
    required this.execute,
    required this.feedback,
    required this.preferences,
    required this.storageKey,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Future<Json> Function(String operationId, String plate) execute;
  final ScanFeedback feedback;
  final SharedPreferences preferences;
  final String storageKey;
  final DateTime Function() _clock;
  final _consensus = PlateConsensus();
  Json? _pending;
  bool busy = false, stopped = false, fatal = false, _closed = false;
  String status = 'Đưa biển số vào khung quét', plate = '';
  DateTime? retryAfter;
  bool get hasPending => _pending != null;
  bool get readyForFrame =>
      !_closed &&
      !stopped &&
      !busy &&
      !fatal &&
      (retryAfter == null || !_clock().isBefore(retryAfter!));

  void restore() {
    final pending = preferences.getString(storageKey);
    if (pending != null) {
      _pending = Map<String, dynamic>.from(jsonDecode(pending) as Map);
    }
    final previous = preferences.getString('$storageKey:last');
    if (previous != null) {
      final value = jsonDecode(previous) as Map;
      final at = DateTime.parse(value['at'] as String);
      if (_clock().difference(at) < const Duration(seconds: 30)) {
        _consensus.block(value['plate'] as String, at);
      }
    }
  }

  void pause(bool value) {
    stopped = value;
    _consensus.reset();
  }

  Future<void> acceptFrame(List<String>? candidates) async {
    if (!readyForFrame) {
      return;
    }
    if (_pending != null) return _process();
    if (candidates == null) {
      _consensus.reset();
      status = 'Ảnh thiếu sáng hoặc thiếu chi tiết. Căn lại biển số.';
      _notify();
      return;
    }
    final stable = _consensus.observe(candidates, _clock());
    if (stable == null) {
      if (candidates.length > 1) {
        status = 'Chỉ đưa một biển số vào khung quét';
      } else if (candidates.length == 1) {
        plate = candidates.single;
        status =
            _consensus.isBlocked(plate)
                ? 'Đã xử lý biển số này · Chờ xe tiếp theo'
                : 'Đang kiểm tra biển số…';
      } else {
        plate = '';
        status = 'Đang tự quét · Đưa biển số rõ nét vào khung';
      }
      _notify();
      return;
    }
    _pending = {'id': const Uuid().v4(), 'plate': stable};
    await _process();
  }

  Future<void> _process() async {
    busy = true;
    plate = _pending!['plate'] as String;
    status = 'Đang đối chiếu vé…';
    _notify();
    try {
      // Persist before sending. A restart or timeout replays the same command.
      if (!await preferences.setString(storageKey, jsonEncode(_pending))) {
        throw const ParkFailure(
          'Không lưu được lượt quét. Kiểm tra bộ nhớ thiết bị.',
        );
      }
      Json result;
      try {
        result = await execute(_pending!['id'] as String, plate);
      } on ParkFailure catch (failure) {
        if (failure.retryable) {
          status =
              'Chưa xác nhận được với máy chủ. Đang giữ lượt quét để thử lại.';
        } else {
          await _clearPending();
          status = switch (failure.code) {
            'VALID_TICKET_REQUIRED' || 'PLATE_MISMATCH' || 'INVALID_PLATE' =>
              'Xe chưa đăng ký đỗ online hoặc quét nhầm, vui lòng thử lại',
            'OVERDUE_INSUFFICIENT_BALANCE' =>
              'Bạn đã gửi quá giờ, và số dư không đủ, vui lòng nạp thêm tiền',
            'INSUFFICIENT_BALANCE' =>
              'Số dư không đủ thanh toán tiền gửi xe, vui lòng nạp thêm tiền',
            'ENTRY_REQUIRED' =>
              'Xe chưa được ghi nhận vào bãi. Vui lòng kiểm tra lại.',
            'KIOSK_SESSION_REQUIRED' || 'KIOSK_DIRECTION_MISMATCH' =>
              'Phiên camera không hợp lệ. Vui lòng chọn lại bãi và chiều camera.',
            _ => failure.message,
          };
        }
        _notify();
        if (!_closed && !stopped) {
          try {
            await feedback.speak(status);
          } catch (_) {
            status =
                '$status\nKhông phát được âm thanh. Kiểm tra loa và quyền âm thanh của trình duyệt.';
            _notify();
          }
        }
        // The five seconds start only after the announcement has finished.
        retryAfter = _clock().add(const Duration(seconds: 5));
        _consensus.reset();
        return;
      }
      _consensus.block(plate, _clock());
      if (!await preferences.setString(
        '$storageKey:last',
        jsonEncode({'plate': plate, 'at': _clock().toUtc().toIso8601String()}),
      )) {
        throw const ParkFailure(
          'Không lưu được trạng thái lượt quét đã thành công.',
        );
      }
      await _clearPending();
      status = switch (result['action']) {
        'entered' => 'Xe vào hợp lệ',
        'exited' => 'Đã thanh toán · Xe ra hợp lệ',
        _ => 'Xe đã được ghi nhận. Di chuyển khỏi vùng quét.',
      };
      _notify();
      if (!_closed && !stopped && result['action'] != 'duplicate') {
        try {
          await feedback.success();
        } catch (_) {
          status =
              '$status\nKhông phát được âm báo. Lượt quét đã được ghi nhận.';
        }
      }
    } catch (error) {
      // A storage failure must never turn a committed entry into exit.
      fatal = true;
      status =
          '$status\n${error is ParkFailure ? error.message : 'Lỗi âm thanh hoặc bộ nhớ. Kiểm tra thiết bị rồi mở lại camera.'}';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _clearPending() async {
    if (!await preferences.remove(storageKey)) {
      throw const ParkFailure(
        'Không lưu được kết quả lượt quét. Vui lòng mở lại camera.',
      );
    }
    _pending = null;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    stopped = true;
    super.dispose();
  }
}
