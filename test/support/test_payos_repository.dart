import 'package:smartpark/data/payos_topup_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestPayosRepository extends PayosTopupRepository {
  TestPayosRepository()
    : super(SupabaseClient('https://payos.test.invalid', 'test-public-key'));

  @override
  Future<int> balance() async => 500000;
}
