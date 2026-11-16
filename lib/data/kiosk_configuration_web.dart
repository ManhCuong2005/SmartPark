import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

// Each browser tab keeps its own lane; refreshing entry must not restore exit.
Map<String, String?> loadKioskConfiguration(
  SharedPreferences preferences,
  String actor,
) {
  final saved = web.window.sessionStorage.getItem('kiosk:configuration:$actor');
  return saved == null
      ? {}
      : Map<String, String?>.from(jsonDecode(saved) as Map);
}

Future<bool> saveKioskConfiguration(
  SharedPreferences preferences,
  String actor,
  String? lot,
  String? direction,
) async {
  if (lot == null || direction == null) {
    web.window.sessionStorage.removeItem('kiosk:configuration:$actor');
  } else {
    web.window.sessionStorage.setItem(
      'kiosk:configuration:$actor',
      jsonEncode({'lot': lot, 'direction': direction}),
    );
  }
  return true;
}
