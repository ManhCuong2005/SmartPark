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
  Future<List<Json>> availability(String lotId, DateTime start, DateTime end);
  Future<Json> execute(String id, String kind, Json payload);
  Future<void> enqueue(PendingOperation operation);
  Future<List<PendingOperation>> pending();
  Future<void> discard(String id);
  Future<void> retry(String id);
  Future<void> synchronize();
  Stream<void> get changes;
  void subscribe();
  Future<void> dispose();
}
