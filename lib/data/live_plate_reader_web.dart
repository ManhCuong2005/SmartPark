import 'dart:convert';
import 'dart:js_interop';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../domain/plate_scanning.dart';

@JS('SmartParkOCR.prepare')
external JSPromise<JSAny?> _prepare();
@JS('SmartParkOCR.read')
external JSPromise<JSString> _read(JSUint8Array bytes, JSBoolean mirrored);
@JS('SmartParkOCR.close')
external JSPromise<JSAny?> _close();

class LivePlateReader {
  bool _prepared = false;
  Future<void> prepare() async {
    if (_prepared) return;
    await _prepare().toDart;
    _prepared = true;
  }

  Future<List<PlateLine>?> readPhoto(
    XFile file, {
    bool mirrored = false,
  }) async {
    late final Map result;
    try {
      final bytes = await file.readAsBytes();
      result =
          jsonDecode((await _read(bytes.toJS, mirrored.toJS).toDart).toDart)
              as Map;
    } finally {
      if (file.path.startsWith('blob:')) web.URL.revokeObjectURL(file.path);
    }
    if (result['usable'] != true) return null;
    return [
      for (final row in result['lines'] as List)
        PlateLine(
          row['text'] as String,
          (row['left'] as num).toDouble(),
          (row['top'] as num).toDouble(),
          (row['right'] as num).toDouble(),
          (row['bottom'] as num).toDouble(),
        ),
    ];
  }

  Future<List<PlateLine>?> read(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation orientation,
  ) => throw UnsupportedError('Browser scanning uses camera snapshots.');
  Future<void> close() async {
    if (!_prepared) return;
    _prepared = false;
    await _close().toDart;
  }
}
