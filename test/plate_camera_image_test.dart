import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/data/plate_camera_image.dart';

// Exercise native pixel layouts without invoking a camera or ML Kit.
CameraImage frame(
  List<Map<String, dynamic>> planes, {
  int format = 35,
  int width = 20,
  int height = 20,
}) =>
// ignore: deprecated_member_use
CameraImage.fromPlatformData({
  'width': width,
  'height': height,
  'format': format,
  'planes': planes,
});

void main() {
  test(
    'non-square camera preserves upright detector coordinates when rotated',
    () {
      final bytes = Uint8List(40 * 20 * 3 ~/ 2);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 40; x++) {
          bytes[y * 40 + x] = y * 10 + x;
        }
      }
      bytes.fillRange(800, bytes.length, 128);
      final image = frame(
        [
          {'bytes': bytes, 'bytesPerRow': 40, 'bytesPerPixel': 1},
        ],
        format: 17,
        width: 40,
      );
      const starts = {0: 68, 90: 52, 180: 88, 270: 56};
      for (final entry in starts.entries) {
        final crop = preparePlateCameraImage(
          image,
          entry.key,
          android: true,
          uprightRegion: const Rect.fromLTRB(.2, .3, .8, .6),
        );
        expect(crop.bytes.first, entry.value);
        expect(crop.left, closeTo(.2, 1e-6));
        expect(crop.top, closeTo(.3, 1e-6));
        expect(crop.widthFraction, closeTo(.6, 1e-6));
        expect(crop.heightFraction, closeTo(.3, 1e-6));
      }
    },
  );
  test('detected upright rectangle maps to packed NV21 in all rotations', () {
    final bytes = Uint8List(600);
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        bytes[y * 20 + x] = y * 10 + x;
      }
    }
    bytes.fillRange(400, 600, 128);
    final image = frame([
      {'bytes': bytes, 'bytesPerRow': 20, 'bytesPerPixel': 1},
    ], format: 17);
    const expected = {
      0: [4, 6, 12, 6],
      90: [6, 4, 6, 12],
      180: [4, 8, 12, 6],
      270: [8, 4, 6, 12],
    };
    for (final entry in expected.entries) {
      final crop = preparePlateCameraImage(
        image,
        entry.key,
        android: true,
        uprightRegion: const Rect.fromLTRB(.2, .3, .8, .6),
      );
      final e = entry.value;
      expect(
        [crop.width, crop.height],
        [e[2], e[3]],
        reason: 'rotation ${entry.key}',
      );
      expect(crop.bytes.first, e[1] * 10 + e[0]);
      expect(crop.bytes.length, crop.width * crop.height * 3 ~/ 2);
      expect(crop.left, closeTo(.2, .00001));
      expect(crop.top, closeTo(.3, .00001));
    }
    expect(
      () => preparePlateCameraImage(
        image,
        0,
        android: true,
        uprightRegion: const Rect.fromLTRB(-.1, 0, .5, .5),
      ),
      throwsException,
    );
  });
  test(
    'crops padded three-plane YUV and preserves interleaved V/U samples',
    () {
      final y = Uint8List(24 * 20),
          u = Uint8List(24 * 10),
          v = Uint8List(24 * 10);
      for (var row = 0; row < 20; row++) {
        for (var col = 0; col < 20; col++) {
          y[row * 24 + col] = row * 10 + col;
        }
      }
      for (var row = 0; row < 10; row++) {
        for (var col = 0; col < 10; col++) {
          u[row * 24 + col * 2] = 50 + col;
          v[row * 24 + col * 2] = 100 + row;
        }
      }
      final source = frame([
        {'bytes': y, 'bytesPerRow': 24, 'bytesPerPixel': 1},
        {'bytes': u, 'bytesPerRow': 24, 'bytesPerPixel': 2},
        {'bytes': v, 'bytesPerRow': 24, 'bytesPerPixel': 2},
      ]);
      final crop = preparePlateCameraImage(source, 0, android: true);
      expect([crop.width, crop.height, crop.bytesPerRow], [16, 10, 16]);
      expect(crop.bytes.first, 42); // Aligned crop starts at x=2, y=4.
      expect(crop.bytes[16 * 10], 102);
      expect(crop.bytes[16 * 10 + 1], 51);
      expect(crop.bytes.length, 16 * 10 * 3 ~/ 2);
      expect(crop.usable, true);
      final rotated = preparePlateCameraImage(source, 90, android: true);
      expect([rotated.width, rotated.height], [10, 16]);
      expect(rotated.widthFraction, .8);
      expect(rotated.heightFraction, .5);
    },
  );
  test('packed NV21 and padded YUV produce the same cropped frame', () {
    final bytes = Uint8List(20 * 20 * 3 ~/ 2);
    for (var i = 0; i < 400; i++) {
      bytes[i] = i % 200;
    }
    for (var i = 400; i < bytes.length; i++) {
      bytes[i] = i.isEven ? 120 : 80;
    }
    final packed = frame([
      {'bytes': bytes, 'bytesPerRow': 20, 'bytesPerPixel': 1},
    ], format: 17);
    final planar = frame([
      {'bytes': bytes.sublist(0, 400), 'bytesPerRow': 20, 'bytesPerPixel': 1},
      {
        'bytes': Uint8List(100)..fillRange(0, 100, 80),
        'bytesPerRow': 10,
        'bytesPerPixel': 1,
      },
      {
        'bytes': Uint8List(100)..fillRange(0, 100, 120),
        'bytesPerRow': 10,
        'bytesPerPixel': 1,
      },
    ]);
    for (final degrees in [0, 90, 180, 270]) {
      expect(
        preparePlateCameraImage(packed, degrees, android: true).bytes,
        preparePlateCameraImage(planar, degrees, android: true).bytes,
      );
    }
  });
  test('BGRA crop honors row padding and rejects featureless frames', () {
    final bytes = Uint8List(84 * 20)..fillRange(0, 84 * 20, 255);
    final image = frame([
      {'bytes': bytes, 'bytesPerRow': 84, 'bytesPerPixel': 4},
    ], format: 1111970369);
    final crop = preparePlateCameraImage(image, 90, android: false);
    expect([crop.width, crop.height, crop.bytesPerRow], [10, 16, 40]);
    expect(crop.bytes.length, 10 * 16 * 4);
    expect(crop.usable, false);
  });
}
