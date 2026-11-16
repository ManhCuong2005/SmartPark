import 'package:shared_preferences/shared_preferences.dart';

Map<String, String?> loadKioskConfiguration(
  SharedPreferences preferences,
  String actor,
) => {
  'lot': preferences.getString('kiosk:lot:$actor'),
  'direction': preferences.getString('kiosk:direction:$actor'),
};

Future<bool> saveKioskConfiguration(
  SharedPreferences preferences,
  String actor,
  String? lot,
  String? direction,
) async {
  if (lot == null || direction == null) {
    return await preferences.remove('kiosk:lot:$actor') &&
        await preferences.remove('kiosk:direction:$actor');
  }
  return await preferences.setString('kiosk:lot:$actor', lot) &&
      await preferences.setString('kiosk:direction:$actor', direction);
}
