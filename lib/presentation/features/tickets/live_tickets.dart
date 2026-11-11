import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../domain/vietqr_service.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) {
    final b = repository.ticket;
    if (b == null) {
      return const ParkPage(
        bottom: ParkBottomNav(active: 2),
        child: Column(
          children: [
            PageHeading('Vé điện tử'),
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chọn vé trong lịch sử đặt chỗ.'),
            ),
          ],
        ),
      );
    }
    final lot = repository.lots.where((l) => l.id == b['lot_id']).firstOrNull;
    final slot =
        repository.snapshot
            .rows('slots')
            .where((s) => s['id'] == b['slot_id'])
            .firstOrNull;
    final active = ['confirmed', 'parked'].contains(b['status']);
    return ParkPage(
      bottom: const ParkBottomNav(active: 2),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            color: ParkColors.navy,
            child: Column(
              children: [
                const Icon(
                  Icons.confirmation_number,
                  color: Colors.white,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Txt(
                  statusLabel(b['status'] as String),
                  size: 23,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                const Txt('Vé điện tử SmartPark', color: Color(0xFFB9CFE4)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                if (b['status'] == 'confirmed') ...[
                  Builder(
                    builder: (context) {
                      final startsAt = DateTime.parse(b['starts_at'] as String);
                      final deadline = startsAt.add(const Duration(hours: 1));
                      final now = DateTime.now();
                      final diff = deadline.difference(now);
                      final isImminent = diff.inMinutes <= 15 && !diff.isNegative;
                      final isOverdue = diff.isNegative;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.shade50
                              : (isImminent ? Colors.orange.shade50 : ParkColors.paleBlue),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOverdue
                                ? Colors.red.shade300
                                : (isImminent ? Colors.orange.shade300 : ParkColors.blue.withAlpha(80)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: isOverdue
                                  ? Colors.red.shade700
                                  : (isImminent ? Colors.orange.shade800 : ParkColors.blue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isOverdue
                                    ? 'Vé đã quá hạn check-in 1 tiếng và có thể bị hủy tự động.'
                                    : (isImminent
                                        ? 'Sắp hết hạn giữ chỗ! Còn ${diff.inMinutes} phút để check-in.'
                                        : 'Vui lòng check-in trước ${deadline.toLocal().hour}:${deadline.toLocal().minute.toString().padLeft(2, '0')} (tối đa 1h sau giờ hẹn).'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue
                                      ? Colors.red.shade800
                                      : (isImminent ? Colors.orange.shade900 : ParkColors.navy),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                ParkCard(
                  child: Column(
                    children: [
                      Txt(lot?.name ?? '', size: 19, weight: FontWeight.w700),
                      Text('${slot?['code'] ?? ''} · ${b['plate']}'),
                      const SizedBox(height: 20),
                      if (active)
                        Semantics(
                          label: 'Mã QR vé điện tử',
                          child: QrImageView(
                            data:
                                TicketIdentity(
                                  b['id'] as String,
                                  b['qr_token'] as String,
                                ).encoded,
                            size: 210,
                            backgroundColor: Colors.white,
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Vé đã kết thúc, QR không còn hiệu lực.'),
                        ),
                      SelectableText(
                        b['id'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ParkCard(
                  child: Column(
                    children: [
                      DetailRow(
                        'Giờ vào dự kiến',
                        DateTime.parse(
                          b['starts_at'] as String,
                        ).toLocal().toString(),
                      ),
                      DetailRow(
                        'Giờ ra dự kiến',
                        DateTime.parse(
                          b['ends_at'] as String,
                        ).toLocal().toString(),
                      ),
                      DetailRow(
                        'Trạng thái',
                        statusLabel(b['status'] as String),
                      ),
                      if (b['status'] == 'completed')
                        DetailRow(
                          'Đã thu',
                          money(b['amount'] as int),
                          last: true,
                        ),
                    ],
                  ),
                ),
                if (b['status'] == 'parked' || (b['status'] == 'completed' && b['amount'] != null && (b['amount'] as int) > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Thanh toán qua VietQR'),
                      onPressed: () {
                        final amount = b['amount'] as int? ?? 15000;
                        final plate = b['plate'] as String? ?? '';
                        final desc = 'SPK $plate'.trim();
                        final bankBin = '970422'; // MBBank
                        final accountNo = '0000123456789';
                        final emvCoPayload = VietQrHelper.generateEmvCoPayload(
                          bankBin: bankBin,
                          accountNo: accountNo,
                          amount: amount,
                          description: desc,
                        );
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Quét mã VietQR chuyển khoản'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: QrImageView(
                                    data: emvCoPayload,
                                    size: 220,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Số tiền: ${money(amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('STK: $accountNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: accountNo));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Đã sao chép số tài khoản'), duration: Duration(seconds: 1)),
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              child: Text('Sao chép', style: TextStyle(fontSize: 11, color: ParkColors.blue, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('ND: $desc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: desc));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Đã sao chép nội dung chuyển khoản'), duration: Duration(seconds: 1)),
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              child: Text('Sao chép', style: TextStyle(fontSize: 11, color: ParkColors.blue, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (b['status'] == 'confirmed')
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: AsyncParkButton(
                      'Hủy đặt chỗ',
                      action: () async {
                        if (await confirmAction(context, 'Hủy đặt chỗ này?')) {
                          await repository.cancelBooking(b);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TicketHistoryScreen extends StatefulWidget {
  const TicketHistoryScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  bool active = true;
  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final rows =
        repo.bookings
            .where(
              (b) =>
                  b['customer_id'] == repo.userId &&
                  (['confirmed', 'parked'].contains(b['status']) == active),
            )
            .toList();
    return ParkPage(
      bottom: const ParkBottomNav(active: 2),
      child: Column(
        children: [
          const PageHeading('Lịch sử đặt chỗ', back: false),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Pill(
                        'Đang hoạt động',
                        selected: active,
                        onTap: () => setState(() => active = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Pill(
                        'Đã kết thúc',
                        selected: !active,
                        onTap: () => setState(() => active = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (rows.isEmpty) const Text('Chưa có vé trong danh sách này.'),
                for (final b in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ParkCard(
                      onTap: () {
                        repo.update(
                          () => repo.selectedBookingId = b['id'] as String,
                        );
                        Navigator.pushNamed(context, '/tickets/qr');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repo.lots
                                    .where((l) => l.id == b['lot_id'])
                                    .firstOrNull
                                    ?.name ??
                                '',
                          ),
                          const SizedBox(height: 8),
                          Txt(
                            b['plate'] as String,
                            size: 19,
                            weight: FontWeight.w700,
                          ),
                          Text(statusLabel(b['status'] as String)),
                          Text(
                            DateTime.parse(
                              b['starts_at'] as String,
                            ).toLocal().toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
