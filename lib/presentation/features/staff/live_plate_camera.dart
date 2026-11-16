import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/live_plate_reader.dart';
import '../../../domain/plate_scanning.dart';

class LivePlateCamera extends StatefulWidget {
  const LivePlateCamera({
    super.key,
    required this.onFrame,
    this.shouldRead,
    required this.settingsKey,
    this.onCameraChanged,
  });
  final Future<void> Function(List<String>?) onFrame;
  final bool Function()? shouldRead;
  final String settingsKey;
  final VoidCallback? onCameraChanged;
  @override
  State<LivePlateCamera> createState() => _LivePlateCameraState();
}

class _LivePlateCameraState extends State<LivePlateCamera>
    with WidgetsBindingObserver {
  CameraController? _camera;
  LivePlateReader? _reader;
  Future<void>? _frame, _opening, _releasing;
  Timer? _webTimer;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  String? _error;
  bool _active = true, _closing = false;
  bool _ready = false;
  bool _chooseCamera = false;
  List<CameraDescription> _cameras = [];
  String? _selectedCamera;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() =>
      _opening ??= _initialize().whenComplete(() => _opening = null);
  Future<void> _initialize() async {
    await _releasing;
    if (!mounted || !_active || _closing) return;
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (!mounted || !_active || generation != _generation) return;
      if (cameras.isEmpty) throw StateError('Không tìm thấy camera.');
      final preferences = await SharedPreferences.getInstance();
      _selectedCamera ??= preferences.getString(widget.settingsKey);
      _cameras = cameras;
      if ((_selectedCamera == null && cameras.length > 1) ||
          (_selectedCamera != null &&
              !cameras.any((c) => c.name == _selectedCamera))) {
        setState(() => _chooseCamera = true);
        return;
      }
      final description =
          cameras.where((c) => c.name == _selectedCamera).firstOrNull ??
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.back)
              .firstOrNull ??
          cameras.first;
      _selectedCamera = description.name;
      final camera = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            defaultTargetPlatform == TargetPlatform.iOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.nv21,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || !_active || generation != _generation) return;
      if (!kIsWeb) {
        await camera.setFocusMode(FocusMode.auto);
        await camera.setExposureMode(ExposureMode.auto);
      }
      final reader = LivePlateReader();
      _reader = reader;
      await reader.prepare();
      if (!mounted || !_active || generation != _generation) return;
      setState(() {
        _error = null;
        _ready = true;
      });
      if (kIsWeb) {
        _webTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (_canRead) {
            _frame = _readPhoto(
              camera,
              reader,
            ).whenComplete(() => _frame = null);
          }
        });
      } else {
        await camera.startImageStream((image) {
          if (_canRead) {
            _frame = _readImage(
              image,
              camera,
              reader,
            ).whenComplete(() => _frame = null);
          }
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error =
                  'Chưa mở được camera/OCR. Kiểm tra quyền camera và kết nối.\n$error',
        );
      }
    } finally {
      if (!mounted || !_active || generation != _generation) await _release();
    }
  }

  bool get _canRead {
    final now = DateTime.now();
    if (!_active ||
        _closing ||
        _error != null ||
        _frame != null ||
        !(widget.shouldRead?.call() ?? true) ||
        now.difference(_lastFrame) < const Duration(milliseconds: 250)) {
      return false;
    }
    _lastFrame = now;
    return true;
  }

  Future<void> _readImage(
    CameraImage image,
    CameraController camera,
    LivePlateReader reader,
  ) async {
    try {
      final lines = await reader.read(
        image,
        camera.description,
        camera.value.deviceOrientation,
      );
      if (mounted && _active) {
        await widget.onFrame(lines == null ? null : scanCandidates(lines));
      }
    } catch (error) {
      _frameError(error);
    }
  }

  Future<void> _readPhoto(
    CameraController camera,
    LivePlateReader reader,
  ) async {
    try {
      final photo = await camera.takePicture();
      final lines = await reader.readPhoto(
        photo,
        mirrored: camera.description.lensDirection != CameraLensDirection.back,
      );
      if (mounted && _active) {
        await widget.onFrame(lines == null ? null : scanCandidates(lines));
      }
    } catch (error) {
      _frameError(error);
    }
  }

  void _frameError(Object error) {
    if (mounted && _active) {
      setState(() => _error = 'Camera/OCR gặp lỗi.\n$error');
    }
  }

  Future<void> _selectCamera(String name) async {
    if (_opening != null || _releasing != null) return;
    _selectedCamera = name;
    _generation++;
    try {
      await _release();
      if (!mounted || !_active) return;
      widget.onCameraChanged?.call();
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(widget.settingsKey, name)) {
        throw StateError('Không lưu được camera.');
      }
      setState(() {
        _chooseCamera = false;
        _error = null;
      });
      await _open();
    } catch (error) {
      _frameError(error);
    }
  }

  Future<void> _release() =>
      _releasing ??= _disposeCamera().whenComplete(() => _releasing = null);
  Future<void> _disposeCamera() async {
    _ready = false;
    _webTimer?.cancel();
    _webTimer = null;
    final camera = _camera;
    _camera = null;
    try {
      if (camera?.value.isStreamingImages == true) {
        await camera!.stopImageStream();
      }
      await _frame;
    } finally {
      await camera?.dispose();
      await _reader?.close();
      _reader = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _generation++;
      unawaited(_release());
    } else {
      unawaited(_opening?.then((_) => _open()) ?? _open());
    }
  }

  @override
  void dispose() {
    _closing = true;
    _active = false;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    // Let pending initialization finish before freeing its native resources.
    unawaited((_opening ?? Future<void>.value()).whenComplete(_release));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chooseCamera) {
      return Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Chọn đúng camera cho làn này',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _cameras.length; i++)
              TextButton(
                onPressed: () => _selectCamera(_cameras[i].name),
                child: Text('Camera ${i + 1} · ${_cameras[i].name}'),
              ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () async {
                  setState(() => _error = null);
                  await _release();
                  await _open();
                },
                child: const Text('Mở lại camera'),
              ),
            ],
          ),
        ),
      );
    }
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || !_ready) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang khởi động camera và OCR…',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    // AspectRatio keeps the guide coordinates identical to OCR coordinates.
    return Column(
      children: [
        if (_cameras.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedCamera,
              isExpanded: true,
              dropdownColor: const Color(0xFF102329),
              style: const TextStyle(color: Colors.white),
              items: [
                for (var i = 0; i < _cameras.length; i++)
                  DropdownMenuItem(
                    value: _cameras[i].name,
                    child: Text(
                      'Camera ${i + 1} · ${_cameras[i].name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (name) async {
                if (name != null && name != _selectedCamera) {
                  await _selectCamera(name);
                }
              },
            ),
          ),
        Expanded(
          child: Center(
            child: Transform.flip(
              // camera_web mirrors both preview and JPEG for non-rear cameras.
              flipX:
                  kIsWeb &&
                  camera.description.lensDirection != CameraLensDirection.back,
              child: CameraPreview(
                camera,
                child: IgnorePointer(child: CustomPaint(painter: _ScanGuide())),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanGuide extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final region = Rect.fromLTRB(
      size.width * .1,
      size.height * .25,
      size.width * .9,
      size.height * .75,
    );
    final shade =
        Path()
          ..addRect(Offset.zero & size)
          ..addRect(region)
          ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(region, const Radius.circular(12)),
      Paint()
        ..color = Colors.tealAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
