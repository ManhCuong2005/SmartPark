import 'dart:async';
import 'package:flutter/foundation.dart';

enum MapLoadStatus { loading, ready, partial, unavailable }

/// Tile callbacks only update the small status overlay, not the map/camera.
class MapLoadState extends ChangeNotifier {
  MapLoadState({this.timeout = const Duration(seconds: 12)});
  final Duration timeout;
  Timer? _watchdog;
  bool _hasImage = false, _hasError = false, _disposed = false;
  MapLoadStatus status = MapLoadStatus.loading;

  void restart() {
    _watchdog?.cancel();
    _hasImage = _hasError = false;
    _set(MapLoadStatus.loading);
    _watchdog = Timer(timeout, () => _set(MapLoadStatus.unavailable));
  }

  void imageLoaded() {
    if (_disposed) return;
    _watchdog?.cancel();
    _hasImage = true;
    _set(_hasError ? MapLoadStatus.partial : MapLoadStatus.ready);
  }

  void imageFailed() {
    if (_disposed) return;
    _watchdog?.cancel();
    _hasError = true;
    _set(_hasImage ? MapLoadStatus.partial : MapLoadStatus.unavailable);
  }

  void _set(MapLoadStatus value) {
    if (_disposed || value == status) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    super.dispose();
  }
}
