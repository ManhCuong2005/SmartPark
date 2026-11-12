import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../domain/location_service.dart';
import '../domain/models.dart';

class DeviceLocationService implements LocationService {
  @override
  Future<GeoPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ParkFailure('Bật dịch vụ vị trí để tìm vị trí của bạn.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ParkFailure(
        'Chưa được cấp quyền vị trí. Bạn vẫn có thể xem và chọn bãi trên bản đồ.',
      );
    }
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoPosition(fix.latitude, fix.longitude);
    } on TimeoutException {
      throw const ParkFailure(
        'Chưa tìm được vị trí. Hãy thử lại ở nơi thoáng hơn.',
      );
    }
  }
}
