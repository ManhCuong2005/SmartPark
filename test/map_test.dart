import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/core/config/map_config.dart';
import 'package:smartpark/domain/location_service.dart';
import 'package:smartpark/presentation/features/parking/map_load_state.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

final _fixtureTile = MemoryImage(TileProvider.transparentImage);

class MapRepository extends TestRepository {
  MapRepository({super.loggedIn});
  List<Json> mapLots = [mapLot('one', 16.06, 108.22)];
  @override
  ParkingSnapshot fixture() =>
      ParkingSnapshot({...super.fixture().data, 'lots': mapLots});
}

Json mapLot(String id, double? lat, double? lng) => {
  'id': id,
  'name': 'Bãi $id',
  'area': 'Địa chỉ $id',
  'car_rate': 15000,
  'motorcycle_rate': 5000,
  'latitude': lat,
  'longitude': lng,
};

class TestLocation implements LocationService {
  int calls = 0;
  Future<GeoPosition> Function() resolve =
      () async => const GeoPosition(16.07, 108.23);
  @override
  Future<GeoPosition> currentPosition() {
    calls++;
    return resolve();
  }
}

class TestTiles extends TileProvider {
  bool failing = false;
  int requests = 0;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return failing ? _FailedImage() : _fixtureTile;
  }
}

class _FailedImage extends ImageProvider<_FailedImage> {
  @override
  Future<_FailedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _FailedImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: Future<ui.Codec>.error(StateError('Simulated tile unavailable')),
    scale: 1,
  );
}

