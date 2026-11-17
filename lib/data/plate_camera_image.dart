import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../domain/models.dart';

class PlateCameraImage {
  const PlateCameraImage(
    this.bytes,
    this.width,
    this.height,
    this.bytesPerRow,
    this.left,
    this.top,
    this.widthFraction,
    this.heightFraction,
    this.usable,
  );
  final Uint8List bytes;
  final int width, height, bytesPerRow;
  final double left, top, widthFraction, heightFraction;
  final bool usable;
}

/// Crop the guide before OCR; normalize YUV row/pixel strides to packed NV21.
PlateCameraImage preparePlateCameraImage(
  CameraImage image,
  int rotation, {
  required bool android,
}) {
  final sideways = rotation == 90 || rotation == 270;
  final width = ((image.width * (sideways ? .5 : .8)).floor() ~/ 2) * 2;
  final height = ((image.height * (sideways ? .8 : .5)).floor() ~/ 2) * 2;
  final left = ((image.width - width) ~/ 4) * 2;
  final top = ((image.height - height) ~/ 4) * 2;
  if (width < 2 ||
      height < 2 ||
      (android && ![1, 3].contains(image.planes.length)) ||
      (!android && image.planes.length != 1)) {
    throw const ParkFailure('Định dạng khung hình camera không được hỗ trợ.');
  }
  final plane = image.planes.first;
  final output = Uint8List(
    android ? width * height * 3 ~/ 2 : width * height * 4,
  );
  var offset = 0;
  for (var y = top; y < top + height; y++) {
    if (!android) {
      output.setRange(
        offset,
        offset + width * 4,
        plane.bytes,
        y * plane.bytesPerRow + left * 4,
      );
      offset += width * 4;
    } else {
      for (var x = left; x < left + width; x++) {
        output[offset++] =
            plane.bytes[y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? 1)];
      }
    }
  }
  if (android) {
    for (var y = top ~/ 2; y < (top + height) ~/ 2; y++) {
      for (var x = left ~/ 2; x < (left + width) ~/ 2; x++) {
        if (image.planes.length == 1) {
          final source =
              plane.bytesPerRow * image.height + y * plane.bytesPerRow + x * 2;
          output[offset++] = plane.bytes[source];
          output[offset++] = plane.bytes[source + 1];
        } else {
          final u = image.planes[1], v = image.planes[2];
          output[offset++] =
              v.bytes[y * v.bytesPerRow + x * (v.bytesPerPixel ?? 1)];
          output[offset++] =
              u.bytes[y * u.bytesPerRow + x * (u.bytesPerPixel ?? 1)];
        }
      }
    }
  }
  var sum = 0.0, squares = 0.0, samples = 0;
  for (var y = 0; y < height; y += 4) {
    for (var x = 0; x < width; x += 4) {
      final index = (y * width + x) * (android ? 1 : 4);
      final value =
          android
              ? output[index].toDouble()
              : .114 * output[index] +
                  .587 * output[index + 1] +
                  .299 * output[index + 2];
      sum += value;
      squares += value * value;
      samples++;
    }
  }
  final mean = sum / samples;
  // shortcut: exposure/contrast thresholds need calibration on the installed camera.
  final usable = mean >= 18 && squares / samples - mean * mean >= 8;
  final x = switch (rotation) {
    90 => (image.height - top - height) / image.height,
    180 => (image.width - left - width) / image.width,
    270 => top / image.height,
    _ => left / image.width,
  };
  final y = switch (rotation) {
    90 => left / image.width,
    180 => (image.height - top - height) / image.height,
    270 => (image.width - left - width) / image.width,
    _ => top / image.height,
  };
  return PlateCameraImage(
    output,
    width,
    height,
    width * (android ? 1 : 4),
    x,
    y,
    sideways ? height / image.height : width / image.width,
    sideways ? width / image.width : height / image.height,
    usable,
  );
}
