// Composition root: Presentation depends on Domain contracts; only this module
// selects concrete Supabase/Drift/platform implementations.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local/parking_database.dart';
import '../data/plate_recognizer.dart';
import '../data/supabase_parking_repository.dart';
import '../domain/parking_repository.dart';
import '../presentation/park_controller.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) =>
      SupabaseParkingRepository(Supabase.instance.client, ParkingDatabase()),
);
final parkControllerProvider = ChangeNotifierProvider<ParkController>((ref) {
  final controller = ParkController(
    ref.watch(parkingRepositoryProvider),
    plateService: PlateRecognizer(),
  );
  unawaited(controller.initialize());
  return controller;
});
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
