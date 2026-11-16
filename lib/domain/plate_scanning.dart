import 'parking_rules.dart';

enum ScanDirection {
  entry('Cam vào'),
  exit('Cam ra');

  const ScanDirection(this.label);
  final String label;
}

/// Coordinates are fractions of the upright camera image.
class PlateLine {
  const PlateLine(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

List<String> scanCandidates(List<PlateLine> lines) {
  final visible =
      lines
          .where(
            (l) =>
                l.centerX >= .1 &&
                l.centerX <= .9 &&
                l.centerY >= .25 &&
                l.centerY <= .75 &&
                l.bottom - l.top >= .018,
          )
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));
  final candidates = <String>{};
  for (final line in visible) {
    candidates.addAll(plateCandidates(line.text));
    // Join only adjacent aligned rows, never the text of the whole scene.
    for (final next in visible) {
      final height = line.bottom - line.top;
      final gap = next.top - line.bottom;
      if (next.top <= line.top ||
          gap < -height * .3 ||
          gap > height * 1.8 ||
          (line.centerX - next.centerX).abs() >
              (line.right - line.left + next.right - next.left) * .25) {
        continue;
      }
      if (!RegExp(
            r'^\d{2}[A-Z]{1,2}\d?$',
          ).hasMatch(normalizePlate(line.text)) ||
          !RegExp(r'^\d{4,5}$').hasMatch(normalizePlate(next.text))) {
        continue;
      }
      candidates.addAll(plateCandidates('${line.text}\n${next.text}'));
    }
  }
  return candidates.toList();
}

class PlateConsensus {
  final _samples = <String?>[];
  DateTime? _lastSample, _lastBlockedSeen, _blockedAt;
  String? _blocked;

  void reset() {
    _samples.clear();
    _lastSample = null;
  }

  void block(String plate, DateTime now) {
    _blocked = plate;
    _lastBlockedSeen = _blockedAt = now;
    reset();
  }

  /// Call only for usable frames. Blurry frames must not re-arm a passage.
  String? observe(List<String> candidates, DateTime now) {
    // Browser OCR can take several seconds per frame on a cold/slow device.
    if (_lastSample != null && now.difference(_lastSample!).inSeconds >= 8) {
      reset();
    }
    _lastSample = now;
    if (_blocked != null) {
      if (candidates.contains(_blocked)) _lastBlockedSeen = now;
      if (now.difference(_lastBlockedSeen!) >= const Duration(seconds: 2) &&
          now.difference(_blockedAt!) >= const Duration(seconds: 30)) {
        _blocked = null;
      }
    }
    final plate = candidates.length == 1 ? candidates.single : null;
    _samples.add(plate);
    if (_samples.length > 5) _samples.removeAt(0);
    if (plate == null || plate == _blocked) return null;
    return _samples.where((p) => p == plate).length >= 3 ? plate : null;
  }
}
