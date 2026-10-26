import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';

class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.selected,
    required this.occupied,
    required this.onSelect,
    this.staff = false,
  });
  final String selected;
  final Set<String> occupied;
  final ValueChanged<String> onSelect;
  final bool staff;
  @override
  Widget build(BuildContext context) => ParkCard(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ParkColors.paleBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!staff) ...[
                const FigmaAsset('16:7', 'IconNavigation', size: 16),
                const SizedBox(width: 7),
              ],
              Txt(
                staff ? 'LỐI XE DI CHUYỂN' : 'LỐI VÀO / LỐI RA',
                align: TextAlign.center,
                size: 11,
                color: ParkColors.blue,
                weight: FontWeight.w600,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: staff ? 13 : 16,
            crossAxisSpacing: 10,
            childAspectRatio: staff ? 1.5 : 69 / 53,
          ),
          itemBuilder: (context, i) {
            final slot = 'A${(i + 1).toString().padLeft(2, '0')}';
            final used = occupied.contains(slot), active = selected == slot;
            return Semantics(
              label: 'Ô $slot${used ? ' đang dùng' : ' còn trống'}',
              selected: active,
              button: true,
              child: Material(
                color:
                    active
                        ? ParkColors.blue
                        : used
                        ? const Color(0xFFE5EAF0)
                        : ParkColors.paleGreen,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: !staff && used ? null : () => onSelect(slot),
                  child: Center(
                    child: Txt(
                      slot,
                      size: 12,
                      weight: FontWeight.w600,
                      color:
                          active
                              ? Colors.white
                              : used
                              ? ParkColors.muted
                              : ParkColors.green,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!staff) const SizedBox(height: 26),
      ],
    ),
  );
}

class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key, this.staff = false});
  final bool staff;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: List.generate(
      3,
      (i) => Row(
        children: [
          Container(
            width: 17,
            height: 16,
            decoration: BoxDecoration(
              color:
                  [
                    ParkColors.paleGreen,
                    const Color(0xFFE5EAF0),
                    ParkColors.blue,
                  ][i],
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 6),
          Txt(
            ['Còn trống', staff ? 'Đang dùng' : 'Đã đặt', 'Đang chọn'][i],
            size: 11,
            color: ParkColors.muted,
          ),
        ],
      ),
    ),
  );
}

