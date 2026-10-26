import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';
import 'demo_qr.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 2),
    child: Column(
      children: [
        Container(
          height: 211,
          width: double.infinity,
          color: ParkColors.navy,
          child: Stack(
            children: [
              const Positioned(
                top: -41,
                right: -77,
                child: FigmaAsset('16:228', 'Decorative', size: 192),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 29),
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 62,
                        height: 62,
                        child: Stack(
                          children: [
                            FigmaAsset('16:228', 'SuccessCircle', size: 62),
                            Positioned(
                              left: 14,
                              top: 12,
                              child: FigmaAsset(
                                '16:228',
                                'IconCheck',
                                size: 35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Txt(
                        'Đặt chỗ thành công!',
                        size: 23,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      const Txt(
                        'Mã vé đã sẵn sàng để sử dụng.',
                        size: 13,
                        color: Color(0xFFB9CFE4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(23, 21, 23, 20),
          child: Column(
            children: [
              ParkCard(
                child: Column(
                  children: [
                    Txt(repository.lot.name, size: 19, weight: FontWeight.w700),
                    const SizedBox(height: 10),
                    Txt(
                      '${repository.slot} · Tầng 1 · ${repository.day}/10/2026',
                      size: 12,
                      color: ParkColors.muted,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'QR minh họa chưa kích hoạt',
                      image: true,
                      child: CustomPaint(
                        size: const Size(198, 198),
                        painter: DemoQr(),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Txt(
                      'QR minh họa · chưa kích hoạt',
                      size: 11,
                      color: ParkColors.muted,
                    ),
                    const SizedBox(height: 22),
                    const Txt('MÃ ĐẶT CHỖ', size: 11, color: ParkColors.muted),
                    const SizedBox(height: 7),
                    const Txt('SP-1022-007', size: 20, weight: FontWeight.w700),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ParkCard(
                child: Row(
                  children: [
                    const FigmaAsset('16:228', 'IconClock', size: 25),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Txt(
                            '${clock(repository.start)} - ${clock(repository.end)}',
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(height: 5),
                          const Txt(
                            'Giờ gửi xe',
                            size: 12,
                            color: ParkColors.muted,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Thông tin vé demo',
                      onPressed:
                          () => mockMessage(
                            context,
                            'Vé demo chưa kích hoạt, chưa thể chia sẻ vé sử dụng thực tế.',
                          ),
                      icon: const FigmaAsset('16:228', 'IconShare', size: 22),
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

class TicketHistoryScreen extends StatefulWidget {
  const TicketHistoryScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading('Lịch sử đặt chỗ', back: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Pill(
                      'Đang hoạt động',
                      selected: tab == 0,
                      onTap: () => setState(() => tab = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pill(
                      'Đã hoàn thành',
                      selected: tab == 1,
                      onTap: () => setState(() => tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              if (tab == 0)
                ParkCard(
                  onTap: () => Navigator.pushNamed(context, '/tickets/qr'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          FigmaAsset('16:390', 'Status', size: 8),
                          SizedBox(width: 8),
                          Txt(
                            'ĐANG SỬ DỤNG',
                            size: 11,
                            color: ParkColors.green,
                            weight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Txt(
                        widget.repository.lot.name,
                        size: 19,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 10),
                      Txt(
                        '${widget.repository.day}/10/2026 • ${clock(widget.repository.start)} - ${clock(widget.repository.end)}',
                        size: 12,
                        color: ParkColors.muted,
                      ),
                      const SizedBox(height: 22),
                      const Divider(color: ParkColors.line),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Txt('Vị trí ${widget.repository.slot}', size: 13),
                          Txt(
                            money(widget.repository.total),
                            size: 20,
                            color: ParkColors.blue,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              const Txt('Gần đây', size: 18, weight: FontWeight.w700),
              const SizedBox(height: 18),
              for (var i = 0; i < 2; i++) ...[
                ParkCard(
                  onTap:
                      () => mockMessage(
                        context,
                        'Lịch sử minh họa • chưa có dữ liệu backend',
                      ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: ParkColors.paleBlue,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: FigmaAsset('16:390', 'IconCar', size: 26),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              i == 0 ? 'Bãi xe Sông Hàn' : 'Bãi xe Vincom',
                              size: 15,
                              weight: FontWeight.w600,
                            ),
                            const SizedBox(height: 8),
                            Txt(
                              i == 0
                                  ? '18/10/2026 · 2 giờ'
                                  : '12/10/2026 · 3 giờ',
                              size: 12,
                              color: ParkColors.muted,
                            ),
                            const SizedBox(height: 8),
                            Txt(
                              i == 0 ? '24.000đ' : '60.000đ',
                              size: 14,
                              color: ParkColors.blue,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                      const FigmaAsset('16:390', 'IconChevronRight', size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
