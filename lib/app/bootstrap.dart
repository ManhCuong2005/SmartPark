import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import 'smartpark_app.dart';

Future<void> bootstrap({bool staff = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    runApp(ProviderScope(child: SmartParkApp(staff: staff)));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không khởi tạo được SmartPark. Kiểm tra cấu hình và khởi động lại.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
