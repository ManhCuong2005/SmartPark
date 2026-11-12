/// Mobile push is an optional delivery channel. The Supabase inbox remains
/// authoritative and usable without Firebase or notification permission.
abstract interface class DeviceNotifications {
  Stream<void> get messages;
  Stream<String> get openedBookings;
  String get status;
  Future<void> bindUser(String? userId);
  Future<void> enable();
  Future<void> unregister();
  Future<void> dispose();
}
