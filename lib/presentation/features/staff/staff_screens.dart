export 'operational_screens.dart';
import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 0, staff: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 351,
          child: Stack(
            children: [
              Container(
                height: 242,
                width: double.infinity,
                color: ParkColors.navy,
                child: Stack(
                  children: [
                    const Positioned(
                      right: -77,
                      top: -80,
                      child: FigmaAsset('27:42', 'BlueGlow', size: 208),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Txt(
                            'Ca trực hôm nay',
                            size: 13,
                            color: Color(0xFFB9CFE4),
                          ),
                          const SizedBox(height: 17),
                          Txt(
                            'Xin chào, ${repository.name}',
                            size: 26,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B3C55),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Row(
                                  children: [
                                    FigmaAsset('27:42', 'OnlineDot', size: 8),
                                    SizedBox(width: 8),
                                    Txt(
                                      repository.online
                                          ? 'Đã kết nối'
                                          : 'Đang ngoại tuyến',
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Pill('Nhân viên'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                top: 196,
                child: ParkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Txt(
                        'TỔNG QUAN HIỆN TẠI',
                        size: 12,
                        color: ParkColors.muted,
                        weight: FontWeight.w600,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Txt(
                                  '${repository.parked.length}',
                                  size: 34,
                                  weight: FontWeight.w700,
                                ),
                                const Txt(
                                  'Xe trong bãi',
                                  size: 12,
                                  color: ParkColors.muted,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 70,
                            color: ParkColors.line,
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Txt(
                                  '${repository.lots.where((l) => repository.snapshot.rows('memberships').any((m) => m['lot_id'] == l.id && m['user_id'] == repository.userId && m['active'] == true) || repository.snapshot.rows('lots').any((r) => r['id'] == l.id && r['owner_id'] == repository.userId)).fold<int>(0, (n, l) => n + l.spaces)}',
                                  size: 34,
                                  weight: FontWeight.w700,
                                  color: ParkColors.teal,
                                ),
                                const Txt(
                                  'Vị trí còn trống',
                                  size: 12,
                                  color: ParkColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 27, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Txt('Thao tác nhanh', size: 19, weight: FontWeight.w700),
              const SizedBox(height: 19),
              for (var i = 0; i < 2; i++) ...[
                ParkCard(
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        i == 0 ? '/staff/scan' : '/staff/slots',
                      ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 63,
                        height: 63,
                        decoration: BoxDecoration(
                          color:
                              i == 0
                                  ? ParkColors.paleBlue
                                  : ParkColors.paleGreen,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: FigmaAsset(
                            '27:42',
                            i == 0 ? 'IconScan' : 'IconGrid',
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 17),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              i == 0 ? 'Quét mã QR' : 'Sơ đồ vị trí',
                              size: 18,
                              weight: FontWeight.w700,
                            ),
                            const SizedBox(height: 8),
                            Txt(
                              i == 0
                                  ? 'Xác nhận xe vào / ra'
                                  : 'Cập nhật tình trạng ô đỗ',
                              size: 12,
                              color: ParkColors.muted,
                            ),
                          ],
                        ),
                      ),
                      const FigmaAsset('27:42', 'IconChevron', size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 9),
              ParkCard(
                color: Color(0xFFFFF6E7),
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    FigmaAsset('27:42', 'IconAlert', size: 21),
                    SizedBox(width: 9),
                    Expanded(
                      child: Txt(
                        '${repository.operations.length} thao tác đang chờ đồng bộ. Xem mục Tài khoản → Đồng bộ dữ liệu.',
                        size: 12,
                        color: ParkColors.blue,
                      ),
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
