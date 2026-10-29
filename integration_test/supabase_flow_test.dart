// Opt-in test against a DEVELOPMENT Cloud project. No writes occur by default.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartpark/app/providers.dart';
import 'package:smartpark/app/smartpark_app.dart';
import 'package:smartpark/core/config/supabase_config.dart';
import 'package:smartpark/data/local/parking_database.dart';
import 'package:smartpark/data/supabase_parking_repository.dart';
import 'package:smartpark/presentation/park_controller.dart';

const allow = bool.fromEnvironment('SMARTPARK_TEST_ALLOW_WRITES');
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Cloud: customer reservation → real QR → staff check-in/out → owner receipts',
    (tester) async {
      final dir = await Directory.systemTemp.createTemp('smartpark-e2e-');
      final customerClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
      final staffClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
      final owner = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
      final customer = ParkController(
        SupabaseParkingRepository(
          customerClient,
          ParkingDatabase(NativeDatabase(File('${dir.path}/customer.sqlite'))),
        ),
        monitorConnectivity: false,
      );
      final staff = ParkController(
        SupabaseParkingRepository(
          staffClient,
          ParkingDatabase(NativeDatabase(File('${dir.path}/staff.sqlite'))),
        ),
        monitorConnectivity: false,
      );
      try {
        expect(
          await customer.authenticate(
            const String.fromEnvironment('TEST_CUSTOMER_EMAIL'),
            const String.fromEnvironment('TEST_CUSTOMER_PASSWORD'),
          ),
          isTrue,
        );
        await customer.initialize();
        customer.lot = customer.lots.firstWhere(
          (l) => l.id == const String.fromEnvironment('TEST_LOT_ID'),
        );
        await customer.loadAvailability();
        customer.slot = const String.fromEnvironment(
          'TEST_SLOT_CODE',
          defaultValue: 'A001',
        );
        expect(
          customer.vehicle.id,
          isNotEmpty,
          reason: 'Create a test customer vehicle first',
        );
        await customer.book();
        final ticket = customer.ticket!,
            qr =
                TicketIdentity(
                  ticket['id'] as String,
                  ticket['qr_token'] as String,
                ).encoded;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [parkControllerProvider.overrideWith((ref) => customer)],
            child: const SmartParkApp(initialRoute: '/tickets/qr'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          await staff.authenticate(
            const String.fromEnvironment('TEST_STAFF_EMAIL'),
            const String.fromEnvironment('TEST_STAFF_PASSWORD'),
            staff: true,
          ),
          isTrue,
        );
        await staff.initialize();
        await staff.openTicket(qr);
        await staff.staffAction(true, ticket['plate'] as String);
        expect(staff.ticket!['status'], 'parked');
        expect(staff.operations, isEmpty);
        await staff.staffAction(false, ticket['plate'] as String);
        expect(staff.ticket!['status'], 'completed');
        expect(staff.operations, isEmpty);
        await owner.auth.signInWithPassword(
          email: const String.fromEnvironment('TEST_OWNER_EMAIL'),
          password: const String.fromEnvironment('TEST_OWNER_PASSWORD'),
        );
        final snapshot = await owner.rpc('park_snapshot') as Map;
        expect(
          (snapshot['payments'] as List).where(
            (p) => p['booking_id'] == ticket['id'],
          ),
          hasLength(1),
        );
        // Detach the provider-owned customer controller before closing its resources.
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        staff.dispose();
        await customerClient.dispose();
        await staffClient.dispose();
        await owner.dispose();
      }
    },
    skip: !allow,
  );
}
