import 'package:flutter/material.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../../park_controller.dart';

class BookingAvailabilityNotice extends StatelessWidget {
  const BookingAvailabilityNotice({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) {
    final conflict = repository.vehicleConflict;
    if (conflict == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ParkCard(
        color: ParkColors.paleBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Txt(
              'Xe đã có lịch trùng giờ',
              color: ParkColors.blue,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 10),
            Text(
              repository.vehicleConflictMessage,
              style: const TextStyle(color: ParkColors.navy),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    await repository.refresh();
                    if (!context.mounted) return;
                    repository.update(
                      () =>
                          repository.selectedBookingId =
                              conflict['id'] as String,
                    );
                    Navigator.pushNamed(context, '/tickets/qr');
                  },
                  child: const Text('Xem vé đang trùng'),
                ),
                if (ModalRoute.of(context)?.settings.name != '/booking/time')
                  TextButton(
                    onPressed:
                        () => Navigator.popUntil(
                          context,
                          (route) =>
                              route.settings.name == '/booking/time' ||
                              route.isFirst,
                        ),
                    child: const Text('Đổi xe hoặc giờ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reopen the relevant step when another device takes a slot or books the same
/// vehicle between preflight and the atomic write. The button keeps the error
/// visible via the app's normal error handler and never opens a success ticket.
Future<void> bookingStep(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ParkFailure catch (error) {
    if (context.mounted &&
        [
          'VEHICLE_TIME_CONFLICT',
          'SLOT_TIME_CONFLICT',
          'SLOT_UNAVAILABLE',
          '23P01',
        ].contains(error.code)) {
      final target =
          error.code == 'VEHICLE_TIME_CONFLICT'
              ? '/booking/time'
              : '/booking/slots';
      Navigator.popUntil(
        context,
        (route) => route.settings.name == target || route.isFirst,
      );
    }
    rethrow;
  }
}
