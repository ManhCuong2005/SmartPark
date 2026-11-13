import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';
import '../domain/parking_rules.dart';

class PayosTopupRepository {
  const PayosTopupRepository(this.client);

  final SupabaseClient client;

  Future<int> balance() async =>
      (await client.rpc('wallet_topup_balance') as num).toInt();

  Future<List<Map<String, dynamic>>> history() => client
      .from('wallet_topups')
      .select('order_code,amount,created_at,expires_at,paid_at,checkout_url')
      .order('order_code', ascending: false)
      .limit(20);

  Future<Uri> create(int amount) async {
    final result = await client.functions.invoke(
      'payos-topup',
      body: {'action': 'create', 'amount': amount},
    );
    return Uri.parse(result.data['checkoutUrl'] as String);
  }

  Future<String> check(int orderCode) async {
    final result = await client.functions.invoke(
      'payos-topup',
      body: {'action': 'check', 'orderCode': orderCode},
    );
    return result.data['status'] as String;
  }

  Future<Json> createBookingPayment(Json request) =>
      _bookingPayment({'action': 'create_booking', ...request});

  Future<Json> checkBookingPayment(int orderCode) =>
      _bookingPayment({'action': 'check', 'orderCode': orderCode});

  Future<Json> _bookingPayment(Json body) async {
    try {
      final response = await client.functions.invoke('payos-topup', body: body);
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] as String? : null;
      if (code != null && code != 'payment_service_error') {
        throw ParkFailure(backendMessage(code), code: code);
      }
      throw const ParkFailure(
        'Chưa kết nối được payOS. Nếu đã chuyển tiền, hãy kiểm tra giao dịch; đừng chuyển lại.',
        retryable: true,
      );
    }
  }
}
