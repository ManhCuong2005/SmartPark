import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/map_config.dart';
import '../../../domain/location_service.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'map_load_state.dart';
import 'parking_screens.dart' show ParkingCard;

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({
    super.key,
    required this.repository,
    required this.locationService,
    required this.tileProviderFactory,
  });
  final ParkController repository;
  final LocationService locationService;
  final TileProvider Function() tileProviderFactory;
  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final map = MapController();
  final _load = MapLoadState();
  final _resetTiles = StreamController<void>.broadcast();
  late final TileLayer _baseLayer;
  late final List<ParkingLot> _initialLots;
  bool _mapReady = false, _didFitLots = false, _locating = false;
  bool _reportScheduled = false, _tileSucceeded = false, _tileFailed = false;
  LatLng? _position;
  String? _locationError;

  List<ParkingLot> get _lots =>
      widget.repository.lots
          .where((l) => MapConfig.usableCoordinates(l.latitude, l.longitude))
          .toList();

  @override
  void initState() {
    super.initState();
    _initialLots = _lots;
    _didFitLots = _initialLots.isNotEmpty;
    _load.restart();
    // Keep the base layer/provider stable when Supabase refreshes markers or a
    // selection changes. TileLayer owns/disposes the provider.
    _baseLayer = TileLayer(
      urlTemplate: MapConfig.tileUrl,
      tileProvider: widget.tileProviderFactory(),
      userAgentPackageName: 'vn.smartpark.smartpark.customer',
      minZoom: 3,
      maxZoom: 18,
      maxNativeZoom: 19,
      retinaMode: false,
      panBuffer: 0,
      keepBuffer: 1,
      tileDisplay: const TileDisplay.instantaneous(),
      tileUpdateTransformer: TileUpdateTransformers.throttle(
        const Duration(milliseconds: 100),
      ),
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
      reset: _resetTiles.stream,
      errorTileCallback: (_, __, ___) => _reportTile(failed: true),
      tileBuilder: (context, child, tile) {
        if (tile.imageInfo != null && !tile.loadError) {
          _reportTile(failed: false);
        }
        return child;
      },
    );
  }

  @override
  void didUpdateWidget(covariant ParkingMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lots = _lots;
    if (lots.isEmpty) _didFitLots = false;
    // Data can arrive after the first frame. Initial camera settings alone do
    // not move an already-created map.
    if (!_didFitLots && lots.isNotEmpty) {
      _didFitLots = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _fitLots();
      });
    }
  }

  void _reportTile({required bool failed}) {
    if (!mounted) return;
    if (failed) {
      _tileFailed = true;
    } else {
      _tileSucceeded = true;
    }
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      if (_tileSucceeded) _load.imageLoaded();
      if (_tileFailed) _load.imageFailed();
      _tileSucceeded = _tileFailed = false;
    });
  }

  void _retryTiles() {
    _tileSucceeded = _tileFailed = false;
    _load.restart();
    _resetTiles.add(null);
  }

  void _fitLots() {
    if (!_mapReady) return;
    final lots = _lots;
    if (lots.isEmpty) return;
    if (lots.length == 1) {
      map.move(LatLng(lots.first.latitude!, lots.first.longitude!), 15);
    } else {
      map.fitCamera(_cameraFit(lots));
    }
  }

  CameraFit _cameraFit(List<ParkingLot> lots) => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints([
      for (final lot in lots) LatLng(lot.latitude!, lot.longitude!),
    ]),
    padding: const EdgeInsets.fromLTRB(54, 70, 54, 54),
    maxZoom: 15,
  );

  void _zoom(double delta) {
    if (_mapReady) {
      map.move(map.camera.center, (map.camera.zoom + delta).clamp(3.0, 18.0));
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final fix = await widget.locationService.currentPosition();
      if (!mounted) return;
      if (!MapConfig.usableCoordinates(fix.latitude, fix.longitude)) {
        throw const ParkFailure('Vị trí nhận được không hợp lệ. Hãy thử lại.');
      }
      setState(() => _position = LatLng(fix.latitude, fix.longitude));
      if (_mapReady) map.move(_position!, 15);
    } catch (e) {
      if (!mounted) return;
      setState(
        () =>
            _locationError =
                e is ParkFailure
                    ? e.message
                    : 'Không lấy được vị trí. Bạn vẫn có thể chọn bãi trên bản đồ.',
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _load.dispose();
    unawaited(_resetTiles.close());
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lots = _lots;
    final selected = widget.repository.lot;
    final first = _initialLots.firstOrNull;
    final colors = Theme.of(context).colorScheme;
    return ParkPage(
      bottom: const ParkBottomNav(active: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading('Bản đồ bãi đỗ', back: false),
          SizedBox(
            height: 380,
            child: RepaintBoundary(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: map,
                    options: MapOptions(
                      initialCenter:
                          first == null
                              ? const LatLng(16.0612, 108.2215)
                              : LatLng(first.latitude!, first.longitude!),
                      initialZoom: 13,
                      initialCameraFit:
                          _initialLots.length > 1
                              ? _cameraFit(_initialLots)
                              : null,
                      minZoom: 3,
                      maxZoom: 18,
                      backgroundColor: colors.surfaceContainerHighest,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () => _mapReady = true,
                    ),
                    children: [
                      _baseLayer,
                      MarkerLayer(
                        markers: [
                          for (final lot in lots)
                            Marker(
                              point: LatLng(lot.latitude!, lot.longitude!),
                              width: 120,
                              height: 44,
                              child: Semantics(
                                button: true,
                                label:
                                    'Chọn bãi ${lot.name}, ${lot.spaces} chỗ trống',
                                child: FilledButton(
                                  key: ValueKey('map-lot-${lot.id}'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        selected.id == lot.id
                                            ? colors.primary
                                            : colors.surface,
                                    foregroundColor:
                                        selected.id == lot.id
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed:
                                      () => widget.repository.update(
                                        () => widget.repository.lot = lot,
                                      ),
                                  child: Text(
                                    lot.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                            ),
                          if (_position != null)
                            Marker(
                              point: _position!,
                              width: 28,
                              height: 28,
                              child: const Icon(
                                Icons.my_location,
                                color: ParkColors.blue,
                                semanticLabel: 'Vị trí hiện tại của bạn',
                              ),
                            ),
                        ],
                      ),
                      const _MapAttribution(),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Hiện tất cả bãi',
                            onPressed: _fitLots,
                            icon: const Icon(Icons.fit_screen),
                          ),
                          IconButton(
                            tooltip: 'Phóng to',
                            onPressed: () => _zoom(1),
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            tooltip: 'Thu nhỏ',
                            onPressed: () => _zoom(-1),
                            icon: const Icon(Icons.remove),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 64,
                    child: ListenableBuilder(
                      listenable: _load,
                      builder:
                          (context, _) => _MapStatus(
                            status: _load.status,
                            onRetry: _retryTiles,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _locating ? null : _locate,
                      icon:
                          _locating
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.my_location, size: 18),
                      label: const Text('Vị trí của tôi'),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pushReplacementNamed(
                            context,
                            '/parking/list',
                          ),
                      child: const Text('Danh sách'),
                    ),
                  ],
                ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_locationError!),
                  ),
                Text(
                  '${lots.length} bãi có vị trí trên bản đồ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (selected.id.isNotEmpty)
                  ParkingCard(
                    lot: selected,
                    onTap:
                        () => Navigator.pushNamed(context, '/parking/detail'),
                  ),
                if (lots.isEmpty)
                  const Text(
                    'Chưa có bãi với tọa độ hợp lệ. Bạn vẫn có thể xem bản đồ; chủ bãi cần bổ sung vị trí bãi.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Bản đồ cần kết nối mạng để tải vùng chưa xem. Danh sách bãi đã lưu vẫn xem được khi ngoại tuyến.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap:
                  () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10),
              ),
            ),
            InkWell(
              onTap: () => launchUrl(Uri.parse(MapConfig.attributionUrl)),
              child: const Text(
                MapConfig.attribution,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapStatus extends StatelessWidget {
  const _MapStatus({required this.status, required this.onRetry});
  final MapLoadStatus status;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (status == MapLoadStatus.ready) return const SizedBox.shrink();
    final loading = status == MapLoadStatus.loading;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const LinearProgressIndicator(),
            Text(
              loading
                  ? 'Đang tải bản đồ…'
                  : status == MapLoadStatus.partial
                  ? 'Một phần bản đồ chưa tải được.'
                  : 'Chưa tải được nền bản đồ. Kiểm tra kết nối và thử lại.',
            ),
            if (!loading)
              TextButton(
                onPressed: onRetry,
                child: const Text('Thử lại bản đồ'),
              ),
          ],
        ),
      ),
    );
  }
}
