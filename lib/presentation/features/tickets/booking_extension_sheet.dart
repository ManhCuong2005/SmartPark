import 'package:flutter/material.dart';
import '../../../domain/parking_rules.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../../park_controller.dart';

class BookingExtensionSheet extends StatefulWidget {
  const BookingExtensionSheet({
    super.key,
    required this.repository,
    required this.booking,
  });
  final ParkController repository;
  final Json booking;
  @override
  State<BookingExtensionSheet> createState() => _BookingExtensionSheetState();
}

class _BookingExtensionSheetState extends State<BookingExtensionSheet> {
  int hours = 1;
  bool submitting = false;
  late final DateTime base;
  @override
  void initState() {
    super.initState();
    final planned =
        DateTime.parse(widget.booking['ends_at'] as String).toLocal();
    final now = DateTime.now();
    base = planned.isAfter(now) ? planned : now;
  }

  @override
  Widget build(BuildContext context) {
    final until = base.add(Duration(hours: hours));
    final expected = calculateFee(
      DateTime.parse(widget.booking['checked_in_at'] as String),
      until,
      widget.booking['hourly_rate'] as int,
      0,
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Txt(
                'Gia hạn thời gian gửi xe',
                size: 21,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 12),
              const Text(
                'Máy chủ sẽ kiểm tra lịch ô đỗ và phương tiện trước khi đồng ý. Gia hạn không thu tiền trước; phí thực tế tính khi xe ra.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in [1, 2, 4])
                    ChoiceChip(
                      label: Text('+$h giờ'),
                      selected: hours == h,
                      onSelected:
                          submitting ? null : (_) => setState(() => hours = h),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DetailRow(
                'Giờ ra mới',
                '${displayDate(until)} ${clock(TimeOfDay.fromDateTime(until))}',
              ),
              DetailRow('Phí dự kiến đến giờ mới', money(expected)),
              const SizedBox(height: 16),
              AsyncParkButton(
                'Xác nhận gia hạn',
                enabled: !submitting,
                action: () async {
                  setState(() => submitting = true);
                  try {
                    await widget.repository.extendBooking(
                      widget.booking,
                      until,
                    );
                  } finally {
                    if (mounted) setState(() => submitting = false);
                  }
                },
                onSuccess: () => Navigator.pop(context, true),
              ),
              Center(
                child: TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
