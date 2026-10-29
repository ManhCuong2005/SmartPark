export 'map_screen.dart';
import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class ParkingArt extends StatelessWidget {
  const ParkingArt({
    super.key,
    required this.lot,
    this.screen = '13:139',
    this.car = 'IconCar1',
    this.size = 109,
  });
  final ParkingLot lot;
  final String screen, car;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: FittedBox(
      child: SizedBox(
        width: 109,
        height: 109,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Container(color: lot.tint),
              Positioned(
                left: 0,
                right: 0,
                top: 47,
                child: Container(height: 17, color: const Color(0xFFBACDE9)),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: 8 + i * 29.67,
                  top: 12,
                  child: Container(
                    width: 25,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 21,
                        height: 3,
                        color: const Color(0xFFA4B8D5),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 32.7,
                top: 41.42,
                child: FigmaAsset(screen, car, size: 36.4),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ParkingCard extends StatelessWidget {
  const ParkingCard({
    super.key,
    required this.lot,
    required this.onTap,
    this.compact = false,
  });
  final ParkingLot lot;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => ParkCard(
    padding: const EdgeInsets.all(12),
    onTap: onTap,
    child: Row(
      children: [
        ParkingArt(lot: lot, size: compact ? 102 : 109),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Txt(lot.name, size: 16, weight: FontWeight.w700),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!compact) ...[
                    const FigmaAsset('13:139', 'IconMapPin', size: 14),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Txt(
                      '${lot.area} · ${lot.distance}',
                      size: 12,
                      color: ParkColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const FigmaAsset('13:139', 'AvailabilityDot', size: 8),
                  const SizedBox(width: 6),
                  Txt(
                    '${lot.spaces} chỗ trống',
                    size: 12,
                    color: ParkColors.green,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerRight,
                child: Txt(
                  '${money(lot.hourlyRate)}/h',
                  size: 13,
                  color: ParkColors.blue,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final lots = [...widget.repository.lots];
    if (filter == 1) lots.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
    if (filter == 2) lots.removeWhere((l) => l.spaces == 0);
    return ParkPage(
      bottom: const ParkBottomNav(active: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 245,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  height: 231,
                  width: double.infinity,
                  color: ParkColors.navy,
                  child: Stack(
                    children: [
                      const Positioned(
                        right: -65,
                        top: -70,
                        child: FigmaAsset('13:139', 'GlowGradient', size: 193),
                      ),
                      const Positioned(
                        right: -67,
                        top: 140,
                        child: FigmaAsset('13:139', 'SoftAccent', size: 145),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 38, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt('Xin chào 👋', color: Color(0xFFBDCEE3)),
                            SizedBox(height: 16),
                            Txt(
                              'Bạn muốn đỗ xe\nở đâu hôm nay?',
                              size: 26,
                              height: 1.23,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 25,
                        top: 36,
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Center(
                              child: FigmaAsset('13:139', 'IconUser', size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: 182,
                  child: ParkCard(
                    padding: const EdgeInsets.all(18),
                    onTap: () => Navigator.pushNamed(context, '/parking/map'),
                    child: const Row(
                      children: [
                        FigmaAsset('13:139', 'IconSearch', size: 21),
                        SizedBox(width: 12),
                        Expanded(
                          child: Txt(
                            'Tìm địa điểm hoặc bãi đỗ...',
                            color: ParkColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 25, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Txt('Khám phá nhanh', size: 18, weight: FontWeight.w700),
                const SizedBox(height: 15),
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
                        child: Pill(
                          ['Tất cả', 'Giá tốt', 'Còn chỗ'][i],
                          selected: filter == i,
                          onTap: () => setState(() => filter = i),
                          icon: FigmaAsset(
                            '13:139',
                            ['IconNavigation', 'IconStar', 'IconCar'][i],
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 27),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Txt(
                      'Bãi đỗ đề xuất',
                      size: 19,
                      weight: FontWeight.w700,
                    ),
                    InkWell(
                      onTap:
                          () => Navigator.pushNamed(context, '/parking/list'),
                      child: const Txt(
                        'Xem tất cả',
                        size: 12,
                        color: ParkColors.blue,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final lot in lots.take(2)) ...[
                  ParkingCard(
                    lot: lot,
                    onTap: () {
                      widget.repository.update(
                        () => widget.repository.lot = lot,
                      );
                      Navigator.pushNamed(context, '/parking/detail');
                    },
                  ),
                  const SizedBox(height: 13),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  String query = '';
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    var lots =
        widget.repository.lots
            .where(
              (l) => ('${l.name} ${l.area}').toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
    if (filter == 1) lots.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
    if (filter == 2) lots = lots.where((l) => l.spaces > 0).toList();
    return ParkPage(
      bottom: const ParkBottomNav(active: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            'Tìm bãi đỗ',
            back: false,
            subtitle: 'Tìm chỗ phù hợp với vị trí và ngân sách',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên hoặc khu vực',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(16),
                      child: FigmaAsset('13:333', 'IconSearch', size: 22),
                    ),
                    suffixIcon: Padding(
                      padding: EdgeInsets.all(16),
                      child: FigmaAsset('13:333', 'IconSliders', size: 20),
                    ),
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
                          child: Pill(
                            ['Tất cả', 'Giá tốt', 'Còn chỗ'][i],
                            selected: filter == i,
                            onTap: () => setState(() => filter = i),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Txt(
                      '${lots.length} bãi đỗ phù hợp',
                      size: 13,
                      color: ParkColors.muted,
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pushReplacementNamed(
                            context,
                            '/parking/map',
                          ),
                      child: const Text('Bản đồ'),
                    ),
                  ],
                ),
                for (final lot in lots) ...[
                  ParkingCard(
                    lot: lot,
                    compact: true,
                    onTap: () {
                      widget.repository.update(
                        () => widget.repository.lot = lot,
                      );
                      Navigator.pushNamed(context, '/parking/detail');
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (lots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Txt(
                      'Không tìm thấy bãi đỗ. Hãy thử địa điểm khác.',
                      color: ParkColors.muted,
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

class ParkingDetailScreen extends StatefulWidget {
  const ParkingDetailScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<ParkingDetailScreen> createState() => _ParkingDetailScreenState();
}

class _ParkingDetailScreenState extends State<ParkingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final lot = widget.repository.lot;
    return ParkPage(
      color: Colors.white,
      bottom: BottomAction(
        child: ParkButton(
          'Chọn chỗ đỗ xe',
          onPressed: () => Navigator.pushNamed(context, '/booking/slots'),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 267,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: FigmaAsset(
                    '13:429',
                    'ParkingHeroArt',
                    width: 390,
                    height: 267,
                  ),
                ),
                Positioned(
                  left: 22,
                  top: 23,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                    icon: const FigmaAsset('13:429', 'IconArrowLeft', size: 20),
                  ),
                ),
                Positioned(
                  right: 22,
                  top: 23,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    tooltip: 'Lưu bãi đỗ',
                    onPressed:
                        () => runAction(
                          context,
                          () => widget.repository.toggleFavorite(lot.id),
                        ),
                    icon:
                        widget.repository.isFavorite(lot.id)
                            ? const Icon(Icons.favorite, color: ParkColors.blue)
                            : const FigmaAsset('13:429', 'IconHeart', size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Txt(lot.name, size: 24, weight: FontWeight.w700),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FigmaAsset('13:429', 'IconMapPin', size: 18),
                    SizedBox(width: 4),
                    Expanded(
                      child: Txt(lot.area, size: 13, color: ParkColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                Row(
                  children: [
                    const Pill(
                      'SmartPark',
                      color: Color(0xFFFFF6E7),
                      icon: FigmaAsset('13:429', 'IconStar', size: 16),
                    ),
                    const SizedBox(width: 11),
                    Pill(
                      'Còn ${lot.spaces} chỗ',
                      color: ParkColors.paleGreen,
                      icon: const FigmaAsset('13:429', 'Dot', size: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: ParkColors.line),
                const SizedBox(height: 14),
                const Txt(
                  'Thông tin bãi đỗ',
                  size: 17,
                  weight: FontWeight.w700,
                ),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        FigmaAsset(
                          '13:429',
                          ['IconClock', 'IconShield', 'IconCar'][i],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Txt(
                            [
                              'Đặt trước và xuất trình vé QR',
                              'Thanh toán tiền mặt khi xe ra',
                              'Ô tô: ${money(lot.hourlyRate)}/h · Xe máy: ${money(lot.motorcycleRate)}/h',
                            ][i],
                            color: ParkColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),
                const Divider(color: ParkColors.line),
                const SizedBox(height: 10),
                const Txt('Giá từ', size: 12, color: ParkColors.muted),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Txt(
                      money(lot.hourlyRate),
                      size: 24,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(width: 8),
                    const Txt('/ giờ', size: 13, color: ParkColors.muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
