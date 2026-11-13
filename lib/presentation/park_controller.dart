import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../domain/plate_recognition_service.dart';
import '../domain/device_notifications.dart';
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

class ParkController extends ChangeNotifier with WidgetsBindingObserver {
  ParkController(
    this.backend, {
    this.monitorConnectivity = true,
    this.plateService,
    this.connectionChanges,
    this.deviceNotifications,
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
  final Stream<bool>? connectionChanges;
  final DeviceNotifications? deviceNotifications;
  String? notificationToOpen;
  String get deviceNotificationStatus =>
      deviceNotifications?.status ?? 'Thông báo trong app đang hoạt động';
  ParkingSnapshot snapshot = ParkingSnapshot.empty;
  List<PendingOperation> operations = [];
  List<PendingOperation> rejections = [];
  List<Json> availabilityRows = [];
  Json? availabilityVehicleConflict;
  String? availabilityError;
  bool availabilityLoading = false;
  int _availabilityRequest = 0;
  String? _availabilityLot;
  String? _availabilityVehicle;
  DateTime? _availabilityStart, _availabilityEnd;
  String? selectedLotId, selectedBookingId;
  String? error;
  bool loading = false, online = false, _disposed = false;
  String? _lastUserId;
  late DateTime date, endDate;
  late TimeOfDay start, end;
  Timer? _timer, _debounce;
  Future<void>? _refreshing;
  bool _retryPendingNow = false, _foreground = true, _networkAvailable = true;
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
        final counts = snapshot
            .rows('capacities')
            .where((c) => c['lot_id'] == l['id']);
        final remaining = counts.fold<int>(
          0,
          (sum, c) => sum + (c['remaining'] as int? ?? 0),
        );
        return ParkingLot(
          l['id'] as String,
          l['name'] as String,
          l['area'] as String,
          remaining,
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
    availabilityRows = [];
    _availabilityLot = null;
    unawaited(loadAvailability());
  }

  List<Json> get capacities =>
      snapshot.rows('capacities').where((c) => c['lot_id'] == lot.id).toList();
  List<ParkingLot> get staffLots =>
      lots
          .where(
            (l) =>
                snapshot
                    .rows('lots')
                    .any((r) => r['id'] == l.id && r['owner_id'] == userId) ||
                snapshot
                    .rows('memberships')
                    .any(
                      (m) =>
                          m['lot_id'] == l.id &&
                          m['user_id'] == userId &&
                          m['active'] == true,
                    ),
          )
          .toList();
  bool get availabilityReady =>
      _availabilityLot == lot.id &&
      _availabilityStart == startsAt &&
      _availabilityEnd == endsAt &&
      _availabilityVehicle == vehicle.id &&
      availabilityError == null;
  Json? get vehicleConflict =>
      availabilityReady ? availabilityVehicleConflict : null;
  String get vehicleConflictMessage {
    final conflict = vehicleConflict;
    if (conflict == null) return '';
    return 'Xe ${vehicle.plate} đã có vé trùng thời gian hoặc vẫn đang gửi. Hãy kiểm tra lịch sử vé, đổi xe hoặc đổi giờ.';
  }

  List<Json> get bookingCapacities => availabilityReady ? availabilityRows : [];
  int get remainingCapacity =>
      bookingCapacities
              .where((c) => c['kind'] == vehicle.kind)
              .firstOrNull?['remaining']
          as int? ??
      0;
  bool get canContinueBooking =>
      bookingVehicleKind != null &&
      vehicle.id.isNotEmpty &&
      availabilityReady &&
      !availabilityLoading &&
      vehicleConflict == null &&
      remainingCapacity > 0;

  void setReservationPeriod(DateTime from, DateTime until) {
    date = DateTime(from.year, from.month, from.day);
    start = TimeOfDay.fromDateTime(from);
    endDate = DateTime(until.year, until.month, until.day);
    end = TimeOfDay.fromDateTime(until);
    availabilityRows = [];
    _availabilityLot = null;
    _availabilityRequest++;
    availabilityLoading = false;
    availabilityError = null;
    _notify();
  }

  void setDuration(int hours) =>
      setReservationPeriod(startsAt, startsAt.add(Duration(hours: hours)));

  void selectBookingVehicleKind(String kind) {
    if (!bookingVehicleKinds.contains(kind)) {
      throw const ParkFailure('Bạn chưa thêm phương tiện thuộc loại này.');
    }
    _bookingVehicleKind = kind;
    final eligible = bookingVehicles;
    final preferred =
        eligible.where((v) => v.id == selectedVehicleId).firstOrNull ??
        eligible.where((v) => v.isDefault).firstOrNull ??
        eligible.first;
    if (selectedVehicleId == preferred.id) {
      _notify();
      return;
    }
    selectVehicle(preferred.id);
  }

  void selectVehicle(String? id) {
    if (id != null && !bookingVehicles.any((v) => v.id == id)) {
      throw const ParkFailure('Chọn xe thuộc loại phương tiện đang đặt.');
    }
    if (selectedVehicleId == id) return;
    selectedVehicleId = id;
    _availabilityLot = null;
    availabilityVehicleConflict = null;
    _notify();
    unawaited(loadAvailability());
  }

  Future<void> prepareBooking() async {
    if (bookingVehicleKind == null) {
      throw const ParkFailure(
        'Chọn loại phương tiện trước khi chọn thời gian.',
      );
    }
    validateReservation(startsAt, endsAt, DateTime.now());
    if (vehicle.id.isEmpty) {
      throw const ParkFailure('Thêm phương tiện trước khi chọn chỗ đỗ.');
    }
    final lotId = lot.id, vehicleId = vehicle.id;
    final actor = userId;
    final from = startsAt, until = endsAt;
    await loadAvailability();
    if (userId != actor ||
        lot.id != lotId ||
        vehicle.id != vehicleId ||
        startsAt != from ||
        endsAt != until) {
      throw const ParkFailure(
        'Thông tin đặt chỗ vừa thay đổi. Vui lòng kiểm tra lại.',
      );
    }
    if (!availabilityReady) {
      throw ParkFailure(
        availabilityError ?? 'Chưa kiểm tra được lịch đặt. Vui lòng thử lại.',
      );
    }
    if (vehicleConflict != null) {
      throw ParkFailure(
        backendMessage('VEHICLE_TIME_CONFLICT'),
        code: 'VEHICLE_TIME_CONFLICT',
      );
    }
    if (!canContinueBooking) {
      throw const ParkFailure(
        'Bãi đã hết chỗ cho loại xe này trong khoảng giờ đã chọn. Hãy đổi thời gian.',
        code: 'CAPACITY_FULL',
      );
    }
  }

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
  String? _bookingVehicleKind;
  List<String> get bookingVehicleKinds =>
      [
        'car',
        'motorcycle',
      ].where((kind) => vehicles.any((v) => v.kind == kind)).toList();
  String? get bookingVehicleKind {
    final kinds = bookingVehicleKinds;
    if (kinds.length == 1) return kinds.single;
    return kinds.contains(_bookingVehicleKind) ? _bookingVehicleKind : null;
  }

  List<Vehicle> get bookingVehicles =>
      vehicles.where((v) => v.kind == bookingVehicleKind).toList();
  Vehicle get vehicle {
    final eligible = bookingVehicleKind == null ? vehicles : bookingVehicles;
    return eligible.where((v) => v.id == selectedVehicleId).firstOrNull ??
        eligible.where((v) => v.isDefault).firstOrNull ??
        eligible.firstOrNull ??
        const Vehicle('', 'Chưa có phương tiện', '');
  }

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
        final period = admissionPeriod(
          DateTime.parse(projected['starts_at'] as String),
          DateTime.parse(projected['ends_at'] as String),
          DateTime.parse(op.payload['occurred_at'] as String),
        );
        projected = {
          ...projected,
          'status': 'parked',
          'checked_in_at': op.payload['occurred_at'],
          'starts_at': period.start.toIso8601String(),
          'ends_at': period.end.toIso8601String(),
          'version': (projected['version'] as int) + 1,
          'local_pending': true,
        };
      } else if (op.kind == 'staff.check_out' &&
          projected['status'] == 'parked') {
        projected = {
          ...projected,
          'status': 'completed',
          'checked_out_at': op.payload['occurred_at'],
          'amount':
              projected['prepaid'] == true
                  ? projected['amount']
                  : checkoutAmount(
                    projected,
                    DateTime.parse(op.payload['occurred_at'] as String),
                  ),
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
    if (deviceNotifications != null) {
      _subscriptions.add(
        deviceNotifications!.messages.listen((_) => unawaited(refresh())),
      );
      _subscriptions.add(
        deviceNotifications!.openedBookings.listen((id) async {
          await refresh();
          if (!_disposed && bookings.any((b) => b['id'] == id)) {
            selectedBookingId = id;
            notificationToOpen = id;
            _notify();
          }
        }),
      );
      unawaited(_bindNotifications());
    }
    try {
      snapshot = await backend.cachedSnapshot() ?? ParkingSnapshot.empty;
      operations = await backend.pending();
      rejections = await backend.rejected();
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
          availabilityVehicleConflict = null;
          _bookingPayload = null;
          _bookingOperation = null;
          _extensionOperation = null;
          _extensionPayload = null;
          _availabilityLot = null;
          _availabilityRequest++;
          availabilityLoading = false;
          availabilityError = null;
          operations = [];
          rejections = [];
          selectedLotId = null;
          selectedVehicleId = null;
          _bookingVehicleKind = null;
          selectedBookingId = null;
          selectedBookingId = null;
          notificationToOpen = null;
          _lastUserId = userId;
          _notify();
        }
        backend.subscribe();
        unawaited(refresh(retryPendingNow: true));
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
    if (monitorConnectivity || connectionChanges != null) {
      _subscriptions.add(
        (connectionChanges ??
                Connectivity().onConnectivityChanged.map(
                  (results) => results.any(
                    (result) => result != ConnectivityResult.none,
                  ),
                ))
            .distinct()
            .listen((available) {
              _networkAvailable = available;
              if (!available) {
                online = false;
                _notify();
              } else if (_foreground) {
                unawaited(refresh(retryPendingNow: true));
              }
            }),
      );
    }
    if (monitorConnectivity) {
      WidgetsBinding.instance.addObserver(this);
      _startPolling();
    }
    backend.subscribe();
    await refresh(retryPendingNow: true);
  }

  void _startPolling() {
    if (!monitorConnectivity || _disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_foreground && _networkAvailable) unawaited(refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startPolling();
      unawaited(_resumeSync());
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _resumeSync() async {
    // Android may not deliver connectivity changes while the app is paused.
    // Recheck the transport on resume instead of retaining an old offline hint.
    if (monitorConnectivity && connectionChanges == null) {
      try {
        final results = await Connectivity().checkConnectivity();
        _networkAvailable = results.any((r) => r != ConnectivityResult.none);
      } catch (_) {
        _networkAvailable = true; // The server request remains the final check.
      }
    }
    if (_disposed) return;
    if (_networkAvailable) {
      await refresh(retryPendingNow: true);
    } else {
      online = false;
      _notify();
    }
  }

  Future<void> refresh({bool retryPendingNow = false}) {
    if (_disposed) return Future.value();
    _retryPendingNow = _retryPendingNow || retryPendingNow;
    return _refreshing ??= _refreshRequested().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _refreshRequested() async {
    do {
      final retry = _retryPendingNow;
      _retryPendingNow = false;
      await _refresh(retryPendingNow: retry);
    } while (_retryPendingNow && !_disposed);
  }

  Future<void> _refresh({required bool retryPendingNow}) async {
    if (!signedIn || _disposed) return;
    final id = userId;
    try {
      // A connection hint (Wi-Fi/mobile) is not proof the server is reachable.
      // A successful snapshot also detects Internet restored on the same Wi-Fi.
      var next = await backend.refresh();
      if (userId != id || _disposed) return;
      final acknowledged = await backend.synchronize(
        retryPendingNow: retryPendingNow || !online,
      );
      if (userId != id || _disposed) return;
      if (acknowledged) next = await backend.refresh();
      if (userId != id || _disposed) return;
      snapshot = next;
      online = _networkAvailable;
      error = null;
      unawaited(_bindNotifications());
      operations = await backend.pending();
      rejections = await backend.rejected();
      if (lot.id.isNotEmpty) await loadAvailability();
    } catch (e) {
      if (userId != id || _disposed) return;
      online = false;
      error = e.toString();
      operations = await backend.pending();
      rejections = await backend.rejected();
    }
    _notify();
  }

  Future<void> loadAvailability() async {
    final request = ++_availabilityRequest;
    final id = lot.id;
    if (id.isEmpty || !endsAt.isAfter(startsAt)) {
      availabilityLoading = false;
      _availabilityLot = null;
      _notify();
      return;
    }
    final startTime = startsAt, endTime = endsAt;
    final vehicleId = vehicle.id;
    final actor = userId;
    availabilityLoading = true;
    availabilityError = null;
    _notify();
    try {
      final next = await backend.availability(
        id,
        startTime,
        endTime,
        vehicleId: vehicleId.isEmpty ? null : vehicleId,
      );
      if (!_disposed &&
          request == _availabilityRequest &&
          userId == actor &&
          vehicle.id == vehicleId &&
          lot.id == id &&
          startsAt == startTime &&
          endsAt == endTime) {
        availabilityRows = next.capacities;
        availabilityVehicleConflict = next.vehicleConflict;
        _availabilityVehicle = vehicleId;
        _availabilityLot = id;
        _availabilityStart = startTime;
        _availabilityEnd = endTime;
        // Persist availability with the scoped snapshot for offline reading.
        snapshot = ParkingSnapshot({
          ...snapshot.data,
          'availability': next.capacities,
          'availability_lot': id,
          'availability_start': startTime.toIso8601String(),
          'availability_end': endTime.toIso8601String(),
        });
      }
    } catch (e) {
      if (!_disposed && request == _availabilityRequest && userId == actor) {
        availabilityError = e.toString();
        _availabilityLot = null;
      }
    } finally {
      if (request == _availabilityRequest) availabilityLoading = false;
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
  Future<Json> paymentRequest({Json? booking, DateTime? newEnd}) async {
    final actor = userId;
    if (actor == null) throw const ParkFailure('Vui lòng đăng nhập.');
    if (booking != null) {
      if (booking['customer_id'] != actor ||
          booking['status'] != 'parked' ||
          booking['prepaid'] != true ||
          booking['local_pending'] == true ||
          newEnd == null) {
        throw const ParkFailure(
          'Chỉ thanh toán gia hạn vé trả trước đang gửi của chính bạn.',
        );
      }
      final end = newEnd.toUtc().toIso8601String();
      if (_extensionPayload?['booking_id'] != booking['id'] ||
          _extensionPayload?['ends_at'] != end) {
        _extensionOperation = const Uuid().v4();
        _extensionPayload = {
          'booking_id': booking['id'],
          'ends_at': end,
          'expected_version': booking['version'],
          'expected_amount': extensionFee(booking, newEnd),
        };
      }
      return {
        'operationId': _extensionOperation,
        'kind': 'booking.extend.pay',
        'payload': _extensionPayload,
      };
    }
    final request = <String, dynamic>{
      'vehicle_id': vehicle.id,
      'lot_id': lot.id,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'expected_amount': total,
    };
    final retrying =
        _bookingPayload != null &&
        request.entries.every((e) => _bookingPayload![e.key] == e.value);
    // Replay the same payment after a lost acknowledgement before preflight.
    if (!retrying) {
      await prepareBooking();
      if (userId != actor)
        throw const ParkFailure(
          'Tài khoản đã thay đổi. Vui lòng đăng nhập lại.',
        );
      _bookingOperation = const Uuid().v4();
      _bookingPayload = {...request, 'id': const Uuid().v4()};
    }
    return {
      'operationId': _bookingOperation,
      'kind': 'booking.pay',
      'payload': _bookingPayload,
    };
  }

  Future<void> book() => payBooking();

  Future<void> payBooking({Json? booking, DateTime? newEnd}) async {
    final actor = userId;
    final request = await paymentRequest(booking: booking, newEnd: newEnd);
    try {
      final result = await backend.execute(
        request['operationId'] as String,
        request['kind'] as String,
        request['payload'] as Json,
      );
      await acceptPaidBooking(result, actor!, extension: booking != null);
    } on ParkFailure catch (e) {
      // Insufficient funds may be topped up; retain the same operation ID.
      if (!e.retryable && e.code != 'INSUFFICIENT_BALANCE')
        clearPayment(extension: booking != null);
      if (booking == null &&
          [
            'CAPACITY_FULL',
            'VEHICLE_TIME_CONFLICT',
            '23P01',
          ].contains(e.code)) {
        await loadAvailability();
      }
      if (e.code == 'PRICE_CHANGED') await refresh();
      rethrow;
    }
  }

  void clearPayment({bool extension = false}) {
    if (extension) {
      _extensionOperation = null;
      _extensionPayload = null;
    } else {
      _bookingOperation = null;
      _bookingPayload = null;
    }
  }

  Future<void> acceptPaidBooking(
    Json result,
    String actor, {
    bool extension = false,
  }) async {
    if (userId != actor) {
      throw const ParkFailure(
        'Tài khoản đã thay đổi. Hãy kiểm tra vé trong tài khoản ban đầu.',
      );
    }
    selectedBookingId = result['id'] as String;
    snapshot = ParkingSnapshot({
      ...snapshot.data,
      'bookings': [
        result,
        ...bookings.where((b) => b['id'] != selectedBookingId),
      ],
    });
    clearPayment(extension: extension);
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

  String? _extensionOperation;
  Json? _extensionPayload;
  Future<void> extendBooking(Json booking, DateTime newEnd) async {
    if (booking['prepaid'] == true) {
      return payBooking(booking: booking, newEnd: newEnd);
    }
    final actor = userId;
    if (actor == null ||
        booking['customer_id'] != actor ||
        booking['status'] != 'parked' ||
        booking['local_pending'] == true) {
      throw const ParkFailure(
        'Chỉ gia hạn vé đang gửi đã được máy chủ xác nhận của chính bạn.',
      );
    }
    final end = newEnd.toUtc().toIso8601String();
    if (_extensionPayload?['booking_id'] != booking['id'] ||
        _extensionPayload?['ends_at'] != end) {
      _extensionOperation = const Uuid().v4();
      _extensionPayload = {
        'booking_id': booking['id'],
        'ends_at': end,
        'expected_version': booking['version'],
      };
    }
    try {
      final result = await backend.execute(
        _extensionOperation!,
        'booking.extend',
        _extensionPayload!,
      );
      if (_disposed) return;
      if (userId != actor) {
        throw const ParkFailure(
          'Tài khoản đã thay đổi. Vui lòng kiểm tra lại vé sau khi đăng nhập.',
        );
      }
      snapshot = ParkingSnapshot({
        ...snapshot.data,
        'bookings': [result, ...bookings.where((b) => b['id'] != result['id'])],
      });
      _extensionOperation = null;
      _extensionPayload = null;
      _notify();
      await refresh();
    } on ParkFailure catch (failure) {
      if (!failure.retryable) {
        _extensionOperation = null;
        _extensionPayload = null;
        await refresh();
      }
      rethrow;
    }
  }

  final Set<String> _vehicleSaves = {};
  Future<void> saveVehicle({
    Vehicle? old,
    required String label,
    required String plate,
    String kind = 'car',
    bool isDefault = false,
    bool deleted = false,
  }) async {
    final actor = userId;
    if (actor == null) throw const ParkFailure('Vui lòng đăng nhập.');
    final key = old?.id ?? 'new-vehicle';
    if (!_vehicleSaves.add(key)) {
      throw const ParkFailure(
        'Đang lưu phương tiện này. Vui lòng chờ kết quả.',
      );
    }
    try {
      // Expiry/check-out can have happened on the server since the last poll.
      // Refresh before applying a cached business restriction when reachable.
      // Offline still uses the conservative cached state and never unlocks a
      // vehicle solely because the phone clock says its booking has ended.
      if (old != null && online && _networkAvailable && _foreground) {
        await refresh();
      }
      if (userId != actor) {
        throw const ParkFailure(
          'Tài khoản đã thay đổi. Vui lòng mở lại thao tác sau khi đăng nhập.',
        );
      }
      await _saveVehicle(
        old: old,
        label: label,
        plate: plate,
        kind: kind,
        isDefault: isDefault,
        deleted: deleted,
      );
    } finally {
      _vehicleSaves.remove(key);
    }
  }

  Future<void> _saveVehicle({
    Vehicle? old,
    required String label,
    required String plate,
    String kind = 'car',
    bool isDefault = false,
    bool deleted = false,
  }) async {
    if (label.trim().isEmpty || label.trim().length > 100) {
      throw const ParkFailure('Tên phương tiện cần có từ 1 đến 100 ký tự.');
    }
    if (!['car', 'motorcycle'].contains(kind)) {
      throw const ParkFailure('Loại phương tiện không hợp lệ.');
    }
    if (!isValidPlate(plate)) {
      throw const ParkFailure(
        'Biển số chưa đúng định dạng Việt Nam. Vui lòng kiểm tra.',
      );
    }
    final id = old?.id ?? const Uuid().v4();
    final normalized = normalizePlate(plate);
    // Reject known business errors even offline. Only transport failures belong
    // in the retry queue; the server repeats these checks transactionally.
    if (!deleted && vehicles.any((v) => v.id != id && v.plate == normalized)) {
      throw const ParkFailure('Biển số này đã có trong phương tiện của bạn.');
    }
    if (old != null &&
        (deleted || normalized != old.plate || kind != old.kind)) {
      final active = bookings.where(
        (b) =>
            b['vehicle_id'] == id &&
            (b['status'] == 'confirmed' || b['status'] == 'parked'),
      );
      if (active.isNotEmpty) {
        throw ParkFailure(
          active.any((b) => b['status'] == 'parked')
              ? 'Xe đang được gửi trong bãi. Bạn chỉ có thể đổi biển số, loại xe hoặc xóa xe sau khi lấy xe ra.'
              : 'Xe đang có vé đặt chỗ. Hãy hủy vé hoặc chờ vé kết thúc trước khi đổi biển số, loại xe hoặc xóa xe.',
        );
      }
    }
    if (operations.any(
      (o) => o.kind == 'vehicle.save' && o.payload['id'] == id,
    )) {
      throw const ParkFailure('Phương tiện này còn thao tác chờ đồng bộ.');
    }
    await _queue('vehicle.save', {
      'id': id,
      'label': label.trim(),
      'plate': normalized,
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

  Future<void> openPlate(String plate) async {
    final actor = userId, lotId = lot.id;
    final normalized = normalizePlate(plate);
    if (!isValidPlate(normalized)) {
      throw const ParkFailure('Biển số không hợp lệ.');
    }
    final found = await backend.execute(const Uuid().v4(), 'staff.lookup', {
      'lot_id': lotId,
      'plate': normalized,
    });
    if (userId != actor || lot.id != lotId) {
      throw const ParkFailure(
        'Tài khoản hoặc bãi đã thay đổi. Hãy xác nhận lại biển số.',
      );
    }
    snapshot = ParkingSnapshot({
      ...snapshot.data,
      'bookings': [found, ...bookings.where((b) => b['id'] != found['id'])],
    });
    selectedBookingId = found['id'] as String;
    _notify();
  }

  Future<void> staffAction(
    bool entering,
    String plate, {
    DateTime? checkoutAt,
  }) async {
    final b = ticket;
    if (b == null) throw const ParkFailure('Xác nhận biển số và tìm vé trước.');
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
    if (b['status'] == 'expired') {
      throw const ParkFailure(
        'Vé đã hết hạn và chưa được sử dụng. Không thể check-in bằng vé này.',
      );
    }
    if (b['status'] != (entering ? 'confirmed' : 'parked')) {
      throw const ParkFailure('Trạng thái vé không cho phép thao tác.');
    }
    final observed =
        (entering ? DateTime.now() : checkoutAt ?? DateTime.now()).toUtc();
    if (entering &&
        (observed.isBefore(
              DateTime.parse(
                b['starts_at'] as String,
              ).subtract(const Duration(minutes: 15)),
            ) ||
            !observed.isBefore(DateTime.parse(b['ends_at'] as String)))) {
      throw const ParkFailure(
        'Chỉ nhận xe từ 15 phút trước giờ vào đến trước giờ ra dự kiến. Vé quá hạn không được check-in.',
      );
    }
    await _queue(entering ? 'staff.check_in' : 'staff.check_out', {
      'booking_id': b['id'],
      'expected_version': b['version'],
      'plate': normalizePlate(plate),
      'occurred_at': observed.toIso8601String(),
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
    final actor = userId!;
    final command = PendingOperation(
      id: const Uuid().v4(),
      userId: actor,
      kind: kind,
      payload: payload,
    );
    // Persist before sending so a crash or lost acknowledgement can be retried
    // with exactly the same idempotency key. Do not expose a rejected online
    // command as a queued success.
    final hasDependencies =
        kind == 'staff.check_out' &&
        operations.any(
          (op) => op.payload['booking_id'] == payload['booking_id'],
        );
    await backend.enqueue(command);
    if (userId != actor) {
      // The command remains scoped to the original account's durable outbox.
      // Never submit it using the newly signed-in account's credentials.
      throw const ParkFailure(
        'Tài khoản đã thay đổi. Thao tác chỉ được đồng bộ trong tài khoản ban đầu.',
      );
    }
    if (_networkAvailable && _foreground && !hasDependencies) {
      try {
        final result = await backend.execute(command.id, kind, payload);
        if (userId != actor) return;
        // Retain the acknowledged amount even if the following snapshot fetch
        // fails. A successful cash collection must not revert to cached 0đ.
        if (kind.startsWith('staff.') &&
            result['id'] == payload['booking_id'] &&
            result['status'] != null) {
          snapshot = ParkingSnapshot({
            ...snapshot.data,
            'bookings': [
              result,
              ...bookings.where((b) => b['id'] != result['id']),
            ],
          });
        }
        await backend.discard(command.id);
        operations = await backend.pending();
        await refresh();
        return;
      } on ParkFailure catch (failure) {
        if (userId != actor) rethrow;
        if (!failure.retryable) {
          await backend.discard(command.id);
          operations = await backend.pending();
          _notify();
          // Pull the current version after a business rejection, keeping the
          // original explanation visible to the caller.
          await refresh();
          rethrow;
        }
        online = false;
      }
    }
    operations = await backend.pending();
    _notify();
  }

  Future<void> retryOperation(String id) async {
    await backend.retry(id);
    await refresh();
  }

  Future<void> discardOperation(String id) async {
    await backend.discard(id);
    operations = await backend.pending();
    rejections = await backend.rejected();
    _notify();
  }

  Future<void> signOut() async {
    if ((await backend.pending()).isNotEmpty) {
      throw const ParkFailure(
        'Còn thao tác chưa đồng bộ. Hãy xử lý hàng đợi trước khi đăng xuất.',
      );
    }
    await deviceNotifications?.unregister();
    await backend.signOut();
    selectedVehicleId = null;
    _bookingVehicleKind = null;
    _extensionOperation = null;
    _extensionPayload = null;
    snapshot = ParkingSnapshot.empty;
    availabilityRows = [];
    availabilityVehicleConflict = null;
    _bookingPayload = null;
    _bookingOperation = null;
    _availabilityLot = null;
    _availabilityRequest++;
    availabilityLoading = false;
    availabilityError = null;
    operations = [];
    rejections = [];
    _notify();
  }

  Future<void> resetPassword(String email) => backend.resetPassword(email);

  Future<void> _bindNotifications() async {
    await deviceNotifications?.bindUser(userId);
    _notify();
  }

  Future<void> enableDeviceNotifications() async {
    await deviceNotifications?.enable();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (monitorConnectivity) WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _debounce?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(backend.dispose());
    unawaited(deviceNotifications?.dispose());
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
      'expired': 'Hết hạn · Chưa sử dụng',
    }[s] ??
    s;
