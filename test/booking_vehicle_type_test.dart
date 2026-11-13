import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class BookingVehiclesRepository extends TestRepository {
  List<Json> vehicleRows = [];
  @override
  ParkingSnapshot fixture() =>
      ParkingSnapshot({...super.fixture().data, 'vehicles': vehicleRows});

  Json addedVehicle(
    String id,
    String kind,
    String plate, {
    bool isDefault = false,
  }) => {
    'id': id,
    'user_id': account,
    'label': id,
    'plate': plate,
    'kind': kind,
    'is_default': isDefault,
    'version': 1,
  };
}

Future<ParkController> mountBooking(
  WidgetTester tester,
  BookingVehiclesRepository backend,
) async {
  final state = ParkController(backend, monitorConnectivity: false);
  await state.initialize();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [parkControllerProvider.overrideWith((ref) => state)],
      child: const SmartParkApp(initialRoute: '/parking/detail'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đặt chỗ đỗ xe'));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets(
    'choose a saved vehicle kind before dates, then choose only vehicles of that kind',
    (tester) async {
      final backend = BookingVehiclesRepository();
      backend.vehicleRows = [
        backend.addedVehicle('Car A', 'car', '43A12345', isDefault: true),
        backend.addedVehicle('Bike A', 'motorcycle', '43B112345'),
        backend.addedVehicle('Bike B', 'motorcycle', '43B154321'),
      ];
      final state = await mountBooking(tester, backend);
      expect(find.text('Chọn loại phương tiện'), findsOneWidget);
      expect(find.text('Ngày vào'), findsNothing);
      expect(state.bookingVehicleKind, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tiếp tục'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Xe máy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn thời gian'), findsOneWidget);
      expect(state.bookingVehicleKind, 'motorcycle');
      expect(state.vehicle.plate, '43B112345');
      expect(state.total, 10000);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.items!.map((item) => item.value), ['Bike A', 'Bike B']);
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bike B · 43B154321').last);
      await tester.pumpAndSettle();
      expect(state.vehicle.plate, '43B154321');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đặt chỗ'), findsOneWidget);
      expect(find.text('Xe máy'), findsOneWidget);
      expect(find.text('Ô tô'), findsNothing);
      expect(find.text('43B154321'), findsOneWidget);
      expect(backend.executions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one saved kind is automatic and foreign or deleted vehicles add no choices',
    (tester) async {
      final backend = BookingVehiclesRepository();
      backend.vehicleRows = [
        backend.addedVehicle('Car A', 'car', '43A12345'),
        {
          ...backend.addedVehicle('Deleted bike', 'motorcycle', '43B112345'),
          'deleted': true,
        },
        {
          ...backend.addedVehicle('Foreign bike', 'motorcycle', '43B154321'),
          'user_id': 'another-user',
        },
      ];
      final state = await mountBooking(tester, backend);
      expect(find.text('Chọn thời gian'), findsOneWidget);
      expect(find.text('Chọn loại phương tiện'), findsNothing);
      expect(state.bookingVehicleKinds, ['car']);
      expect(find.text('Xe máy'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('Car A · 43A12345'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no vehicles requires adding one before choosing the date', (
    tester,
  ) async {
    final backend = BookingVehiclesRepository();
    await mountBooking(tester, backend);
    expect(find.text('Chọn loại phương tiện'), findsOneWidget);
    expect(find.text('Ô tô'), findsNothing);
    expect(find.text('Xe máy'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tiếp tục'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Thêm phương tiện'));
    await tester.pumpAndSettle();
    expect(find.text('Phương tiện của tôi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'switching kind clears the previous vehicle scope and rejects a vehicle from another kind',
    () async {
      final backend = BookingVehiclesRepository();
      backend.vehicleRows = [
        backend.addedVehicle('Car A', 'car', '43A12345'),
        backend.addedVehicle('Bike A', 'motorcycle', '43B112345'),
      ];
      final state = ParkController(backend, monitorConnectivity: false);
      addTearDown(state.dispose);
      await state.initialize();
      state.selectBookingVehicleKind('car');
      await state.loadAvailability();
      final start = state.startsAt, end = state.endsAt;
      state.selectBookingVehicleKind('motorcycle');
      expect(state.vehicle.id, 'Bike A');
      expect(state.bookingVehicles.map((v) => v.id), ['Bike A']);
      expect(state.startsAt, start);
      expect(state.endsAt, end);
      expect(() => state.selectVehicle('Car A'), throwsA(isA<ParkFailure>()));
      expect(backend.executions, 0);
    },
  );
}
