import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark/domain/device_notifications.dart';
import 'package:smartpark/presentation/park_controller.dart';
import 'support/test_repository.dart';

class TestNotifications implements DeviceNotifications {
  final incoming = StreamController<void>.broadcast(sync: true);
  final tapped = StreamController<String>.broadcast(sync: true);
  String? actor;
  bool enabled = false, unregistered = false;
  @override
  Stream<void> get messages => incoming.stream;
  @override
  Stream<String> get openedBookings => tapped.stream;
  @override
  String get status =>
      enabled ? 'Đã bật thông báo trên điện thoại' : 'Chưa bật';
  @override
  Future<void> bindUser(String? userId) async {
    actor = userId;
  }

  @override
  Future<void> enable() async {
    enabled = true;
  }

  @override
  Future<void> unregister() async {
    unregistered = true;
    actor = null;
  }

  @override
  Future<void> dispose() async {
    await incoming.close();
    await tapped.close();
  }
}

class NotificationRepository extends TestRepository {
  int reads = 0;
  @override
  Future<ParkingSnapshot> refresh() {
    reads++;
    return super.refresh();
  }
}

void main() {
  test(
    'notification opt-in binds to current account and updates permission status',
    () async {
      final backend = NotificationRepository(),
          notifications = TestNotifications();
      final controller = ParkController(
        backend,
        monitorConnectivity: false,
        deviceNotifications: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(notifications.actor, backend.account);
      await controller.enableDeviceNotifications();
      expect(
        controller.deviceNotificationStatus,
        'Đã bật thông báo trên điện thoại',
      );
    },
  );
  test('foreground message refreshes authoritative Supabase inbox', () async {
    final backend = NotificationRepository(),
        notifications = TestNotifications();
    final controller = ParkController(
      backend,
      monitorConnectivity: false,
      deviceNotifications: notifications,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final before = backend.reads;
    notifications.incoming.add(null);
    await controller.refresh();
    expect(backend.reads, before + 1);
  });
  test(
    'tapped push selects an authorized ticket and ignores unknown IDs',
    () async {
      final backend = NotificationRepository(),
          notifications = TestNotifications();
      final controller = ParkController(
        backend,
        monitorConnectivity: false,
        deviceNotifications: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      notifications.tapped.add('unknown-ticket');
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.notificationToOpen, isNull);
      final id = backend.fixture().rows('bookings').single['id'] as String;
      notifications.tapped.add(id);
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.selectedBookingId, id);
      expect(controller.notificationToOpen, id);
    },
  );
  test('sign-out unregisters device before clearing account', () async {
    final backend = NotificationRepository(),
        notifications = TestNotifications();
    final controller = ParkController(
      backend,
      monitorConnectivity: false,
      deviceNotifications: notifications,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.signOut();
    expect(notifications.unregistered, true);
    expect(backend.loggedIn, false);
  });
}
