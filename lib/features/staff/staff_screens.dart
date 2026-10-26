import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';
import '../booking/booking_screens.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key, required this.repository});
  final MockParkRepository repository;
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
                          const Txt(
                            'Xin chào, Minh Anh',
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
                                child: const Row(
                                  children: [
                                    FigmaAsset('27:42', 'OnlineDot', size: 8),
                                    SizedBox(width: 8),
                                    Txt(
                                      'Đang trực · 07:00–15:00',
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Pill('Ca sáng'),
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
                                  '${repository.checkedIn ? 29 : 28}',
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
                                  '${repository.checkedIn ? 11 : 12}',
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
              const ParkCard(
                color: Color(0xFFFFF6E7),
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    FigmaAsset('27:42', 'IconAlert', size: 21),
                    SizedBox(width: 9),
                    Expanded(
                      child: Txt(
                        '02 lượt đặt chỗ sắp đến trong 15 phút.',
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

class StaffScannerScreen extends StatefulWidget {
  const StaffScannerScreen({super.key});
  @override
  State<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends State<StaffScannerScreen> {
  bool flash = false;
  Future<void> manual() async {
    final controller = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setDialog) => AlertDialog(
                  title: const Text('Nhập mã vé demo'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dùng mã SP-1022-007 để mô phỏng. Không quét camera hoặc xác thực QR thật.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Mã vé',
                          errorText: error,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (controller.text.trim().toUpperCase() !=
                            'SP-1022-007') {
                          setDialog(() => error = 'Mã vé demo không hợp lệ');
                          return;
                        }
                        Navigator.pop(c);
                        Navigator.pushNamed(context, '/staff/confirm');
                      },
                      child: const Text('Kiểm tra demo'),
                    ),
                  ],
                ),
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    color: ParkColors.navy,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed:
                        () => Navigator.pushReplacementNamed(
                          context,
                          '/staff/home',
                        ),
                    icon: const FigmaAsset('27:110', 'IconBack', size: 22),
                  ),
                  const SizedBox(width: 5),
                  const Txt(
                    'Quét mã QR',
                    size: 23,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Txt(
                'Đưa mã QR của khách vào khung quét',
                size: 13,
                color: Color(0xFFB9CFE4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 35),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 430,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1729),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: -55,
                  top: -70,
                  child: FigmaAsset('27:110', 'LensReflection', size: 199),
                ),
                Center(
                  child: SizedBox(
                    width: 254,
                    height: 254,
                    child: Stack(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Positioned(
                            left: i.isEven ? 7 : null,
                            right: i.isOdd ? 7 : null,
                            top: i < 2 ? 8 : null,
                            bottom: i >= 2 ? 8 : null,
                            child: Container(
                              width: 53,
                              height: 53,
                              decoration: BoxDecoration(
                                border: Border(
                                  top:
                                      i < 2
                                          ? const BorderSide(
                                            color: ParkColors.teal,
                                            width: 5,
                                          )
                                          : BorderSide.none,
                                  bottom:
                                      i >= 2
                                          ? const BorderSide(
                                            color: ParkColors.teal,
                                            width: 5,
                                          )
                                          : BorderSide.none,
                                  left:
                                      i.isEven
                                          ? const BorderSide(
                                            color: ParkColors.teal,
                                            width: 5,
                                          )
                                          : BorderSide.none,
                                  right:
                                      i.isOdd
                                          ? const BorderSide(
                                            color: ParkColors.teal,
                                            width: 5,
                                          )
                                          : BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        const Center(
                          child: FigmaAsset('27:110', 'IconScan', size: 64),
                        ),
                        Positioned(
                          left: 28,
                          right: 28,
                          top: 164,
                          child: Container(height: 3, color: ParkColors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 30,
                  right: 30,
                  bottom: 28,
                  child: Txt(
                    'Camera demo · chưa kết nối quét QR',
                    size: 12,
                    color: Color(0xFFB9CFE4),
                    align: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        IconButton.filled(
          tooltip: 'Đèn flash mô phỏng',
          style: IconButton.styleFrom(
            backgroundColor: flash ? ParkColors.blue : const Color(0xFF203A58),
            minimumSize: const Size(72, 56),
          ),
          onPressed: () => setState(() => flash = !flash),
          icon: const FigmaAsset('27:110', 'IconFlash', size: 24),
        ),
        const SizedBox(height: 27),
        const Txt('Quét không thành công?', size: 13, color: Color(0xFFB9CFE4)),
        TextButton(
          onPressed: manual,
          child: const Txt(
            'Nhập mã vé thủ công',
            size: 14,
            color: ParkColors.teal,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class StaffConfirmationScreen extends StatelessWidget {
  const StaffConfirmationScreen({super.key, required this.repository});
  final MockParkRepository repository;
  Future<void> confirm(BuildContext context, bool entering) async {
    if (!await confirmMock(
          context,
          '${entering ? 'Cho xe vào' : 'Cho xe ra'} chỉ cập nhật dữ liệu trong phiên demo. Chưa xác thực vé hoặc điều khiển cổng thực tế.',
        ) ||
        !context.mounted) {
      return;
    }
    repository.update(() {
      repository.checkedIn = entering;
      if (entering) {
        repository.staffOccupied.add('A07');
      } else {
        repository.staffOccupied.remove('A07');
      }
    });
    mockMessage(context, 'Đã mô phỏng xe ${entering ? 'vào' : 'ra'} bãi');
    Navigator.pushNamedAndRemoveUntil(context, '/staff/home', (r) => false);
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    child: Column(
      children: [
        const PageHeading('Xác nhận vé', screen: '27:144'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const ParkCard(
                color: ParkColors.paleGreen,
                child: Row(
                  children: [
                    FigmaAsset('27:144', 'IconCheck', size: 30),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Txt(
                            'Mã vé hợp lệ',
                            size: 18,
                            weight: FontWeight.w700,
                            color: ParkColors.green,
                          ),
                          SizedBox(height: 8),
                          Txt(
                            'Trạng thái minh họa • chưa xác thực',
                            size: 12,
                            color: ParkColors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const ParkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Txt(
                      'THÔNG TIN PHƯƠNG TIỆN',
                      size: 12,
                      color: ParkColors.muted,
                      weight: FontWeight.w600,
                    ),
                    SizedBox(height: 25),
                    Row(
                      children: [
                        FigmaAsset('27:144', 'IconCar', size: 31),
                        SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              '43A - 123.45',
                              size: 21,
                              weight: FontWeight.w700,
                            ),
                            SizedBox(height: 8),
                            Txt(
                              'Ô tô  •  Xe cá nhân',
                              size: 13,
                              color: ParkColors.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    Divider(color: ParkColors.line),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Txt('Vé #SP-1022-007', size: 13)),
                        Txt('Đã đặt trước', size: 11, color: ParkColors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const ParkCard(
                child: Column(
                  children: [
                    DetailRow('Bãi đỗ', 'Bãi xe Trung tâm'),
                    DetailRow('Vị trí', 'A07 · Tầng 1'),
                    DetailRow('Thời gian', '14:30 – 16:30', last: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const ParkCard(
                color: ParkColors.paleBlue,
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    FigmaAsset('27:144', 'IconShield', size: 21),
                    SizedBox(width: 10),
                    Expanded(
                      child: Txt(
                        'Kiểm tra biển số trước khi cho xe vào.',
                        size: 12,
                        color: ParkColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ParkButton(
                'Xác nhận xe vào bãi',
                onPressed: () => confirm(context, true),
              ),
              const SizedBox(height: 12),
              ParkButton(
                'Xác nhận xe ra',
                secondary: true,
                onPressed: () => confirm(context, false),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    ),
  );
}

class StaffSlotsScreen extends StatelessWidget {
  const StaffSlotsScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 2, staff: true),
    child: Column(
      children: [
        const PageHeading(
          'Sơ đồ bãi đỗ',
          subtitle: 'Bãi xe Trung tâm · Tầng 1',
          back: false,
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
                      'ĐÃ SỬ DỤNG',
                      size: 11,
                      color: ParkColors.muted,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 5),
                    Txt(
                      '${21 + repository.staffOccupied.length} / 40 chỗ',
                      size: 23,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (21 + repository.staffOccupied.length) / 40,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 7,
                      backgroundColor: ParkColors.line,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 21),
              const ParkCard(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 20),
                child: SlotLegend(staff: true),
              ),
              const SizedBox(height: 21),
              SlotGrid(
                staff: true,
                selected: repository.staffSlot,
                occupied: repository.staffOccupied,
                onSelect:
                    (s) => repository.update(() => repository.staffSlot = s),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Txt(
                    'Vị trí đang chọn',
                    size: 12,
                    color: ParkColors.muted,
                  ),
                  Txt(
                    repository.staffSlot,
                    size: 19,
                    color: ParkColors.blue,
                    weight: FontWeight.w700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ParkButton(
                'Cập nhật trạng thái ô ${repository.staffSlot}',
                onPressed: () async {
                  if (!await confirmMock(
                        context,
                        'Đổi ô ${repository.staffSlot} thành ${repository.staffOccupied.contains(repository.staffSlot) ? 'còn trống' : 'đang dùng'} trong dữ liệu demo.',
                      ) ||
                      !context.mounted) {
                    return;
                  }
                  repository.update(() {
                    if (!repository.staffOccupied.remove(
                      repository.staffSlot,
                    )) {
                      repository.staffOccupied.add(repository.staffSlot);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    ),
  );
}

class StaffAccountScreen extends StatelessWidget {
  const StaffAccountScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 3, staff: true),
    child: Column(
      children: [
        const PageHeading('Tài khoản nhân viên', back: false),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const ParkCard(
                child: Column(
                  children: [
                    Txt('Minh Anh', size: 24, weight: FontWeight.w700),
                    SizedBox(height: 12),
                    Txt('Ca sáng · 07:00–15:00', color: ParkColors.muted),
                    SizedBox(height: 12),
                    Txt('Môi trường mô phỏng', color: ParkColors.blue),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ParkButton(
                'Đăng xuất',
                onPressed: () {
                  repository.resetSession();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/staff/login',
                    (r) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
