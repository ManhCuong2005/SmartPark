import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/models.dart';
import '../domain/plate_scanning.dart';
import 'plate_camera_image.dart';

class LivePlateReader {
  static const _detector = MethodChannel('smartpark/plate_detector');
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Future<void> prepare() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const ParkFailure(
        'Dùng Android/iOS hoặc mở bản Web bằng Chrome để quét camera.',
      );
    }
    if (Platform.isAndroid) await _detector.invokeMethod<void>('prepare');
  }

  Future<List<PlateLine>?> read(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation orientation,
  ) async {
    final android = Platform.isAndroid;
    final compensation =
        {
          DeviceOrientation.portraitUp: 0,
          DeviceOrientation.landscapeLeft: 90,
          DeviceOrientation.portraitDown: 180,
          DeviceOrientation.landscapeRight: 270,
        }[orientation]!;
    final degrees =
        android
            ? (camera.lensDirection == CameraLensDirection.front
                    ? camera.sensorOrientation + compensation
                    : camera.sensorOrientation - compensation + 360) %
                360
            : camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) {
      throw const ParkFailure('Camera trả về hướng ảnh không hỗ trợ.');
    }
    final cropped = preparePlateCameraImage(image, degrees, android: android);
    if (!cropped.usable) return null;
    final crops = <PlateCameraImage>[];
    if (android) {
      final regions = await _detector.invokeListMethod<dynamic>('detect', {
        'bytes': cropped.bytes,
        'width': cropped.width,
        'height': cropped.height,
        'rotation': degrees,
      });
      if (regions == null) {
        throw const ParkFailure('Model không trả về kết quả.');
      }
      for (final value in regions) {
        final r = List<num>.from(value as List);
        if (r.length != 4) {
          throw const ParkFailure('Vùng biển số không hợp lệ.');
        }
        crops.add(
          preparePlateCameraImage(
            image,
            degrees,
            android: true,
            uprightRegion: Rect.fromLTRB(
              cropped.left + r[0] * cropped.widthFraction,
              cropped.top + r[1] * cropped.heightFraction,
              cropped.left + r[2] * cropped.widthFraction,
              cropped.top + r[3] * cropped.heightFraction,
            ),
          ),
        );
      }
      // shortcut: unfamiliar plate shapes fall back to guide OCR; calibrate with installed-camera footage.
      if (crops.isEmpty) crops.add(cropped);
    } else {
      crops.add(cropped);
    }
    final lines = <PlateLine>[];
    for (final crop in crops) {
      lines.addAll(await _readCrop(crop, rotation, degrees, android));
    }
    if (android &&
        !identical(crops.first, cropped) &&
        scanCandidates(lines).isEmpty) {
      return _readCrop(cropped, rotation, degrees, android);
    }
    return lines;
  }

  Future<List<PlateLine>> _readCrop(
    PlateCameraImage cropped,
    InputImageRotation rotation,
    int degrees,
    bool android,
  ) async {
    final recognized = await _recognizer.processImage(
      InputImage.fromBytes(
        bytes: cropped.bytes,
        metadata: InputImageMetadata(
          size: Size(cropped.width.toDouble(), cropped.height.toDouble()),
          rotation: rotation,
          format: android ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: cropped.bytesPerRow,
        ),
      ),
    );
    final sideways = degrees == 90 || degrees == 270;
    final width = sideways ? cropped.height : cropped.width;
    final height = sideways ? cropped.width : cropped.height;
    return [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          if ((line.confidence == null || line.confidence! >= .7) &&
              line.boundingBox.height >= 16 &&
              (line.angle == null || line.angle!.abs() <= 25))
            PlateLine(
              line.text,
              cropped.left +
                  line.boundingBox.left / width * cropped.widthFraction,
              cropped.top +
                  line.boundingBox.top / height * cropped.heightFraction,
              cropped.left +
                  line.boundingBox.right / width * cropped.widthFraction,
              cropped.top +
                  line.boundingBox.bottom / height * cropped.heightFraction,
            ),
    ];
  }

  Future<List<PlateLine>?> readPhoto(XFile file, {bool mirrored = false}) =>
      throw UnsupportedError('Native scanning uses the live image stream.');
  Future<void> close() async {
    await _recognizer.close();
    if (Platform.isAndroid) await _detector.invokeMethod<void>('close');
  }
}
