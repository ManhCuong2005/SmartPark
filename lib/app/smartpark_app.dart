import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/sync_queue_screen.dart';
import 'providers.dart';
import '../shared/widgets/park_widgets.dart';
import '../presentation/features/auth/auth_screens.dart';
import '../presentation/features/parking/parking_screens.dart';
import '../presentation/features/parking/parking_reports_screen.dart';
import '../presentation/features/booking/booking_screens.dart';
import '../presentation/features/tickets/ticket_screens.dart';
import '../presentation/features/account/account_screens.dart';
import '../presentation/features/account/wallet_screen.dart';
import '../presentation/features/staff/staff_screens.dart';

class SmartParkApp extends ConsumerWidget {
  const SmartParkApp({super.key, this.staff = false, this.initialRoute});
  final bool staff;
  final String? initialRoute;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(parkControllerProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);
    final notification = repository.notificationToOpen;
    if (notification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (repository.notificationToOpen != notification) return;
        repository.notificationToOpen = null;
        if (repository.signedIn) {
          navigatorKey.currentState?.pushNamed('/tickets/detail');
        }
      });
    }
    Widget guard(Widget view, {bool staffOnly = false}) {
      if (!repository.signedIn) {
        return AuthScreen(repository: repository, staff: staffOnly || staff);
      }
      if (staffOnly && !repository.canStaff) {
        return ParkPage(
          child: Column(
            children: [
              if (repository.signedIn && repository.rejections.isNotEmpty)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              repository.rejections.first.error ??
                                  'Thay đổi không được máy chủ chấp nhận.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => repository.discardOperation(
                                  repository.rejections.first.id,
                                ),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
      navigatorKey: navigatorKey,
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
              if (repository.signedIn &&
                  (!repository.online || repository.error != null))
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(Icons.cloud_off_outlined, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Chưa thể đồng bộ. Đang hiển thị dữ liệu đã lưu.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('sync-retry-button'),
                          onPressed: repository.refresh,
                          child: const Text('Thử lại'),
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
        // The base map is public. Private vehicles/tickets and booking actions
        // remain protected; lot records still come from the authenticated API.
        '/parking/map':
            (_) => ParkingMapScreen(
              repository: repository,
              locationService: ref.read(locationServiceProvider),
              tileProviderFactory: ref.read(mapTileProviderFactoryProvider),
            ),
        '/parking/list':
            (_) => guard(ParkingListScreen(repository: repository)),
        '/parking/detail':
            (_) => guard(ParkingDetailScreen(repository: repository)),
        '/booking/capacity':
            (_) => guard(CapacitySelectionScreen(repository: repository)),
        '/booking/vehicle-type':
            (_) => guard(VehicleTypeSelectionScreen(repository: repository)),
        '/booking/time':
            (_) => guard(TimeSelectionScreen(repository: repository)),
        '/booking/confirm':
            (_) => guard(BookingConfirmationScreen(repository: repository)),
        '/booking/payment': (_) => guard(PaymentScreen(repository: repository)),
        '/tickets/detail': (_) => guard(TicketScreen(repository: repository)),
        '/tickets': (_) => guard(TicketHistoryScreen(repository: repository)),
        '/vehicles': (_) => guard(VehiclesScreen(repository: repository)),
        '/profile': (_) => guard(ProfileScreen(repository: repository)),
        if (!staff) '/wallet': (_) => guard(const WalletScreen()),
        '/notifications':
            (_) => guard(NotificationsScreen(repository: repository)),
        '/profile/edit':
            (_) => guard(ProfileEditScreen(repository: repository)),
        '/help': (_) => const HelpScreen(),
        '/reports': (_) => guard(ParkingReportsScreen(repository: repository)),
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
        '/staff/capacity':
            (_) => guard(
              StaffCapacityScreen(repository: repository),
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
