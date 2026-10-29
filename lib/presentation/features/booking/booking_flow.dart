import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class TimeSelectionScreen extends StatelessWidget {
  const TimeSelectionScreen({super.key, required this.repository});
  final ParkController repository;
  Future<void> pick(BuildContext context, bool entering) async {
    final time = await showTimePicker(
      context: context,
      initialTime: entering ? repository.start : repository.end,
    );
    if (time == null) return;
    repository.update(() {
      if (entering) {
        repository.start = time;
      } else {
        repository.end = time;
      }
    });
    await repository.loadAvailability();
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
    repository.update(() {
      if (entering) {
        repository.date = date;
        if (repository.endDate.isBefore(date)) repository.endDate = date;
      } else {
        repository.endDate = date;
      }
    });
    await repository.loadAvailability();
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed:
            repository.durationMinutes <= 0
                ? null
                : () => Navigator.pushNamed(context, '/booking/confirm'),
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
                            clock(entering ? repository.start : repository.end),
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
              ParkCard(
                onTap: () => Navigator.pushNamed(context, '/vehicles'),
                child: Column(
                  children: [
                    const Txt('Phương tiện', weight: FontWeight.w600),
                    DropdownButton<String>(
                      isExpanded: true,
                      value:
                          repository.vehicles.any(
                                (v) => v.id == repository.vehicle.id,
                              )
                              ? repository.vehicle.id
                              : null,
                      hint: const Text('Thêm phương tiện'),
                      items:
                          repository.vehicles
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Text('${v.label} · ${v.plate}'),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (id) => repository.update(
                            () => repository.selectedVehicleId = id,
                          ),
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
                'Chỗ đỗ được kiểm tra lại khi xác nhận. Giá cuối cùng tính theo thời gian xe thực tế ở bãi.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed: () => Navigator.pushNamed(context, '/booking/payment'),
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
              ParkCard(
                child: Column(
                  children: [
                    DetailRow('Bãi đỗ', repository.lot.name),
                    DetailRow('Vị trí đỗ', repository.slot),
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
                  'Có thể hủy vé đã xác nhận trước giờ vào bãi.',
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

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: AsyncParkButton(
        'Xác nhận đặt chỗ',
        action: repository.book,
        onSuccess:
            () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/tickets/qr',
              (r) => false,
            ),
      ),
    ),
    child: Column(
      children: [
        const PageHeading(
          'Thanh toán tại bãi',
          subtitle: 'Thanh toán tiền mặt khi xe ra bãi',
          screen: '16:176',
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const ParkCard(
                child: ListTile(
                  leading: Icon(Icons.payments),
                  title: Text('Tiền mặt'),
                  subtitle: Text(
                    'Nhân viên xác nhận số tiền tại bước check-out.',
                  ),
                  trailing: Icon(Icons.check_circle, color: ParkColors.blue),
                ),
              ),
              const SizedBox(height: 20),
              DetailRow('Tạm tính', money(repository.total)),
              const ParkCard(
                color: ParkColors.paleBlue,
                child: Txt(
                  'Cần kết nối mạng để xác nhận đặt chỗ. Vé QR chỉ được cấp khi máy chủ đã chấp nhận.',
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
