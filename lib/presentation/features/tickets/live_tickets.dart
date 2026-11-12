export 'booking_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'booking_extension_sheet.dart';

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
                if (b['status'] == 'parked' && b['local_pending'] != true)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: ParkButton(
                      'Gia hạn thời gian',
                      onPressed: () async {
                        final extended = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder:
                              (_) => BookingExtensionSheet(
                                repository: repository,
                                booking: b,
                              ),
                        );
                        if (extended == true && context.mounted) {
                          showMessage(
                            context,
                            'Gia hạn thành công. Giờ ra dự kiến đã được cập nhật.',
                          );
                        }
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
