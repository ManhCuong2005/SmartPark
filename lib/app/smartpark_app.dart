import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/sync_queue_screen.dart';
import 'providers.dart';
import '../shared/widgets/park_widgets.dart';
import '../presentation/features/auth/auth_screens.dart';
import '../presentation/features/parking/parking_screens.dart';
import '../presentation/features/booking/booking_screens.dart';
import '../presentation/features/tickets/ticket_screens.dart';
import '../presentation/features/account/account_screens.dart';
import '../presentation/features/staff/staff_screens.dart';

class SmartParkApp extends ConsumerWidget {
  const SmartParkApp({super.key, this.staff = false, this.initialRoute});
  final bool staff;
  final String? initialRoute;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(parkControllerProvider);
    Widget guard(Widget view, {bool staffOnly = false}) {
      if (!repository.signedIn) {
        return AuthScreen(repository: repository, staff: staffOnly || staff);
      }
      if (staffOnly && !repository.canStaff) {
        return ParkPage(
          child: Column(
            children: [
              const PageHeading('Chưa được phân công'),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chủ bãi cần cấp quyền cho tài khoản này.'),
              ),
              TextButton(
                onPressed: () => runAction(context, repository.signOut),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        );
      }
      return view;
    }

    return MaterialApp(
      title: staff ? 'SmartPark Staff' : 'SmartPark',
      debugShowCheckedModeBanner: false,
      theme: parkTheme(),
      darkTheme: parkTheme(dark: true),
      themeMode: ref.watch(themeModeProvider),
      initialRoute:
          initialRoute ??
          (repository.signedIn
              ? (staff ? '/staff/home' : '/home')
              : (staff ? '/staff/login' : '/')),
      builder:
          (context, child) => Column(
            children: [
              if (repository.signedIn)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Icon(
                          repository.online
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            repository.error ?? repository.freshness,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.sync,
                            semanticLabel: 'Đồng bộ',
                          ),
                          onPressed: repository.refresh,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
      routes: <String, WidgetBuilder>{
        '/': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => AuthScreen(repository: repository),
        '/register': (_) => AuthScreen(repository: repository, register: true),
        '/staff/login': (_) => AuthScreen(repository: repository, staff: true),
        '/home': (_) => guard(HomeScreen(repository: repository)),
        '/parking/map': (_) => guard(ParkingMapScreen(repository: repository)),
        '/parking/list':
            (_) => guard(ParkingListScreen(repository: repository)),
        '/parking/detail':
            (_) => guard(ParkingDetailScreen(repository: repository)),
        '/booking/slots':
            (_) => guard(SlotSelectionScreen(repository: repository)),
        '/booking/time':
            (_) => guard(TimeSelectionScreen(repository: repository)),
        '/booking/confirm':
            (_) => guard(BookingConfirmationScreen(repository: repository)),
        '/booking/payment': (_) => guard(PaymentScreen(repository: repository)),
        '/tickets/qr': (_) => guard(TicketScreen(repository: repository)),
        '/tickets': (_) => guard(TicketHistoryScreen(repository: repository)),
        '/vehicles': (_) => guard(VehiclesScreen(repository: repository)),
        '/profile': (_) => guard(ProfileScreen(repository: repository)),
        '/notifications':
            (_) => guard(NotificationsScreen(repository: repository)),
        '/profile/edit':
            (_) => guard(ProfileEditScreen(repository: repository)),
        '/help': (_) => const HelpScreen(),
        '/sync': (_) => guard(SyncQueueScreen(repository: repository)),
        '/staff/home':
            (_) =>
                guard(StaffHomeScreen(repository: repository), staffOnly: true),
        '/staff/scan':
            (_) => guard(
              StaffScannerScreen(repository: repository),
              staffOnly: true,
            ),
        '/staff/confirm':
            (_) => guard(
              StaffConfirmationScreen(repository: repository),
              staffOnly: true,
            ),
        '/staff/slots':
            (_) => guard(
              StaffSlotsScreen(repository: repository),
              staffOnly: true,
            ),
        '/staff/account':
            (_) => guard(
              StaffAccountScreen(repository: repository),
              staffOnly: true,
            ),
      }.map(
        (route, builder) => MapEntry(
          route,
          (context) => Consumer(
            builder: (context, ref, _) {
              ref.watch(parkControllerProvider);
              return builder(context);
            },
          ),
        ),
      ),
    );
  }
}
