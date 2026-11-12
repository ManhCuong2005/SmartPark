import 'models.dart';

abstract interface class ParkingRepository {
  String? get userId;
  String? get email;
  Stream<void> get authChanges;
  Future<bool> signUp(String email, String password, String name, String phone);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<ParkingSnapshot?> cachedSnapshot();
  Future<ParkingSnapshot> refresh();
  Future<ReservationAvailability> availability(
    String lotId,
    DateTime start,
    DateTime end, {
    String? vehicleId,
  });
  Future<Json> execute(String id, String kind, Json payload);
  Future<void> enqueue(PendingOperation operation);
  Future<List<PendingOperation>> pending();

  /// Terminal rejections of editable data, retained as notices, never replayed.
  Future<List<PendingOperation>> rejected();
  Future<void> discard(String id);
  Future<void> retry(String id);

  /// A restored connection can bypass transient retry delays, never conflicts.
  /// Returns true when at least one command was acknowledged by the server.
  Future<bool> synchronize({bool retryPendingNow = false});
  Stream<void> get changes;
  void subscribe();
  Future<void> dispose();
}
