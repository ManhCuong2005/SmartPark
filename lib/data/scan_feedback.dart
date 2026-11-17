import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

abstract interface class ScanFeedback {
  Future<void> prepare();
  Future<void> speak(String message);
  Future<void> success();
  Future<void> stop();
  Future<void> dispose();
}

/// Bundled Vietnamese announcements do not depend on the system's voices.
String scanAnnouncementAsset(String message) {
  final name =
      message.startsWith('Xe chưa đăng ký')
          ? 'invalid_ticket'
          : message.startsWith('Bạn đã gửi quá giờ')
          ? 'overdue'
          : message.startsWith('Số dư không đủ')
          ? 'balance'
          : message.startsWith('Xe chưa được ghi nhận')
          ? 'entry'
          : message.startsWith('Phiên camera không hợp lệ')
          ? 'session'
          : message.startsWith('Chưa xác nhận được')
          ? 'retry'
          : 'error';
  return 'audio/scan_${name}_vi.mp3';
}

class DeviceScanFeedback implements ScanFeedback {
  final _sound = AudioPlayer();
  Completer<void>? _cancelledSpeech;
  @override
  Future<void> prepare() async {
    // Prime audio during the lot-selection gesture, including browser autoplay.
    await _sound.setVolume(0);
    await _sound.play(AssetSource('audio/scan_success.wav'));
    await _sound.stop();
    await _sound.setVolume(1);
  }

  @override
  Future<void> speak(String message) async {
    final cancelled = Completer<void>();
    _cancelledSpeech = cancelled;
    final completed = Completer<void>();
    final subscription = _sound.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    try {
      await _sound.play(AssetSource(scanAnnouncementAsset(message)));
      await Future.any([
        completed.future,
        cancelled.future,
      ]).timeout(const Duration(seconds: 20));
    } finally {
      await subscription.cancel();
      if (identical(_cancelledSpeech, cancelled)) _cancelledSpeech = null;
      await _sound.stop();
    }
  }

  @override
  Future<void> success() => _sound.play(AssetSource('audio/scan_success.wav'));
  @override
  Future<void> stop() async {
    if (_cancelledSpeech?.isCompleted == false) _cancelledSpeech!.complete();
    await _sound.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _sound.dispose();
  }
}
