export 'booking_flow.dart';
import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.selected,
    required this.occupied,
    required this.onSelect,
    this.staff = false,
    this.codes = const [],
  });
  final String selected;
  final Set<String> occupied;
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
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: BottomAction(
      child: ParkButton(
        'Tiếp tục',
        onPressed:
            repository.slot.isEmpty
                ? null
                : () => Navigator.pushNamed(context, '/booking/time'),
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
                codes:
                    repository.slots.map((s) => s['code'] as String).toList(),
                selected: repository.slot,
                occupied: repository.occupied,
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
