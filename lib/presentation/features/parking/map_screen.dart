import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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
  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    await runAction(context, () async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ParkFailure('Bật dịch vụ vị trí trên thiết bị.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ParkFailure(
          'Chưa được cấp quyền vị trí. Có thể tìm theo tên bãi.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => position = LatLng(p.latitude, p.longitude));
      map.move(position!, 15);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lots =
        widget.repository.lots
            .where((l) => l.latitude != null && l.longitude != null)
            .toList();
    final selected = widget.repository.lot;
    final center = lots.firstOrNull;
    return ParkPage(
      bottom: const ParkBottomNav(active: 1),
      child: Column(
        children: [
          const PageHeading('Bản đồ bãi đỗ', back: false),
          SizedBox(
            height: 380,
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter:
                    center == null
                        ? const LatLng(16.05, 108.2)
                        : LatLng(center.latitude!, center.longitude!),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'vn.smartpark.smartpark',
                ),
                MarkerLayer(
                  markers: [
                    for (final l in lots)
                      Marker(
                        point: LatLng(l.latitude!, l.longitude!),
                        width: 100,
                        height: 48,
                        child: FilledButton(
                          onPressed:
                              () => widget.repository.update(
                                () => widget.repository.lot = l,
                              ),
                          child: Text(
                            l.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    if (position != null)
                      Marker(
                        point: position!,
                        child: const Icon(
                          Icons.my_location,
                          color: ParkColors.blue,
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('© OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: locate,
                      child: const Text('Vị trí của tôi'),
                    ),
                    const Spacer(),
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
                if (selected.id.isNotEmpty)
                  ParkingCard(
                    lot: selected,
                    onTap:
                        () => Navigator.pushNamed(context, '/parking/detail'),
                  ),
                if (lots.isEmpty)
                  const Text(
                    'Chưa có bãi với tọa độ. Chủ bãi cần bổ sung vị trí.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Bản đồ nền cần mạng. Danh sách đã tải vẫn xem được khi ngoại tuyến.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
