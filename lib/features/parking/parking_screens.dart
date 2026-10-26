import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';

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
  final MockParkRepository repository;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final lots = [...MockParkRepository.lots];
    if (filter == 1) lots.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
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
                            Txt('Chào buổi chiều 👋', color: Color(0xFFBDCEE3)),
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
                          ['Gần tôi', 'Giá tốt', 'Còn chỗ'][i],
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
  final MockParkRepository repository;
  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  String query = '';
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    var lots =
        MockParkRepository.lots
            .where(
              (l) => ('${l.name} ${l.area}').toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
    if (filter == 1) lots.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
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
                            ['Gần tôi', 'Giá tốt', 'Còn chỗ'][i],
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

/// Native geometric map from Figma, intentionally an offline demonstration.
class CityMap extends StatelessWidget {
  const CityMap({super.key, required this.onSelect});
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, c) => Stack(
          children: [
            Container(color: const Color(0xFFE5EEE9)),
            for (var row = 0; row < 4; row++)
              for (var col = 0; col < 3; col++)
                Positioned(
                  left: (col * 135 + 10) * c.maxWidth / 390,
                  top: row * 170 + 25,
                  child: Container(
                    width: 94 * c.maxWidth / 390,
                    height: 96,
                    decoration: BoxDecoration(
                      color:
                          (row + col).isEven
                              ? const Color(0xFFD5E2E0)
                              : const Color(0xFFD3DED8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
            for (final y in [140.0, 305.0, 485.0])
              Positioned(
                left: 0,
                right: 0,
                top: y,
                child: Container(height: 23, color: Colors.white),
              ),
            for (final x in [116.0, 261.0])
              Positioned(
                left: x * c.maxWidth / 390,
                top: 0,
                bottom: 0,
                child: Container(width: 25, color: Colors.white),
              ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 54 * c.maxWidth / 390,
                color: const Color(0xFFC7E2EE),
              ),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: [72.0, 261.0, 189.0][i] * c.maxWidth / 390,
                top: [230.0, 119.0, 409.0][i],
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 59,
                    height: 44,
                    decoration: BoxDecoration(
                      color: i == 0 ? ParkColors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FigmaAsset(
                          '13:236',
                          i == 0 ? 'IconCar' : 'IconCar1',
                          size: 22,
                        ),
                        const SizedBox(width: 3),
                        Txt(
                          '${MockParkRepository.lots[i].spaces}',
                          size: 12,
                          weight: FontWeight.w700,
                          color: i == 0 ? Colors.white : ParkColors.ink,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
  );
}

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 1),
    child: SizedBox(
      height: 724,
      child: Stack(
        children: [
          Positioned.fill(
            child: CityMap(onSelect: (i) => setState(() => selected = i)),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 28,
            child: ParkCard(
              padding: const EdgeInsets.all(16),
              onTap: () => Navigator.pushNamed(context, '/parking/list'),
              child: const Row(
                children: [
                  FigmaAsset('13:236', 'IconSearch', size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Txt('Đà Nẵng, Việt Nam', weight: FontWeight.w500),
                  ),
                  FigmaAsset('13:236', 'IconFilter', size: 20),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 24,
            top: 100,
            child: ParkCard(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  FigmaAsset('13:236', 'Dot', size: 8),
                  SizedBox(width: 8),
                  Txt('Bãi đỗ quanh bạn', size: 12),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 191,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() => selected = 0);
                mockMessage(context, 'Vị trí Đà Nẵng là dữ liệu mock.');
              },
              child: const Icon(Icons.my_location, color: ParkColors.blue),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 28,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Pill(
                    'Danh sách',
                    onTap:
                        () => Navigator.pushReplacementNamed(
                          context,
                          '/parking/list',
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                ParkingCard(
                  lot: MockParkRepository.lots[selected],
                  onTap: () {
                    widget.repository.update(
                      () =>
                          widget.repository.lot =
                              MockParkRepository.lots[selected],
                    );
                    Navigator.pushNamed(context, '/parking/detail');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ParkingDetailScreen extends StatefulWidget {
  const ParkingDetailScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  State<ParkingDetailScreen> createState() => _ParkingDetailScreenState();
}

class _ParkingDetailScreenState extends State<ParkingDetailScreen> {
  bool saved = false;
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
                    onPressed: () => setState(() => saved = !saved),
                    icon:
                        saved
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
                const Row(
                  children: [
                    FigmaAsset('13:429', 'IconMapPin', size: 18),
                    SizedBox(width: 4),
                    Expanded(
                      child: Txt(
                        '15 Đường 2/9, Hải Châu, Đà Nẵng',
                        size: 13,
                        color: ParkColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                Row(
                  children: [
                    const Pill(
                      '4.8',
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
                        Txt(
                          [
                            'Mở cửa 24/7',
                            'Camera và bảo vệ 24/7',
                            'Hỗ trợ ô tô và xe máy',
                          ][i],
                          color: ParkColors.muted,
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
