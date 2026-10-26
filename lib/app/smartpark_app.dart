import 'package:flutter/material.dart';
import '../core/data/mock_repository.dart';
import '../core/theme/park_theme.dart';
import '../features/auth/auth_screens.dart';
import '../features/parking/parking_screens.dart';
import '../features/booking/booking_screens.dart';
import '../features/tickets/ticket_screens.dart';
import '../features/account/account_screens.dart';
import '../features/staff/staff_screens.dart';

class SmartParkApp extends StatefulWidget {
  const SmartParkApp({super.key, this.staff = false, this.initialRoute});
  final bool staff;
  final String? initialRoute;
  @override
  State<SmartParkApp> createState() => _SmartParkAppState();
}

class _SmartParkAppState extends State<SmartParkApp> {
  final repository = MockParkRepository();
  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder:
        (context, _) => MaterialApp(
          title: widget.staff ? 'SmartPark Staff' : 'SmartPark',
          debugShowCheckedModeBanner: false,
          theme: parkTheme(),
          initialRoute:
              widget.initialRoute ?? (widget.staff ? '/staff/login' : '/'),
          routes: {
            '/': (_) => const SplashScreen(),
            '/onboarding': (_) => const OnboardingScreen(),
            '/login': (_) => AuthScreen(repository: repository),
            '/register':
                (_) => AuthScreen(repository: repository, register: true),
            '/staff/login':
                (_) => AuthScreen(repository: repository, staff: true),
            '/home': (_) => HomeScreen(repository: repository),
            '/parking/map': (_) => ParkingMapScreen(repository: repository),
            '/parking/list': (_) => ParkingListScreen(repository: repository),
            '/parking/detail':
                (_) => ParkingDetailScreen(repository: repository),
            '/booking/slots':
                (_) => SlotSelectionScreen(repository: repository),
            '/booking/time': (_) => TimeSelectionScreen(repository: repository),
            '/booking/confirm':
                (_) => BookingConfirmationScreen(repository: repository),
            '/booking/payment': (_) => PaymentScreen(repository: repository),
            '/tickets/qr': (_) => TicketScreen(repository: repository),
            '/tickets': (_) => TicketHistoryScreen(repository: repository),
            '/vehicles': (_) => VehiclesScreen(repository: repository),
            '/profile': (_) => ProfileScreen(repository: repository),
            '/notifications':
                (_) => NotificationsScreen(repository: repository),
            '/profile/edit': (_) => ProfileEditScreen(repository: repository),
            '/help': (_) => const HelpScreen(),
            '/staff/home': (_) => StaffHomeScreen(repository: repository),
            '/staff/scan': (_) => const StaffScannerScreen(),
            '/staff/confirm':
                (_) => StaffConfirmationScreen(repository: repository),
            '/staff/slots': (_) => StaffSlotsScreen(repository: repository),
            '/staff/account': (_) => StaffAccountScreen(repository: repository),
          },
        ),
  );
}
