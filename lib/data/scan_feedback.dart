import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/models.dart';

abstract interface class ScanFeedback {
  Future<void> prepare();
  Future<void> speak(String message);
  Future<void> success();
  Future<void> stop();
  Future<void> dispose();
}

class DeviceScanFeedback implements ScanFeedback {
  final _tts = FlutterTts();
  final _sound = AudioPlayer();
  Completer<void>? _cancelledSpeech;
  @override
  Future<void> prepare() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(.48);
    await _tts.awaitSpeakCompletion(true);
    // Prime audio during the lot-selection gesture, including browser autoplay.
    await _sound.setVolume(0);
    await _sound.play(AssetSource('audio/scan_success.wav'));
    await _sound.stop();
    await _sound.setVolume(1);
  }

  @override
  Future<void> speak(String message) async {
    final failed = Completer<void>();
    final cancelled = Completer<void>();
    _cancelledSpeech = cancelled;
    _tts.setErrorHandler((_) {
      if (!failed.isCompleted) {
        failed.completeError(
          const ParkFailure(
            'Chưa phát được giọng nói. Kiểm tra loa và giọng tiếng Việt của thiết bị.',
          ),
        );
      }
    });
    dynamic result;
    try {
      result = await Future.any<dynamic>([
        _tts.speak(message),
        failed.future,
        cancelled.future,
      ]).timeout(
        const Duration(seconds: 45),
        onTimeout:
            () =>
                throw const ParkFailure(
                  'Giọng nói không phản hồi. Kiểm tra âm thanh của thiết bị.',
                ),
      );
    } finally {
      if (identical(_cancelledSpeech, cancelled)) _cancelledSpeech = null;
    }
    // Web completes with null, Android/iOS normally complete with 1.
    if (result == 0) {
      throw const ParkFailure(
        'Chưa phát được giọng nói. Kiểm tra loa và giọng tiếng Việt của thiết bị.',
      );
    }
  }

  @override
  Future<void> success() => _sound.play(AssetSource('audio/scan_success.wav'));
  @override
  Future<void> stop() async {
    if (_cancelledSpeech?.isCompleted == false) _cancelledSpeech!.complete();
    await _tts.stop();
    await _sound.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _sound.dispose();
  }
}
