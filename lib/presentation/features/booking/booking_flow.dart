import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'booking_availability_notice.dart';

class VehicleTypeSelectionScreen extends StatelessWidget {
  const VehicleTypeSelectionScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) {
    final kinds = repository.bookingVehicleKinds;
    final selected = repository.bookingVehicleKind;
    return ParkPage(
      bottom: BottomAction(
        child: ParkButton(
          'Tiếp tục',
          onPressed:
              selected == null
                  ? null
                  : () {
                    repository.selectBookingVehicleKind(selected);
                    Navigator.pushNamed(context, '/booking/time');
                  },
        ),
      ),
      child: Column(
        children: [
          PageHeading('Chọn loại phương tiện', subtitle: repository.lot.name),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                for (final kind in kinds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      selected: kind == selected,
                      button: kinds.length > 1,
                      child: ParkCard(
                        color:
                            kind == selected
                                ? ParkColors.paleBlue
                                : Theme.of(context).colorScheme.surface,
                        onTap:
                            kinds.length > 1
                                ? () =>
                                    repository.selectBookingVehicleKind(kind)
                                : null,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            kind == 'car'
                                ? Icons.directions_car
                                : Icons.two_wheeler,
                          ),
                          title: Text(kind == 'car' ? 'Ô tô' : 'Xe máy'),
                          subtitle: Text(
                            '${repository.vehicles.where((v) => v.kind == kind).length} xe trong Xe của tôi',
                          ),
                          trailing: Icon(
                            kind == selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color:
                                kind == selected
                                    ? ParkColors.blue
                                    : ParkColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (kinds.isEmpty) ...[
                  const Text(
                    'Thêm phương tiện vào Xe của tôi để bắt đầu đặt vé.',
                  ),
                  const SizedBox(height: 16),
                  ParkButton(
                    'Thêm phương tiện',
                    onPressed: () => Navigator.pushNamed(context, '/vehicles'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimeSelectionScreen extends StatelessWidget {
  const TimeSelectionScreen({super.key, required this.repository});
  final ParkController repository;
  Future<void> pick(BuildContext context, bool entering) async {
    final time = await showTimePicker(
      context: context,
      initialTime: entering ? repository.start : repository.end,
    );
    if (time == null) return;
    final original = entering ? repository.startsAt : repository.endsAt;
    final chosen = DateTime(
      original.year,
      original.month,
      original.day,
      time.hour,
      time.minute,
    );
    final duration = repository.endsAt.difference(repository.startsAt);
    repository.setReservationPeriod(
      entering ? chosen : repository.startsAt,
      entering ? chosen.add(duration) : chosen,
    );
  }

  Future<void> day(BuildContext context, bool entering) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: entering ? repository.date : repository.endDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null) return;
    final time = entering ? repository.start : repository.end;
    final chosen = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final duration = repository.endsAt.difference(repository.startsAt);
    repository.setReservationPeriod(
      entering ? chosen : repository.startsAt,
      entering ? chosen.add(duration) : chosen,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (repository.bookingVehicleKind == null) {
      return VehicleTypeSelectionScreen(repository: repository);
    }
    final vehicles = repository.bookingVehicles;
    return ParkPage(
      bottom: BottomAction(
        child: AsyncParkButton(
          'Tiếp tục',
          action: () => repository.prepareBooking(),
          onSuccess: () => Navigator.pushNamed(context, '/booking/confirm'),
        ),
      ),
      child: Column(
        children: [
          const PageHeading(
            'Chọn thời gian',
            subtitle: 'Chọn ngày và khoảng thời gian muốn đỗ',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                BookingAvailabilityNotice(repository: repository),
                ParkCard(
                  child: Column(
                    children: [
                      for (final entering in [true, false])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entering ? 'Ngày vào' : 'Ngày ra'),
                          subtitle: Text(
                            displayDate(
                              entering ? repository.date : repository.endDate,
                            ),
                          ),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () => day(context, entering),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ParkCard(
                  child: Row(
                    children: [
                      for (final entering in [true, false])
                        Expanded(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(4),
                            title: Text(entering ? 'Giờ vào' : 'Giờ ra'),
                            subtitle: Text(
                              clock(
                                entering ? repository.start : repository.end,
                              ),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => pick(context, entering),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Txt('Thời lượng đỗ nhanh', weight: FontWeight.w600),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final hours in [1, 2, 4, 8])
                            ChoiceChip(
                              label: Text('+$hours giờ'),
                              showCheckmark: false,
                              selected:
                                  repository.durationMinutes == hours * 60,
                              onSelected: (_) => repository.setDuration(hours),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ParkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repository.bookingVehicleKind == 'car'
                            ? 'Ô tô'
                            : 'Xe máy',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (vehicles.length > 1)
                        DropdownButton<String>(
                          isExpanded: true,
                          value: repository.vehicle.id,
                          items: [
                            for (final vehicle in vehicles)
                              DropdownMenuItem(
                                value: vehicle.id,
                                child: Text(
                                  '${vehicle.label} · ${vehicle.plate}',
                                ),
                              ),
                          ],
                          onChanged: repository.selectVehicle,
                        )
                      else
                        Text(
                          '${repository.vehicle.label} · ${repository.vehicle.plate}',
                        ),
                      TextButton(
                        onPressed:
                            () => Navigator.pushNamed(context, '/vehicles'),
                        child: const Text('Quản lý phương tiện'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ParkCard(
                  color: ParkColors.paleBlue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Txt('Tạm tính', color: ParkColors.blue),
                      Txt(
                        money(repository.total),
                        size: 20,
                        color: ParkColors.blue,
                        weight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thanh toán trước theo khoảng thời gian đã đặt, tối thiểu 1 giờ. Vé chưa check-in sẽ hết hiệu lực khi đến giờ ra dự kiến.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: AsyncParkButton(
        'Thanh toán',
        action: () => bookingStep(context, repository.prepareBooking),
        onSuccess: () => Navigator.pushNamed(context, '/booking/payment'),
      ),
    ),
    child: Column(
      children: [
        const PageHeading(
          'Xác nhận đặt chỗ',
          subtitle: 'Vui lòng kiểm tra lại thông tin',
          screen: '16:134',
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              BookingAvailabilityNotice(repository: repository),
              ParkCard(
                child: Column(
                  children: [
                    DetailRow('Bãi đỗ', repository.lot.name),
                    DetailRow(
                      'Loại xe',
                      repository.vehicle.kind == 'car' ? 'Ô tô' : 'Xe máy',
                    ),
                    DetailRow(
                      'Giờ vào',
                      '${displayDate(repository.date)} ${clock(repository.start)}',
                    ),
                    DetailRow(
                      'Giờ ra',
                      '${displayDate(repository.endDate)} ${clock(repository.end)}',
                    ),
                    DetailRow('Phương tiện', repository.vehicle.plate),
                    DetailRow('Tạm tính', money(repository.total), last: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const ParkCard(
                color: ParkColors.paleBlue,
                child: Txt(
                  'Hủy hợp lệ trước giờ vào được hoàn tiền vào số dư gửi xe. Vé chưa check-in sẽ hết hiệu lực khi đến giờ ra dự kiến.',
                  color: ParkColors.blue,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

