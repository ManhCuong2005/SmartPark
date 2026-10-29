// A local HTTP contract simulator exercises the real Supabase SDK. It is never
// imported by production and is not a substitute for PostgreSQL/RLS tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SupabaseSimulator {
  late HttpServer server;
  String get url => 'http://127.0.0.1:${server.port}';
  int? failureStatus;
  String failureCode = 'PGRST000';
  int mutations = 0, requests = 0;
  final receipts = <String, Map<String, dynamic>>{};
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      Object response;
      if (request.uri.path == '/auth/v1/token') {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        String encode(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        response = {
          'access_token':
              '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': '10000000-0000-0000-0000-000000000001', 'exp': now + 3600, 'role': 'authenticated'})}.test',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': now + 3600,
          'refresh_token': 'test-refresh',
          'user': {
            'id': '10000000-0000-0000-0000-000000000001',
            'aud': 'authenticated',
            'email': 'test@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        };
      } else if (request.uri.path == '/rest/v1/rpc/apply_operation') {
        requests++;
        if (failureStatus != null) {
          request.response.statusCode = failureStatus!;
          response = {
            'code': failureCode,
            'message': failureCode,
            'details': null,
            'hint': null,
          };
        } else {
          final payload = jsonDecode(body) as Map<String, dynamic>,
              id = payload['p_operation_id'] as String;
          if (!receipts.containsKey(id)) {
            mutations++;
            receipts[id] = {'ok': true, 'id': id};
          }
          response = receipts[id]!;
        }
      } else if (request.uri.path == '/rest/v1/rpc/park_snapshot') {
        response = {
          'profiles': [],
          'lots': [],
          'slots': [],
          'bookings': [],
          'vehicles': [],
          'memberships': [],
          'payments': [],
          'notifications': [],
          'server_time': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        request.response.statusCode = 501;
        response = {
          'message': 'Contract endpoint not implemented: ${request.uri.path}',
        };
      }
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
  }

  Future<void> close() => server.close(force: true);
}