class SlotSelectionScreen extends StatelessWidget {
  const SlotSelectionScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed: () => Navigator.pushNamed(context, '/booking/time'),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Chọn chỗ đỗ',
          subtitle: '${repository.lot.name} · Tầng 1',
          screen: '16:7',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const ParkCard(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Txt(
                        '01 Chọn chỗ',
                        size: 11,
                        color: ParkColors.blue,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Txt(
                        '02 Thời gian',
                        size: 11,
                        color: ParkColors.muted,
                      ),
                    ),
                    Expanded(
                      child: Txt(
                        '03 Thanh toán',
                        size: 11,
                        color: ParkColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const ParkCard(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                child: SlotLegend(),
              ),
              const SizedBox(height: 20),
              SlotGrid(
                selected: repository.slot,
                occupied: repository.occupied,
                onSelect: (s) => repository.update(() => repository.slot = s),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Txt('Vị trí đã chọn', color: ParkColors.muted),
                  Txt(
                    repository.slot,
                    size: 24,
                    color: ParkColors.blue,
                    weight: FontWeight.w700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class TimeSelectionScreen extends StatelessWidget {
  const TimeSelectionScreen({super.key, required this.repository});
  final MockParkRepository repository;
  Future<void> pick(BuildContext context, bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: start ? repository.start : repository.end,
    );
    if (t == null || !context.mounted) return;
    final a = start ? t : repository.start, b = start ? repository.end : t;
    if (b.hour * 60 + b.minute <= a.hour * 60 + a.minute) {
      mockMessage(context, 'Giờ ra phải sau giờ vào trong cùng ngày.');
      return;
    }
    repository.update(() {
      if (start) {
        repository.start = t;
      } else {
        repository.end = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed: () => Navigator.pushNamed(context, '/booking/confirm'),
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 26),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Txt(
                          'Tháng 10, 2026',
                          size: 17,
                          weight: FontWeight.w700,
                        ),
                        FigmaAsset('16:73', 'IconCalendar', size: 23),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 4 ? 0 : 7),
                            child: InkWell(
                              onTap:
                                  () => repository.update(
                                    () => repository.day = 22 + i,
                                  ),
                              child: Container(
                                height: 91,
                                decoration: BoxDecoration(
                                  color:
                                      repository.day == 22 + i
                                          ? ParkColors.blue
                                          : ParkColors.light,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Txt(
                                      ['T5', 'T6', 'T7', 'CN', 'T2'][i],
                                      size: 11,
                                      color:
                                          repository.day == 22 + i
                                              ? Colors.white
                                              : ParkColors.muted,
                                    ),
                                    const SizedBox(height: 17),
                                    Txt(
                                      '${22 + i}',
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color:
                                          repository.day == 22 + i
                                              ? Colors.white
                                              : ParkColors.ink,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ParkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Txt(
                      'Thời gian gửi xe',
                      size: 17,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        for (var i = 0; i < 2; i++) ...[
                          if (i == 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: FigmaAsset(
                                '16:73',
                                'IconArrowRight',
                                size: 16,
                              ),
                            ),
                          Expanded(
                            child: InkWell(
                              onTap: () => pick(context, i == 0),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: ParkColors.light,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const FigmaAsset(
                                          '16:73',
                                          'IconClock',
                                          size: 17,
                                        ),
                                        const SizedBox(width: 6),
                                        Txt(
                                          i == 0 ? 'Giờ vào' : 'Giờ ra',
                                          size: 12,
                                          color: ParkColors.muted,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 17),
                                    Txt(
                                      clock(
                                        i == 0
                                            ? repository.start
                                            : repository.end,
                                      ),
                                      size: 23,
                                      weight: FontWeight.w700,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ParkCard(
                onTap: () => Navigator.pushNamed(context, '/vehicles'),
                child: Row(
                  children: [
                    const FigmaAsset('16:73', 'IconCar', size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Txt(
                            '${repository.vehicle.label} · ${repository.vehicle.plate}',
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                          const SizedBox(height: 7),
                          const Txt(
                            'Phương tiện mặc định',
                            size: 12,
                            color: ParkColors.muted,
                          ),
                        ],
                      ),
                    ),
                    const FigmaAsset('16:73', 'IconChevronRight', size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ParkCard(
                color: ParkColors.paleBlue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Txt(
                      'Tạm tính · ${repository.durationMinutes / 60} giờ',
                      size: 13,
                      color: ParkColors.blue,
                    ),
                    Txt(
                      money(repository.total),
                      size: 20,
                      color: ParkColors.blue,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
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
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục thanh toán',
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
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              ParkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Txt(
                      'THÔNG TIN ĐẶT CHỖ',
                      size: 12,
                      color: ParkColors.muted,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 10),
                    DetailRow('Bãi đỗ', repository.lot.name),
                    DetailRow('Vị trí đỗ', '${repository.slot} · Tầng 1'),
                    DetailRow('Ngày', '${repository.day}/10/2026'),
                    DetailRow(
                      'Thời gian',
                      '${clock(repository.start)} - ${clock(repository.end)}',
                    ),
                    DetailRow(
                      'Phương tiện',
                      repository.vehicle.plate,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ParkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Txt(
                      'Chi tiết thanh toán',
                      size: 17,
                      weight: FontWeight.w700,
                    ),
                    DetailRow(
                      'Giá gửi xe (${repository.durationMinutes / 60} giờ)',
                      money(repository.total),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Txt('Tổng cộng', weight: FontWeight.w600),
                        Txt(
                          money(repository.total),
                          size: 22,
                          color: ParkColors.blue,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const ParkCard(
                color: ParkColors.paleBlue,
                child: Txt(
                  'Bạn có thể hủy trước giờ vào bãi.',
                  size: 12,
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
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Xác nhận thanh toán',
        onPressed: () async {
          final confirmed = await confirmMock(
            context,
            'Đây là thanh toán mô phỏng qua ${repository.payment}. Không thu tiền, không gọi cổng thanh toán. Vé QR tạo ra chưa được kích hoạt.',
          );
          if (!confirmed || !context.mounted) return;
          repository.update(() => repository.booked = true);
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/tickets/qr',
            (r) => false,
          );
        },
      ),
    ),
    child: Column(
      children: [
        const PageHeading(
          'Thanh toán',
          subtitle: 'Chọn phương thức bạn muốn sử dụng',
          screen: '16:176',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++) ...[
                ParkCard(
                  onTap:
                      () => repository.update(
                        () =>
                            repository.payment =
                                [
                                  'Ví MoMo',
                                  'VNPAY QR',
                                  'Thẻ ngân hàng',
                                  'Tiền mặt',
                                ][i],
                      ),
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              i == 1 ? ParkColors.paleBlue : ParkColors.light,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: FigmaAsset(
                            '16:176',
                            [
                              'IconWallet',
                              'IconQr',
                              'IconCredit',
                              'IconWallet',
                            ][i],
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              [
                                'Ví MoMo',
                                'VNPAY QR',
                                'Thẻ ngân hàng',
                                'Tiền mặt',
                              ][i],
                              size: 15,
                              weight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            Txt(
                              [
                                'Thanh toán qua ví điện tử',
                                'Quét mã bằng ứng dụng ngân hàng',
                                'Visa, Mastercard hoặc nội địa',
                                'Thanh toán khi đến bãi đỗ',
                              ][i],
                              size: 12,
                              color: ParkColors.muted,
                            ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value:
                            [
                              'Ví MoMo',
                              'VNPAY QR',
                              'Thẻ ngân hàng',
                              'Tiền mặt',
                            ][i],
                        groupValue: repository.payment,
                        onChanged:
                            (v) => repository.update(
                              () => repository.payment = v!,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 28),
              const Divider(color: ParkColors.line),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Txt(
                    'Tổng thanh toán',
                    size: 13,
                    color: ParkColors.muted,
                  ),
                  Txt(
                    money(repository.total),
                    size: 24,
                    weight: FontWeight.w700,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ParkCard(
                color: ParkColors.paleGreen,
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    FigmaAsset('16:176', 'IconShield', size: 18),
                    SizedBox(width: 8),
                    Txt(
                      'Thanh toán an toàn và bảo mật',
                      size: 12,
                      color: ParkColors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Txt(
                'Chế độ demo • chưa kết nối thanh toán',
                size: 11,
                color: ParkColors.muted,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
