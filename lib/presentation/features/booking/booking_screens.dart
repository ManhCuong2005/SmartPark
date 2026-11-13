export 'booking_flow.dart';
export 'payment_screen.dart';
import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'booking_availability_notice.dart';

class CapacitySelectionScreen extends StatelessWidget {
  const CapacitySelectionScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: AsyncParkButton(
        'Tiếp tục',
        enabled: repository.canContinueBooking,
        action: () => bookingStep(context, repository.prepareBooking),
        onSuccess: () => Navigator.pushNamed(context, '/booking/confirm'),
      ),
    ),
    child: Column(
      children: [
        PageHeading('Chỗ còn lại', subtitle: repository.lot.name),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              ParkCard(
                color: ParkColors.paleBlue,
                child: Column(
                  children: [
                    Text(
                      '${displayDate(repository.date)} ${clock(repository.start)} → ${displayDate(repository.endDate)} ${clock(repository.end)}',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đổi thời gian hoặc xe'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BookingAvailabilityNotice(repository: repository),
              if (repository.availabilityLoading)
                const CircularProgressIndicator(),
              if (!repository.availabilityReady &&
                  !repository.availabilityLoading)
                ParkCard(
                  child: Column(
                    children: [
                      Text(
                        repository.availabilityError ??
                            'Chưa kiểm tra được sức chứa.',
                      ),
                      TextButton(
                        onPressed: repository.loadAvailability,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              for (final c in repository.bookingCapacities.where(
                (c) => c['kind'] == repository.bookingVehicleKind,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ParkCard(
                    color:
                        c['kind'] == repository.vehicle.kind
                            ? ParkColors.paleBlue
                            : Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: Icon(
                        c['kind'] == 'car'
                            ? Icons.directions_car
                            : Icons.two_wheeler,
                      ),
                      title: Text(c['kind'] == 'car' ? 'Ô tô' : 'Xe máy'),
                      subtitle: Text(
                        'Còn ${c['remaining']} / ${c['capacity']} chỗ trong thời gian đã chọn',
                      ),
                      trailing:
                          c['kind'] == repository.vehicle.kind
                              ? const Icon(
                                Icons.check_circle,
                                color: ParkColors.blue,
                              )
                              : null,
                    ),
                  ),
                ),
              if (repository.availabilityReady &&
                  repository.remainingCapacity == 0)
                const Text(
                  'Đã hết chỗ cho loại xe đã chọn. Vui lòng đổi thời gian hoặc loại xe.',
                ),
              const SizedBox(height: 16),
              const Text(
                'Sức chứa được máy chủ kiểm tra lại khi xác nhận vé. Không cần chọn từng ô đỗ.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
