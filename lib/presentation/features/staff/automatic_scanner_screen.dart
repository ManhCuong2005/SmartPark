import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../data/scan_feedback.dart';
import '../../../data/kiosk_configuration.dart';
import '../../../domain/plate_scanning.dart';
import '../../automatic_scan_controller.dart';
import '../../park_controller.dart';
import 'live_plate_camera.dart';

class StaffScannerScreen extends StatefulWidget {
  const StaffScannerScreen({
    super.key,
    required this.repository,
    this.feedbackFactory = DeviceScanFeedback.new,
    this.cameraBuilder,
  });
  final ParkController repository;
  final ScanFeedback Function() feedbackFactory;
  final Widget Function(BuildContext, Future<void> Function(List<String>?))?
  cameraBuilder;
  @override
  State<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends State<StaffScannerScreen>
    with WidgetsBindingObserver {
  SharedPreferences? _preferences;
  AutomaticScanController? _scan;
  ScanFeedback? _feedback;
  String? _lotId, _error;
  ScanDirection? _direction;
  bool _starting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repository.addListener(_repositoryChanged);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      await widget.repository.refresh();
      if (!mounted) return;
      final configuration = loadKioskConfiguration(
        _preferences!,
        widget.repository.userId!,
      );
      final saved = configuration['lot'];
      final direction =
          ScanDirection.values
              .where((d) => d.name == configuration['direction'])
              .firstOrNull;
      if (saved != null &&
          direction != null &&
          widget.repository.staffLots.any((l) => l.id == saved)) {
        await _start(saved, direction);
      } else {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Chưa tải được bãi hoặc bộ nhớ thiết bị. Vui lòng thử lại.',
        );
      }
    }
  }

  void _repositoryChanged() {
    if (!mounted) return;
    if (_lotId != null &&
        !widget.repository.staffLots.any((l) => l.id == _lotId)) {
      _closeSession();
      _lotId = null;
      _error = 'Quyền quét tại bãi đã thay đổi. Vui lòng chọn lại bãi.';
    }
    setState(() {});
  }

  Future<void> _start(String lotId, ScanDirection direction) async {
    if (_starting || _preferences == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final actor = widget.repository.userId;
      if (!widget.repository.online ||
          !widget.repository.staffLots.any((l) => l.id == lotId)) {
        throw const ParkFailure(
          'Cần kết nối máy chủ và quyền quản trị tại bãi này.',
        );
      }
      final feedback = widget.feedbackFactory();
      _feedback = feedback;
      await feedback.prepare();
      if (!mounted || widget.repository.userId != actor) return;
      final sessionKey = 'kiosk:session:$actor:$lotId:${direction.name}';
      final sessionId =
          _preferences!.getString(sessionKey) ?? const Uuid().v4();
      if (!await _preferences!.setString(sessionKey, sessionId) ||
          !await saveKioskConfiguration(
            _preferences!,
            actor!,
            lotId,
            direction.name,
          )) {
        throw const ParkFailure('Không lưu được chiều camera.');
      }
      await widget.repository.openKiosk(sessionId, lotId, direction);
      if (!mounted || widget.repository.userId != actor) return;
      final scan = AutomaticScanController(
        execute:
            (id, plate) => widget.repository.scanPlate(
              id,
              lotId,
              plate,
              sessionId: sessionId,
              direction: direction,
            ),
        feedback: feedback,
        preferences: _preferences!,
        storageKey: 'kiosk:pending:$actor:$lotId:${direction.name}',
      );
      scan.restore();
      scan.addListener(_changed);
      setState(() {
        _lotId = lotId;
        _direction = direction;
        _scan = scan;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      await _feedback?.dispose();
      _feedback = null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _closeSession() {
    _scan?.removeListener(_changed);
    _scan?.dispose();
    _scan = null;
    final feedback = _feedback;
    _feedback = null;
    if (feedback != null) unawaited(feedback.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _scan?.pause(state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      unawaited(_feedback?.stop() ?? Future<void>.value());
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_repositoryChanged);
    WidgetsBinding.instance.removeObserver(this);
    _closeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    final lot =
        widget.repository.staffLots.where((l) => l.id == _lotId).firstOrNull;
    return PopScope(
      canPop: scan == null,
      child: Scaffold(
        backgroundColor: scan == null ? null : Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            scan == null
                ? (lot?.name ?? 'Chọn bãi quét')
                : '${_direction!.label} · ${lot!.name}',
          ),
          actions: [
            if (scan != null)
              TextButton(
                onPressed:
                    scan.busy || scan.hasPending
                        ? null
                        : () async {
                          _closeSession();
                          await saveKioskConfiguration(
                            _preferences!,
                            widget.repository.userId!,
                            null,
                            null,
                          );
                          if (mounted) setState(() => _lotId = null);
                        },
                child: const Text('Đổi bãi / cam'),
              ),
            if (scan == null)
              IconButton(
                tooltip: 'Tải lại bãi',
                onPressed: _starting ? null : _restore,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body:
            scan == null
                ? SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child:
                          _starting
                              ? const CircularProgressIndicator()
                              : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Text(
                                    lot == null
                                        ? 'Chọn bãi để bắt đầu quét tự động'
                                        : 'Chọn chức năng camera',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(_error!),
                                    ),
                                  if (widget.repository.staffLots.isEmpty)
                                    const Text(
                                      'Tài khoản quản trị chưa có bãi trong CSDL.',
                                    ),
                                  if (lot != null) ...[
                                    for (final direction
                                        in ScanDirection.values)
                                      Card(
                                        child: ListTile(
                                          leading: Icon(
                                            direction == ScanDirection.entry
                                                ? Icons.login
                                                : Icons.logout,
                                          ),
                                          title: Text(direction.label),
                                          subtitle: Text(
                                            direction == ScanDirection.entry
                                                ? 'Chỉ xác nhận xe vào. Không thanh toán, không cho xe ra.'
                                                : 'Chỉ xác nhận xe ra và thanh toán. Không cho xe vào.',
                                          ),
                                          onTap:
                                              () => _start(lot.id, direction),
                                        ),
                                      ),
                                    TextButton(
                                      onPressed:
                                          () => setState(() => _lotId = null),
                                      child: const Text('Chọn bãi khác'),
                                    ),
                                  ],
                                  if (lot == null)
                                    for (final item
                                        in widget.repository.staffLots)
                                      Card(
                                        child: ListTile(
                                          title: Text(item.name),
                                          subtitle: Text(item.area),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),
                                          onTap:
                                              () => setState(() {
                                                _lotId = item.id;
                                                _error = null;
                                              }),
                                        ),
                                      ),
                                ],
                              ),
                    ),
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child:
                          widget.cameraBuilder?.call(
                            context,
                            scan.acceptFrame,
                          ) ??
                          LivePlateCamera(
                            key: ValueKey('$_lotId:${_direction!.name}'),
                            settingsKey:
                                'kiosk:camera:${widget.repository.userId}:$_lotId:${_direction!.name}',
                            onFrame: scan.acceptFrame,
                            shouldRead: () => scan.readyForFrame,
                            onCameraChanged: () {
                              scan.pause(true);
                              scan.pause(false);
                            },
                          ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        color:
                            scan.fatal
                                ? Colors.red.shade900
                                : const Color(0xFF102329),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (scan.plate.isNotEmpty)
                              Text(
                                scan.plate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                scan.status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            if (scan.retryAfter != null &&
                                DateTime.now().isBefore(scan.retryAfter!))
                              const Text(
                                'Tự quét lại sau 5 giây',
                                style: TextStyle(color: Colors.white70),
                              ),
                            if (scan.fatal)
                              TextButton(
                                onPressed: () {
                                  _closeSession();
                                  unawaited(_start(_lotId!, _direction!));
                                },
                                child: const Text('Khởi động lại quét'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
