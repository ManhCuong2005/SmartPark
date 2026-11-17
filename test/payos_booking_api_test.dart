import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartpark/data/payos_topup_repository.dart';
import 'package:smartpark/domain/models.dart';

void main() {
  test(
    'booking QR uses the shared payment HTTP endpoint and keeps settlement errors safe',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      final received = <Map<String, dynamic>>[];
      final responses = [
        (
          200,
          <String, dynamic>{
            'orderCode': 123,
            'checkoutUrl': 'https://pay.payos.vn/web/test',
          },
        ),
        (
          200,
          <String, dynamic>{
            'status': 'PAID',
            'booking': {'id': 'ticket', 'prepaid': true},
          },
        ),
        (409, <String, dynamic>{'error': 'PRICE_CHANGED'}),
        (502, <String, dynamic>{'error': 'payment_service_error'}),
      ];
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        received.add({
          'method': request.method,
          'path': request.uri.path,
          'body': body,
        });
        final response = responses.removeAt(0);
        request.response.statusCode = response.$1;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response.$2));
        await request.response.close();
      });
      final repository = PayosTopupRepository(client);
      final request = <String, dynamic>{
        'operationId': '72000000-0000-0000-0000-000000000109',
        'kind': 'booking.pay',
        'payload': {
          'expected_amount': 15000,
          'lot_id': 'lot',
          'vehicle_id': 'vehicle',
        },
      };
      final order = await repository.createBookingPayment(request);
      expect(order['orderCode'], 123);
      expect(order['checkoutUrl'], 'https://pay.payos.vn/web/test');
      expect(received.single, {
        'method': 'POST',
        'path': '/functions/v1/payos-topup',
        'body': {'action': 'create_booking', ...request},
      });
      final settled = await repository.checkBookingPayment(123);
      expect(settled['status'], 'PAID');
      expect(settled['booking'], {'id': 'ticket', 'prepaid': true});
      expect(received[1]['body'], {'action': 'check', 'orderCode': 123});
      await expectLater(
        repository.createBookingPayment(request),
        throwsA(
          isA<ParkFailure>().having((e) => e.code, 'code', 'PRICE_CHANGED'),
        ),
      );
      await expectLater(
        repository.checkBookingPayment(123),
        throwsA(
          isA<ParkFailure>().having(
            (e) => e.retryable,
            'safe to check again',
            true,
          ),
        ),
      );
      expect(received[2]['body'], received.first['body']);
      expect(responses, isEmpty);
    },
  );
}
