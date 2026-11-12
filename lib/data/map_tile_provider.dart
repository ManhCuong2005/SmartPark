import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/config/map_config.dart';

TileProvider createParkingTileProvider() => NetworkTileProvider(
  // Browser supplies its own User-Agent and Referer; do not trigger a CORS
  // preflight with native-only headers.
  headers: kIsWeb ? null : {'User-Agent': MapConfig.userAgent},
  attemptDecodeOfHttpErrorResponses: false,
  cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: MapConfig.maxCacheBytes,
  ),
);
