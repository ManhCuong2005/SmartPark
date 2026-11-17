import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/models.dart';
import '../domain/plate_scanning.dart';
import 'plate_camera_image.dart';

class LivePlateReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Future<void> prepare() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const ParkFailure(
        'Dùng Android/iOS hoặc mở bản Web bằng Chrome để quét camera.',
      );
    }
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
  Future<void> close() => _recognizer.close();
}
