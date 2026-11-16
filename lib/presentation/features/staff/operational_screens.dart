import 'package:flutter/material.dart';
import '../../../domain/parking_rules.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../../../shared/widgets/plate_input.dart';

export 'automatic_scanner_screen.dart';

class StaffConfirmationScreen extends StatefulWidget {
  const StaffConfirmationScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<StaffConfirmationScreen> createState() =>
      _StaffConfirmationScreenState();
}

class _StaffConfirmationScreenState extends State<StaffConfirmationScreen> {
  late final plate = TextEditingController(
    text: widget.repository.ticket?['plate'] as String? ?? '',
  );
  void returnToScanner() {
    final navigator = Navigator.of(context);
    var scannerInStack = false;
    navigator.popUntil((route) {
      scannerInStack = route.settings.name == '/staff/scan';
      return scannerInStack || route.isFirst;
    });
    if (!scannerInStack) navigator.pushNamed('/staff/scan');
  }

  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository, b = repo.ticket;
    if (b == null) return const ParkPage(child: PageHeading('Chưa chọn vé'));
    final entering = b['status'] == 'confirmed';
    final prepaid = b['prepaid'] == true;
    final scheduledEnd = DateTime.parse(b['ends_at'] as String).toLocal();
    final arrival = DateTime.now();
    final late = entering && !arrival.isBefore(scheduledEnd);
    final pending = repo.operations.any(
      (o) => o.payload['booking_id'] == b['id'],
    );
    final preview =
        b['checked_in_at'] == null ? null : checkoutAmount(b, DateTime.now());
    return ParkPage(
      child: Column(
        children: [
          const PageHeading(
            'Xác nhận vé',
            subtitle: 'Kiểm tra biển số thực tế và vé hợp lệ',
            screen: '27:144',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                ParkCard(
                  child: Column(
                    children: [
                      DetailRow('Biển số trên vé', b['plate'] as String),
                      DetailRow(
                        'Trạng thái',
                        statusLabel(b['status'] as String),
                      ),
                      if (entering)
                        DetailRow(
                          'Hạn nhận xe',
                          '${displayDate(noShowDeadline(scheduledEnd))} ${clock(TimeOfDay.fromDateTime(noShowDeadline(scheduledEnd)))}',
                        ),
                      if (preview != null && b['status'] == 'parked') ...[
                        if (prepaid)
                          DetailRow(
                            'Đã thanh toán trước',
                            money(b['amount'] as int),
                          ),
                        DetailRow(
                          prepaid ? 'Cần thu tại cổng' : 'Số tiền cần thu',
                          money(preview),
                        ),
                        DetailRow(
                          'Đơn giá',
                          '${money(b['hourly_rate'] as int)}/giờ',
                        ),
                        Text(
                          prepaid
                              ? 'Vé đã thanh toán trước. Không thu lại tiền vé khi xe ra.'
                              : 'Thu từ phút đầu, tối thiểu 1 giờ. Chỉ xác nhận xe ra sau khi đã thu tiền.',
                        ),
                        if (prepaid && DateTime.now().isAfter(scheduledEnd))
                          const Text(
                            'Xe đã quá giờ đăng ký. Nhắc khách gia hạn và thanh toán phần thời gian thêm. Quy tắc xử lý chưa gia hạn đang chờ cấu hình.',
                          ),
                      ],
                      if (b['status'] == 'completed' &&
                          b['local_pending'] != true)
                        DetailRow('Đã thu', money(b['amount'] as int)),
                      if (b['status'] == 'completed' &&
                          b['local_pending'] == true)
                        DetailRow(
                          prepaid
                              ? 'Đã thanh toán trước'
                              : 'Khoản thu chờ đồng bộ',
                          money(b['amount'] as int),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (late) ...[
                  ParkCard(
                    color: ParkColors.paleBlue,
                    child: Text(
                      'Vé chưa sử dụng đã quá giờ ra dự kiến. Không thể check-in bằng vé này; khách cần đặt vé mới.',
                      style: const TextStyle(color: ParkColors.navy),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                PlateInput(controller: plate, capture: repo.recognizePlate),
                const SizedBox(height: 20),
                if (pending)
                  const Text(
                    'Vé có thao tác chờ. Trạng thái trên thiết bị chưa được máy chủ xác nhận. Xem hàng đợi để biết kết quả hoặc xung đột.',
                  ),
                if (['confirmed', 'parked'].contains(b['status']))
                  AsyncParkButton(
                    entering
                        ? 'Xác nhận xe vào'
                        : prepaid
                        ? 'Xác nhận xe ra'
                        : 'Xác nhận thu tiền mặt và xe ra',
                    enabled: !late,
                    action: () async {
                      final checkoutAt = DateTime.now().toUtc();
                      final due =
                          entering ? null : checkoutAmount(b, checkoutAt);
                      if (!await confirmAction(
                        context,
                        entering
                            ? 'Xác nhận biển số thực tế và cho xe vào bãi?'
                            : prepaid
                            ? 'Xác nhận xe ${b['plate']} ra bãi? Vé đã thanh toán trước, không thu thêm tại cổng.'
                            : 'Xác nhận đã thu ${money(due!)} tiền mặt cho xe ${b['plate']} và cho xe ra?${repo.online ? '' : ' Đang ngoại tuyến: khoản thu sẽ chờ máy chủ xác nhận, chưa vào doanh thu.'}',
                      )) {
                        return;
                      }
                      await repo.staffAction(
                        entering,
                        plate.text,
                        checkoutAt: entering ? null : checkoutAt,
                      );
                      if (context.mounted) {
                        showMessage(
                          context,
                          repo.operations.any(
                                (o) => o.payload['booking_id'] == b['id'],
                              )
                              ? 'Thao tác đang chờ máy chủ xác nhận. Kiểm tra hàng đợi.'
                              : entering
                              ? 'Máy chủ đã xác nhận xe vào.'
                              : prepaid
                              ? 'Đã xác nhận xe ra. Vé đã thanh toán trước, không thu lại tiền.'
                              : 'Đã ghi nhận thu ${money(repo.ticket?['amount'] as int? ?? due!)} và xe ra. Khoản thu đã gửi vào doanh thu của bãi.',
                        );
                        returnToScanner();
                      }
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/sync'),
                  child: const Text('Xem hàng đợi đồng bộ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
