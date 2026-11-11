export 'booking_flow.dart';
import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.selected,
    required this.occupied,
    this.recentlyReserved = const {},
    required this.onSelect,
    this.staff = false,
    this.codes = const [],
  });
  final String selected;
  final Set<String> occupied;
  final Set<String> recentlyReserved;
  final ValueChanged<String> onSelect;
  final bool staff;
  final List<String> codes;
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
          itemCount: codes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: staff ? 13 : 16,
            crossAxisSpacing: 10,
            childAspectRatio: staff ? 1.5 : 69 / 53,
          ),
          itemBuilder: (context, i) {
            final slot = codes[i];
            final used = occupied.contains(slot),
                recent = recentlyReserved.contains(slot),
                active = selected == slot;
            return Semantics(
              label: 'Ô $slot${used ? (recent ? ' đang giữ chỗ' : ' đã đặt') : ' còn trống'}',
              selected: active,
              button: true,
              child: Material(
                color:
                    active
                        ? ParkColors.blue
                        : recent
                        ? const Color(0xFFFFF3CD) // Màu vàng nhẹ khi đang giữ chỗ
                        : used
                        ? const Color(0xFFE5EAF0) // Màu xám khi đã đặt/bận
                        : ParkColors.paleGreen, // Màu xanh khi còn trống
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
                              : recent
                              ? const Color(0xFF856404) // Chữ vàng đậm
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
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _legendItem(ParkColors.paleGreen, 'Còn trống'),
        const SizedBox(width: 14),
        _legendItem(const Color(0xFFFFF3CD), 'Đang giữ chỗ (vàng)'),
        const SizedBox(width: 14),
        _legendItem(const Color(0xFFE5EAF0), staff ? 'Đang dùng' : 'Đã đặt (xám)'),
        const SizedBox(width: 14),
        _legendItem(ParkColors.blue, 'Đang chọn (xanh)'),
      ],
    ),
  );

  Widget _legendItem(Color color, String label) => Row(
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
      ),
      const SizedBox(width: 5),
      Txt(label, size: 11, color: ParkColors.muted, weight: FontWeight.w500),
    ],
  );
}

class SlotSelectionScreen extends StatelessWidget {
  const SlotSelectionScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed:
            (repository.slot.isEmpty ||
                    repository.occupied.contains(repository.slot))
                ? null
                : () => Navigator.pushNamed(context, '/booking/confirm'),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Chọn chỗ đỗ',
          subtitle:
              '${repository.lot.name} · ${displayDate(repository.date)} ${clock(repository.start)} - ${clock(repository.end)}',
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
                        '01 Thời gian',
                        size: 11,
                        color: ParkColors.muted,
                      ),
                    ),
                    Expanded(
                      child: Txt(
                        '02 Chọn chỗ',
                        size: 11,
                        color: ParkColors.blue,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Txt(
                        '03 Xác nhận',
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
                codes:
                    repository.slots.map((s) => s['code'] as String).toList(),
                selected: repository.slot,
                occupied: repository.occupied,
                recentlyReserved: repository.recentlyReserved,
                onSelect: (s) => repository.update(() => repository.slot = s),
              ),
              if (repository.slots.isEmpty)
                const Text('Bãi chưa có vị trí khả dụng. Hãy tải lại dữ liệu.'),
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
