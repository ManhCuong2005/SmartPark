import 'package:flutter/material.dart';

class ParkingLot {
  const ParkingLot(
    this.name,
    this.area,
    this.distance,
    this.spaces,
    this.hourlyRate,
    this.tint,
  );
  final String name, area, distance;
  final int spaces, hourlyRate;
  final Color tint;
}

class Vehicle {
  Vehicle(this.label, this.plate, {this.isDefault = false});
  String label, plate;
  bool isDefault;
}

/// In-memory demonstration only. No payment, authentication or QR services.
class MockParkRepository extends ChangeNotifier {
  static const lots = [
    ParkingLot(
      'Bãi xe Trung tâm',
      'Hải Châu',
      '1,2 km',
      24,
      15000,
      Color(0xFFDBEAF9),
    ),
    ParkingLot(
      'Bãi xe Sông Hàn',
      'Sơn Trà',
      '2,4 km',
      18,
      12000,
      Color(0xFFDFEEE9),
    ),
    ParkingLot(
      'Bãi xe Vincom',
      'Ngô Quyền',
      '3,1 km',
      8,
      20000,
      Color(0xFFDBEAF9),
    ),
  ];
  ParkingLot lot = lots.first;
  String slot = 'A07';
  int day = 22;
  TimeOfDay start = const TimeOfDay(hour: 14, minute: 30);
  TimeOfDay end = const TimeOfDay(hour: 16, minute: 30);
  String payment = 'VNPAY QR';
  bool booked = false, notificationsRead = false, signedIn = false;
  String name = 'Nguyễn Văn A', email = 'nguyenvana@email.com';
  final vehicles = [
    Vehicle('Ô tô cá nhân', '43A - 123.45', isDefault: true),
    Vehicle('Xe máy', '43D1 - 567.89'),
  ];
  final Set<String> occupied = {'A02', 'A04', 'A09', 'A13'};
  final Set<String> staffOccupied = {
    'A02',
    'A04',
    'A07',
    'A08',
    'A09',
    'A13',
    'A16',
  };
  String staffSlot = 'A03';
  bool checkedIn = false;
  int get durationMinutes =>
      (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  int get total => (durationMinutes / 60 * lot.hourlyRate).ceil();
  Vehicle get vehicle =>
      vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first);
  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  void resetSession() {
    signedIn = false;
    notifyListeners();
  }
}

String money(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
String clock(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