Future<ParkController> mountMap(
  WidgetTester tester, {
  required MapRepository backend,
  required TestTiles tiles,
  TestLocation? location,
  double width = 390,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ParkController(backend, monitorConnectivity: false);
  await controller.initialize();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        parkControllerProvider.overrideWith((ref) => controller),
        mapTileProviderFactoryProvider.overrideWithValue(() => tiles),
        locationServiceProvider.overrideWithValue(location ?? TestLocation()),
        themeModeProvider.overrideWith(
          (ref) => dark ? ThemeMode.dark : ThemeMode.light,
        ),
      ],
      child: const SmartParkApp(initialRoute: '/parking/map'),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUpAll(() async {
    final ready = Completer<void>();
    final stream = _fixtureTile.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (_, __) {
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    await ready.future;
    stream.removeListener(listener);
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'map coordinates reject missing, non-finite and unprojectable values',
    () {
      expect(MapConfig.usableCoordinates(16.06, 108.22), isTrue);
      for (final point in [
        (null, 108.2),
        (90.0, 108.2),
        (16.0, 181.0),
        (double.nan, 1.0),
        (1.0, double.infinity),
      ]) {
        expect(MapConfig.usableCoordinates(point.$1, point.$2), isFalse);
      }
    },
  );

  testWidgets(
    'map loading times out, can recover late, and resets errors on retry',
    (tester) async {
      final load = MapLoadState(timeout: const Duration(seconds: 2));
      load.restart();
      expect(load.status, MapLoadStatus.loading);
      await tester.pump(const Duration(seconds: 3));
      expect(load.status, MapLoadStatus.unavailable);
      load.imageLoaded();
      expect(load.status, MapLoadStatus.ready);
      load.imageFailed();
      expect(load.status, MapLoadStatus.partial);
      load.restart();
      load.imageLoaded();
      expect(load.status, MapLoadStatus.ready);
      load.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tile failure offers retry and successful retry removes error', (
    tester,
  ) async {
    final tiles = TestTiles()..failing = true;
    await mountMap(tester, backend: MapRepository(), tiles: tiles);
    expect(
      find.text('Chưa tải được nền bản đồ. Kiểm tra kết nối và thử lại.'),
      findsOneWidget,
    );
    final requestsBeforeRetry = tiles.requests;
    tiles.failing = false;
    await tester.tap(find.text('Thử lại bản đồ'));
    await tester.pumpAndSettle();
    expect(tiles.requests, greaterThan(requestsBeforeRetry));
    expect(find.text('Thử lại bản đồ'), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lots arriving after the map mounts move the camera once', (
    tester,
  ) async {
    final backend = MapRepository()..mapLots = [];
    final controller = await mountMap(
      tester,
      backend: backend,
      tiles: TestTiles(),
    );
    final map =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    backend.mapLots = [
      mapLot('hanoi-one', 21.02, 105.82),
      mapLot('hanoi-two', 21.04, 105.85),
    ];
    controller.update(() => controller.snapshot = backend.fixture());
    await tester.pumpAndSettle();
    expect(map.camera.center.latitude, closeTo(21.03, .02));
    expect(map.camera.center.longitude, closeTo(105.835, .02));
    final center = map.camera.center;
    controller.update(() => controller.snapshot = backend.fixture());
    await tester.pumpAndSettle();
    expect(map.camera.center, center);
  });

  testWidgets(
    'selecting a marker updates selected lot without recreating tiles',
    (tester) async {
      final backend =
          MapRepository()
            ..mapLots = [
              mapLot('one', 16.06, 108.22),
              mapLot('two', 16.08, 108.24),
            ];
      final tiles = TestTiles();
      final controller = await mountMap(tester, backend: backend, tiles: tiles);
      final base = tester.widget<TileLayer>(find.byType(TileLayer));
      final requests = tiles.requests;
      await tester.tap(find.byKey(const ValueKey('map-lot-two')));
      await tester.pumpAndSettle();
      expect(controller.selectedLotId, 'two');
      expect(
        identical(base, tester.widget<TileLayer>(find.byType(TileLayer))),
        isTrue,
      );
      expect(tiles.requests, requests);
      expect(base.panBuffer, 0);
      expect(base.resolvedRetinaMode, RetinaMode.disabled);
    },
  );

  testWidgets('missing coordinates do not hide the base map', (tester) async {
    final backend =
        MapRepository()
          ..mapLots = [
            mapLot('missing', null, null),
            mapLot('invalid', 90, 108),
          ];
    await mountMap(tester, backend: backend, tiles: TestTiles());
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('0 bãi có vị trí trên bản đồ'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('refusing GPS leaves the map usable', (tester) async {
    final location =
        TestLocation()
          ..resolve =
              () async =>
                  throw const ParkFailure('Chưa được cấp quyền vị trí.');
    await mountMap(
      tester,
      backend: MapRepository(),
      tiles: TestTiles(),
      location: location,
    );
    expect(location.calls, 0);
    await tester.ensureVisible(find.text('Vị trí của tôi'));
    await tester.tap(find.text('Vị trí của tôi'));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    expect(find.text('Chưa được cấp quyền vị trí.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('GPS is requested once and positions the map after completion', (
    tester,
  ) async {
    final pending = Completer<GeoPosition>();
    final location = TestLocation()..resolve = () => pending.future;
    await mountMap(
      tester,
      backend: MapRepository(),
      tiles: TestTiles(),
      location: location,
    );
    await tester.ensureVisible(find.text('Vị trí của tôi'));
    await tester.tap(find.text('Vị trí của tôi'));
    await tester.pump();
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Vị trí của tôi'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    pending.complete(const GeoPosition(16.09, 108.25));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    final map =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    expect(map.camera.center.latitude, closeTo(16.09, .001));
    expect(map.camera.zoom, 15);
  });

  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('map fits $width pixels with attribution and controls', (
      tester,
    ) async {
      await mountMap(
        tester,
        backend: MapRepository(),
        tiles: TestTiles(),
        width: width,
        dark: width == 390,
      );
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text(MapConfig.attribution), findsOneWidget);
      expect(find.byTooltip('Hiện tất cả bãi'), findsOneWidget);
      final map =
          tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
      final zoom = map.camera.zoom;
      await tester.tap(find.byTooltip('Phóng to'));
      await tester.pumpAndSettle();
      expect(map.camera.zoom, zoom + 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('public base map can open without signing in', (tester) async {
    await mountMap(
      tester,
      backend: MapRepository(loggedIn: false)..mapLots = [],
      tiles: TestTiles(),
    );
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
