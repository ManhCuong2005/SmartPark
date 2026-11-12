// Composition root: Presentation depends on Domain contracts; only this module
// selects concrete Supabase/Drift/platform implementations.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local/parking_database.dart';
import '../data/plate_recognizer.dart';
import '../data/device_location_service.dart';
import '../data/map_tile_provider.dart';
import '../data/firebase_device_notifications.dart';
import '../data/supabase_parking_repository.dart';
import '../domain/parking_repository.dart';
import '../domain/location_service.dart';
import '../presentation/park_controller.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) =>
      SupabaseParkingRepository(Supabase.instance.client, ParkingDatabase()),
);
final parkControllerProvider = ChangeNotifierProvider<ParkController>((ref) {
  final controller = ParkController(
    ref.watch(parkingRepositoryProvider),
    plateService: PlateRecognizer(),
    deviceNotifications: FirebaseDeviceNotifications(Supabase.instance.client),
  );
  unawaited(controller.initialize());
  return controller;
});
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final appNavigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());
final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);
final mapTileProviderFactoryProvider = Provider<TileProvider Function()>(
  (ref) => createParkingTileProvider,
);
