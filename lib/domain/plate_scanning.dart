import 'dart:math' as math;
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

class PlateTarget {
  const PlateTarget(this.plate, this.bounds, this.characterHeight);
  final String plate;
  final PlateLine bounds;
  final double characterHeight;
}

List<PlateTarget> scanTargets(List<PlateLine> lines) {
  final visible =
      lines
          .where(
            (l) =>
                l.left >= .1 &&
                l.right <= .9 &&
                l.top >= .25 &&
                l.bottom <= .75 &&
                l.bottom - l.top >= .018,
          )
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));
  final candidates = <String, PlateTarget>{};
  void add(String text, PlateLine bounds, double characterHeight) {
    // shortcut: apparent character size estimates proximity; calibrate for the installed camera and plate types.
    if (characterHeight < .035 || bounds.right - bounds.left < .12) return;
    for (final plate in plateCandidates(text)) {
      final previous = candidates[plate];
      if (previous == null || previous.characterHeight < characterHeight) {
        candidates[plate] = PlateTarget(plate, bounds, characterHeight);
      }
    }
  }

  for (final line in visible) {
    add(line.text, line, line.bottom - line.top);
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
      add(
        '${line.text}\n${next.text}',
        PlateLine(
          '',
          math.min(line.left, next.left),
          line.top,
          math.max(line.right, next.right),
          next.bottom,
        ),
        math.min(height, next.bottom - next.top),
      );
    }
  }
  final targets =
      candidates.values.toList()
        ..sort((a, b) => b.characterHeight.compareTo(a.characterHeight));
  if (targets.length > 1 &&
      targets.first.characterHeight >= targets[1].characterHeight * 1.5) {
    return [targets.first];
  }
  return targets;
}

List<String> scanCandidates(List<PlateLine> lines) =>
    scanTargets(lines).map((target) => target.plate).toList();

class PlateConsensus {
  final _samples = <String?>[];
  DateTime? _lastSample;
  final _blocked = <String, ({DateTime at, DateTime seen})>{};

  bool isBlocked(String plate) => _blocked.containsKey(plate);

  void reset() {
    _samples.clear();
    _lastSample = null;
  }

  void block(String plate, DateTime now) {
    _blocked[plate] = (at: now, seen: now);
    reset();
  }

  /// Call only for usable frames. Blurry frames must not re-arm a passage.
  String? observe(List<String> candidates, DateTime now) {
    // Browser OCR can take several seconds per frame on a cold/slow device.
    if (_lastSample != null && now.difference(_lastSample!).inSeconds >= 8) {
      reset();
    }
    _lastSample = now;
    for (final plate in candidates) {
      final blocked = _blocked[plate];
      if (blocked != null) _blocked[plate] = (at: blocked.at, seen: now);
    }
    _blocked.removeWhere(
      (plate, blocked) =>
          now.difference(blocked.seen) >= const Duration(seconds: 2) &&
          now.difference(blocked.at) >= const Duration(seconds: 30),
    );
    final plate = candidates.length == 1 ? candidates.single : null;
    _samples.add(plate);
    if (_samples.length > 5) _samples.removeAt(0);
    if (plate == null || _blocked.containsKey(plate)) return null;
    return _samples.where((p) => p == plate).length >= 3 ? plate : null;
  }
}
