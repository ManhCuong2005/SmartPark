/// Public map configuration; no backend secrets or location tracking.
abstract final class MapConfig {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
  );
  static const attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: 'Style HOT · tuiles OSM France',
  );
  static const attributionUrl = String.fromEnvironment(
    'MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.fr/fonds-de-carte/',
  );
  static const userAgent =
      'SmartPark/1.0 (+https://github.com/ManhCuong2005/SmartPark)';
  static const maxCacheBytes = 64 * 1024 * 1024;

  // Raster tiles use Web Mercator: poles cannot be projected onto this map.
  static bool usableCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 85.05112878 &&
      longitude.abs() <= 180;
}
