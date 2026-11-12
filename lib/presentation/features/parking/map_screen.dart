import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'parking_screens.dart' show ParkingCard;

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final map = MapController();
  LatLng? position;
  bool _locating = false;
  String? _locationError;
  bool _mapReady = false;

  List<ParkingLot> get _usableLots => widget.repository.lots
      .where((l) =>
          l.latitude != null &&
          l.longitude != null &&
          l.latitude! >= -90 &&
          l.latitude! <= 90 &&
          l.longitude! >= -180 &&
          l.longitude! <= 180 &&
          (l.latitude != 0 || l.longitude != 0))
      .toList();

  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  void _fitLots() {
    if (!_mapReady) return;
    final lots = _usableLots;
    if (lots.isEmpty) return;
    if (lots.length == 1) {
      map.move(LatLng(lots.first.latitude!, lots.first.longitude!), 15);
    } else {
      map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            for (final lot in lots) LatLng(lot.latitude!, lot.longitude!),
          ]),
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    }
  }

  void _zoom(double delta) {
    if (_mapReady) {
      map.move(map.camera.center, (map.camera.zoom + delta).clamp(3.0, 18.0));
    }
  }

  Future<void> locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ParkFailure('Vui lòng bật dịch vụ vị trí (GPS) trên thiết bị.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ParkFailure('Chưa được cấp quyền vị trí. Bạn có thể chọn bãi trên bản đồ.');
      }

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => position = LatLng(p.latitude, p.longitude));
      if (_mapReady && position != null) {
        map.move(position!, 15);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e is ParkFailure ? e.message : 'Không lấy được vị trí hiện tại.';
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = _usableLots;
    final selected = widget.repository.lot;
    final firstLot = lots.firstOrNull;
    final colors = Theme.of(context).colorScheme;

    return ParkPage(
      bottom: const ParkBottomNav(active: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading('Bản đồ bãi đỗ', back: false),
          SizedBox(
            height: 380,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: map,
                  options: MapOptions(
                    initialCenter: firstLot == null
                        ? const LatLng(16.0544, 108.2022) // Đà Nẵng mặc định
                        : LatLng(firstLot.latitude!, firstLot.longitude!),
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 18,
                    onMapReady: () {
                      _mapReady = true;
                      if (lots.isNotEmpty) _fitLots();
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.smartpark.smartpark.customer',
                      maxZoom: 19,
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final l in lots)
                          Marker(
                            point: LatLng(l.latitude!, l.longitude!),
                            width: 120,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: selected.id == l.id ? colors.primary : colors.surface,
                                foregroundColor: selected.id == l.id ? colors.onPrimary : colors.onSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                elevation: selected.id == l.id ? 4 : 1,
                              ),
                              onPressed: () => widget.repository.update(
                                () => widget.repository.lot = l,
                              ),
                              child: Text(
                                l.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (position != null)
                          Marker(
                            point: position!,
                            width: 32,
                            height: 32,
                            child: const Icon(
                              Icons.my_location,
                              color: ParkColors.blue,
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                    const _MapAttribution(),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(10),
                    color: colors.surface,
                    child: Column(
                      children: [
                        IconButton(
                          tooltip: 'Xem tất cả bãi',
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
              ],
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
                      onPressed: _locating ? null : locate,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Vị trí của tôi'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        '/parking/list',
                      ),
                      child: const Text('Danh sách bãi'),
                    ),
                  ],
                ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _locationError!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                Text(
                  '${lots.length} bãi có toạ độ trên bản đồ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (selected.id.isNotEmpty)
                  ParkingCard(
                    lot: selected,
                    onTap: () => Navigator.pushNamed(context, '/parking/detail'),
                  ),
                if (lots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chưa có bãi với toạ độ hợp lệ. Chủ bãi cần bổ sung vị trí.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Bản đồ cần kết nối mạng để tải ảnh vệ tinh. Danh sách bãi đã lưu vẫn xem được ngoại tuyến.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
        child: Container(
          color: Colors.white.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      );
}
