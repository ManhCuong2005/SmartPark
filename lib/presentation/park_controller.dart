import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../domain/plate_recognition_service.dart';
import '../domain/parking_repository.dart';
import '../domain/models.dart';
import '../domain/parking_rules.dart';
export '../domain/models.dart';

class ParkingLot {
  const ParkingLot(
    this.id,
    this.name,
    this.area,
    this.spaces,
    this.hourlyRate, {
    this.latitude,
    this.longitude,
    this.motorcycleRate = 0,
  });
  final String id, name, area;
  final int spaces, hourlyRate, motorcycleRate;
  final double? latitude, longitude;
  String get distance => 'Cập nhật từ hệ thống';
  Color get tint => const Color(0xFFDBEAF9);
}

class Vehicle {
  const Vehicle(
    this.id,
    this.label,
    this.plate, {
    this.kind = 'car',
    this.isDefault = false,
    this.version = 0,
  });
  final String id, label, plate, kind;
  final bool isDefault;
  final int version;
}

class ParkController extends ChangeNotifier {
  ParkController(
    this.backend, {
    this.monitorConnectivity = true,
    this.plateService,
  }) {
    final now = DateTime.now().add(const Duration(minutes: 5));
    date = DateTime(now.year, now.month, now.day);
    start = TimeOfDay.fromDateTime(now);
    end = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
    endDate = DateTime(
      now.add(const Duration(hours: 2)).year,
      now.add(const Duration(hours: 2)).month,
      now.add(const Duration(hours: 2)).day,
    );
  }
  final ParkingRepository backend;
  final PlateRecognitionService? plateService;
  final bool monitorConnectivity;
  ParkingSnapshot snapshot = ParkingSnapshot.empty;
  List<PendingOperation> operations = [];
  List<Json> availabilityRows = [];
  String? selectedLotId, selectedSlotId, selectedBookingId, scannedQr;
  String? error;
  bool loading = false, online = false, _disposed = false;
  String? _lastUserId;
  late DateTime date, endDate;
  late TimeOfDay start, end;
  Timer? _timer, _debounce;
  Future<void>? _refreshing;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? get userId => backend.userId;
  bool get signedIn => userId != null;
  String get email => backend.email ?? '';
  Json get profile =>
      snapshot.rows('profiles').where((p) => p['id'] == userId).firstOrNull ??
      {};
  String get name => profile['name'] as String? ?? '';
  bool get canStaff =>
      profile['role'] == 'owner' ||
      snapshot
          .rows('memberships')
          .any((m) => m['user_id'] == userId && m['active'] == true);
  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, start.hour, start.minute);
  DateTime get endsAt =>
      DateTime(endDate.year, endDate.month, endDate.day, end.hour, end.minute);
  int get durationMinutes => endsAt.difference(startsAt).inMinutes;
  List<ParkingLot> get lots =>
      snapshot.rows('lots').map((l) {
        final all = snapshot
            .rows('slots')
            .where((s) => s['lot_id'] == l['id'] && s['enabled'] == true);
        final used = all.where((s) => s['occupied'] == true).length;
        return ParkingLot(
          l['id'] as String,
          l['name'] as String,
          l['area'] as String,
          (all.length - used).clamp(0, all.length),
          l['car_rate'] as int,
          motorcycleRate: l['motorcycle_rate'] as int,
          latitude: (l['latitude'] as num?)?.toDouble(),
          longitude: (l['longitude'] as num?)?.toDouble(),
        );
      }).toList();
  ParkingLot get lot =>
      lots.where((l) => l.id == selectedLotId).firstOrNull ??
      (lots.firstOrNull ?? const ParkingLot('', 'Chưa có bãi đỗ', '', 0, 0));
  set lot(ParkingLot value) {
    selectedLotId = value.id;
    selectedSlotId = null;
    availabilityRows = [];
    unawaited(loadAvailability());
  }

  List<Json> get slots =>
      availabilityRows.isNotEmpty
          ? availabilityRows
          : snapshot.rows('slots').where((s) => s['lot_id'] == lot.id).toList();
  String get slot =>
      slots.where((s) => s['id'] == selectedSlotId).firstOrNull?['code']
          as String? ??
      '';
  set slot(String code) {
    selectedSlotId =
        slots.where((s) => s['code'] == code).firstOrNull?['id'] as String?;
  }

  Set<String> get occupied =>
      slots
          .where((s) => s['occupied'] == true || s['enabled'] == false)
          .map((s) => s['code'] as String)
          .toSet();
  List<Vehicle> get vehicles =>
      snapshot
          .rows('vehicles')
          .where((v) => v['user_id'] == userId && v['deleted'] != true)
          .map(
            (v) => Vehicle(
              v['id'] as String,
              v['label'] as String,
              v['plate'] as String,
              kind: v['kind'] as String,
              isDefault: v['is_default'] == true,
              version: v['version'] as int,
            ),
          )
          .toList();
  String? selectedVehicleId;
  Vehicle get vehicle =>
      vehicles.where((v) => v.id == selectedVehicleId).firstOrNull ??
      vehicles.where((v) => v.isDefault).firstOrNull ??
      vehicles.firstOrNull ??
      const Vehicle('', 'Chưa có phương tiện', '');
  int get total =>
      durationMinutes <= 0
          ? 0
          : (durationMinutes / 60).ceil() *
              (vehicle.kind == 'motorcycle'
                  ? lot.motorcycleRate
                  : lot.hourlyRate);
  List<Json> get bookings => snapshot.rows('bookings');
  Json? get ticket {
    final saved =
        bookings.where((b) => b['id'] == selectedBookingId).firstOrNull;
    if (saved == null) return null;
    var projected = Map<String, dynamic>.from(saved);
    for (final op in operations.where(
      (o) => o.payload['booking_id'] == selectedBookingId,
    )) {
      if (op.state != 'pending') break;
      if (op.kind == 'staff.check_in' && projected['status'] == 'confirmed') {
        projected = {
          ...projected,
          'status': 'parked',
          'checked_in_at': op.payload['occurred_at'],
          'version': (projected['version'] as int) + 1,
          'local_pending': true,
        };
      } else if (op.kind == 'staff.check_out' &&
          projected['status'] == 'parked') {
        projected = {
          ...projected,
          'status': 'completed',
          'checked_out_at': op.payload['occurred_at'],
          'version': (projected['version'] as int) + 1,
          'local_pending': true,
        };
      }
    }
    return projected;
  }

  List<Json> get notifications => snapshot.rows('notifications');
  List<Json> get parked =>
      bookings.where((b) => b['status'] == 'parked').toList();
  String get freshness =>
      online
          ? 'Đã kết nối · ${snapshot.data['server_time'] ?? ''}'
          : 'Ngoại tuyến · dữ liệu đã lưu có thể thay đổi';
  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  Future<void> initialize() async {
    _lastUserId = userId;
    try {
      snapshot = await backend.cachedSnapshot() ?? ParkingSnapshot.empty;
      operations = await backend.pending();
      _notify();
    } catch (e) {
      error = 'Không mở được bộ nhớ cục bộ: $e';
      _notify();
    }
    _subscriptions.add(
      backend.authChanges.listen((_) {
        if (_lastUserId != userId) {
          snapshot = ParkingSnapshot.empty;
          availabilityRows = [];
          operations = [];
          selectedLotId = null;
          selectedSlotId = null;
          selectedBookingId = null;
          scannedQr = null;
          _lastUserId = userId;
          _notify();
        }
        backend.subscribe();
        unawaited(refresh());
      }),
    );
    _subscriptions.add(
      backend.changes.listen((_) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 400),
          () => unawaited(refresh()),
        );
      }),
    );
    if (monitorConnectivity) {
      _subscriptions.add(
        Connectivity().onConnectivityChanged.listen((_) {
          unawaited(refresh());
        }),
      );
      _timer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => unawaited(refresh()),
      );
    }
    backend.subscribe();
    await refresh();
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    if (!signedIn || _disposed) return;
    final id = userId;
    try {
      await backend.synchronize();
      final next = await backend.refresh();
      if (userId != id || _disposed) return;
      snapshot = next;
      online = true;
      error = null;
      operations = await backend.pending();
      if (lot.id.isNotEmpty) await loadAvailability();
    } catch (e) {
      online = false;
      error = e.toString();
      operations = await backend.pending();
    }
    _notify();
  }

  Future<void> loadAvailability() async {
    final id = lot.id;
    if (id.isEmpty || !endsAt.isAfter(startsAt)) return;
    final startTime = startsAt, endTime = endsAt;
    try {
      final next = await backend.availability(id, startTime, endTime);
      if (lot.id == id && startsAt == startTime && endsAt == endTime) {
        availabilityRows = next;
        // Persist availability with the scoped snapshot for offline reading.
        snapshot = ParkingSnapshot({
          ...snapshot.data,
          'availability': next,
          'availability_lot': id,
          'availability_start': startTime.toIso8601String(),
          'availability_end': endTime.toIso8601String(),
        });
      }
    } catch (_) {
      /* Cache remains visibly stale; server still decides booking. */
    }
    _notify();
  }

  Future<bool> authenticate(
    String mail,
    String password, {
    String? fullName,
    String phone = '',
    bool staff = false,
  }) async {
    loading = true;
    error = null;
    _notify();
    try {
      if (fullName != null) {
        final active = await backend.signUp(mail, password, fullName, phone);
        if (!active) {
          error = 'Đã đăng ký. Kiểm tra email xác nhận rồi đăng nhập.';
          return false;
        }
      } else {
        await backend.signIn(mail, password);
      }
      await refresh();
      if (staff && !canStaff) {
        error =
            'Tài khoản chưa được chủ bãi phân công. Có thể đăng nhập giao diện khách.';
        return false;
      }
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  String? _bookingOperation;
  Json? _bookingPayload;
  Future<void> book() async {
    validateReservation(startsAt, endsAt, DateTime.now());
    if (selectedSlotId == null || vehicle.id.isEmpty) {
      throw const ParkFailure('Chọn chỗ đỗ và thêm phương tiện trước.');
    }
    final request = <String, dynamic>{
      'vehicle_id': vehicle.id,
      'slot_id': selectedSlotId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
    };
    // Keep IDs on an ambiguous network failure, so retry cannot double-book.
    if (_bookingPayload == null ||
        request.entries.any((e) => _bookingPayload![e.key] != e.value)) {
      _bookingOperation = const Uuid().v4();
      _bookingPayload = {...request, 'id': const Uuid().v4()};
    }
    final result = await backend.execute(
      _bookingOperation!,
      'booking.create',
      _bookingPayload!,
    );
    selectedBookingId = result['id'] as String;
    snapshot = ParkingSnapshot({
      ...snapshot.data,
      'bookings': [
        result,
        ...bookings.where((b) => b['id'] != selectedBookingId),
      ],
    });
    _bookingPayload = null;
    _bookingOperation = null;
    _notify();
    await refresh();
  }

  Future<void> cancelBooking(Json booking) async {
    await backend.execute(const Uuid().v4(), 'booking.cancel', {
      'booking_id': booking['id'],
      'expected_version': booking['version'],
    });
    await refresh();
  }

  Future<void> saveVehicle({
    Vehicle? old,
    required String label,
    required String plate,
    String kind = 'car',
    bool isDefault = false,
    bool deleted = false,
  }) async {
    if (!isValidPlate(plate)) {
      throw const ParkFailure(
        'Biển số chưa đúng định dạng Việt Nam. Vui lòng kiểm tra.',
      );
    }
    final id = old?.id ?? const Uuid().v4();
    if (operations.any(
      (o) => o.kind == 'vehicle.save' && o.payload['id'] == id,
    )) {
      throw const ParkFailure('Phương tiện này còn thao tác chờ đồng bộ.');
    }
    await _queue('vehicle.save', {
      'id': id,
      'label': label.trim(),
      'plate': normalizePlate(plate),
      'kind': kind,
      'is_default': isDefault,
      'deleted': deleted,
      'expected_version': old?.version ?? 0,
    });
  }

  Future<void> markNotificationsRead() => _queue('notifications.read', {});
  bool isFavorite(String lotId) =>
      snapshot.rows('favorites').any((f) => f['lot_id'] == lotId);
  Future<void> toggleFavorite(String lotId) async {
    await backend.execute(const Uuid().v4(), 'favorite.set', {
      'lot_id': lotId,
      'enabled': !isFavorite(lotId),
    });
    await refresh();
  }

  Future<void> updateProfile(String name, String phone) async {
    await backend.execute(const Uuid().v4(), 'profile.update', {
      'name': name,
      'phone': phone,
    });
    await refresh();
  }

  Future<void> openTicket(String qr) async {
    final identity = TicketIdentity.parse(qr);
    await refresh();
    final found =
        bookings
            .where(
              (b) => b['id'] == identity.id && b['qr_token'] == identity.token,
            )
            .firstOrNull;
    if (found == null) {
      throw const ParkFailure(
        'Vé chưa có trong dữ liệu được cấp quyền. Kết nối mạng để tải vé.',
      );
    }
    selectedBookingId = identity.id;
    scannedQr = identity.encoded;
    _notify();
  }

  Future<void> staffAction(bool entering, String plate) async {
    final b = ticket;
    if (b == null || scannedQr == null) {
      throw const ParkFailure('Quét QR của vé trước.');
    }
    if (!canStaff) throw const ParkFailure('Tài khoản chưa được phân công.');
    if (normalizePlate(plate) != b['plate']) {
      throw const ParkFailure('Biển số không khớp vé.');
    }
    final pending =
        operations.where((o) => o.payload['booking_id'] == b['id']).toList();
    if (pending.isNotEmpty &&
        (pending.any((o) => o.state == 'conflict') ||
            entering ||
            pending.last.kind != 'staff.check_in')) {
      throw const ParkFailure(
        'Vé này đang có thao tác chờ đồng bộ hoặc xung đột.',
      );
    }
    if (b['status'] != (entering ? 'confirmed' : 'parked')) {
      throw const ParkFailure('Trạng thái vé không cho phép thao tác.');
    }
    await _queue(entering ? 'staff.check_in' : 'staff.check_out', {
      'booking_id': b['id'],
      'qr_token': TicketIdentity.parse(scannedQr!).token,
      'expected_version': b['version'],
      'plate': normalizePlate(plate),
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<String>?> recognizePlate() async {
    if (plateService == null) {
      throw const ParkFailure('Dịch vụ OCR chưa được khởi tạo.');
    }
    return plateService!.captureAndRecognize();
  }

  Future<void> _queue(String kind, Json payload) async {
    if (userId == null) throw const ParkFailure('Vui lòng đăng nhập.');
    await backend.enqueue(
      PendingOperation(
        id: const Uuid().v4(),
        userId: userId!,
        kind: kind,
        payload: payload,
      ),
    );
    operations = await backend.pending();
    _notify();
    await refresh();
  }

  Future<void> retryOperation(String id) async {
    await backend.retry(id);
    await refresh();
  }

  Future<void> discardOperation(String id) async {
    await backend.discard(id);
    operations = await backend.pending();
    _notify();
  }

  Future<void> signOut() async {
    await backend.signOut();
    snapshot = ParkingSnapshot.empty;
    operations = [];
    _notify();
  }

  Future<void> resetPassword(String email) => backend.resetPassword(email);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(backend.dispose());
    super.dispose();
  }
}

String money(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
String clock(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String displayDate(DateTime t) => '${t.day}/${t.month}/${t.year}';
String statusLabel(String s) =>
    const {
      'confirmed': 'Đã xác nhận',
      'parked': 'Đang sử dụng',
      'completed': 'Hoàn thành',
      'cancelled': 'Đã hủy',
    }[s] ??
    s;
