import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 332,
          child: Stack(
            children: [
              Container(
                height: 265,
                width: double.infinity,
                color: ParkColors.navy,
                child: Stack(
                  children: [
                    const Positioned(
                      right: -97,
                      top: -69,
                      child: FigmaAsset('16:508', 'AccentGlow', size: 216),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 37, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Txt(
                            'Tài khoản',
                            size: 24,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: ParkColors.paleBlue,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Center(
                                  child: FigmaAsset(
                                    '16:508',
                                    'IconUser',
                                    size: 38,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Txt(
                                      repository.name,
                                      size: 20,
                                      color: Colors.white,
                                      weight: FontWeight.w700,
                                    ),
                                    const SizedBox(height: 12),
                                    Txt(
                                      repository.email,
                                      size: 12,
                                      color: const Color(0xFFB9CFE4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Txt(
                            'Thành viên SmartPark',
                            size: 13,
                            color: Color(0xFFB9CFE4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 23,
                right: 23,
                top: 236,
                child: ParkCard(
                  onTap: () => Navigator.pushNamed(context, '/tickets'),
                  child: const Row(
                    children: [
                      FigmaAsset('16:508', 'IconTicket', size: 36),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              '12 lượt đỗ xe',
                              size: 18,
                              weight: FontWeight.w700,
                            ),
                            SizedBox(height: 10),
                            Txt(
                              'Cảm ơn bạn đã đồng hành!',
                              size: 12,
                              color: ParkColors.muted,
                            ),
                          ],
                        ),
                      ),
                      FigmaAsset('16:508', 'IconChevronRight', size: 21),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Txt('Cài đặt tài khoản', size: 17, weight: FontWeight.w700),
              const SizedBox(height: 17),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ParkCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          [
                            '/profile/edit',
                            '/vehicles',
                            '/booking/payment',
                            '/notifications',
                            '/help',
                          ][i],
                        ),
                    child: Row(
                      children: [
                        FigmaAsset(
                          '16:508',
                          [
                            'IconUser1',
                            'IconCar',
                            'IconWallet',
                            'IconBell',
                            'IconHelp',
                          ][i],
                          size: 21,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Txt(
                            [
                              'Thông tin cá nhân',
                              'Phương tiện của tôi',
                              'Phương thức thanh toán',
                              'Thông báo',
                              'Trung tâm trợ giúp',
                            ][i],
                            size: 14,
                          ),
                        ),
                        const FigmaAsset(
                          '16:508',
                          'IconChevronRight',
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton(
                onPressed: () {
                  repository.resetSession();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (r) => false,
                  );
                },
                child: const Row(
                  children: [
                    FigmaAsset('16:508', 'IconLogout', size: 19),
                    SizedBox(width: 12),
                    Txt(
                      'Đăng xuất',
                      size: 13,
                      color: Color(0xFFE46060),
                      weight: FontWeight.w600,
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

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key, required this.repository});
  final MockParkRepository repository;
  Future<void> edit(BuildContext context, {Vehicle? vehicle}) async {
    final label = TextEditingController(text: vehicle?.label ?? ''),
        plate = TextEditingController(text: vehicle?.plate ?? '');
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(
              vehicle == null ? 'Thêm phương tiện' : 'Sửa phương tiện',
            ),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: 'Tên phương tiện',
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Nhập tên phương tiện'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: plate,
                    decoration: const InputDecoration(labelText: 'Biển số'),
                    validator:
                        (v) =>
                            v == null || v.trim().length < 5
                                ? 'Biển số không hợp lệ'
                                : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  repository.update(() {
                    if (vehicle == null) {
                      repository.vehicles.add(
                        Vehicle(label.text.trim(), plate.text.trim()),
                      );
                    } else {
                      vehicle.label = label.text.trim();
                      vehicle.plate = plate.text.trim();
                    }
                  });
                  Navigator.pop(c);
                },
                child: const Text('Lưu demo'),
              ),
            ],
          ),
    );
    // Controllers are owned by the dialog until its exit animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    label.dispose();
    plate.dispose();
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 3),
    child: Column(
      children: [
        const PageHeading(
          'Phương tiện của tôi',
          subtitle: 'Lưu phương tiện để đặt chỗ nhanh hơn',
          screen: '16:451',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              for (var i = 0; i < repository.vehicles.length; i++) ...[
                ParkCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: ParkColors.paleBlue,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Center(
                              child: FigmaAsset(
                                '16:451',
                                i == 0 ? 'IconCar' : 'IconCar1',
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 17),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Txt(
                                  repository.vehicles[i].label,
                                  size: 15,
                                  weight: FontWeight.w600,
                                ),
                                const SizedBox(height: 10),
                                Txt(
                                  repository.vehicles[i].plate,
                                  size: 19,
                                  weight: FontWeight.w700,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: ParkColors.line),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap:
                                  () => repository.update(() {
                                    for (final v in repository.vehicles) {
                                      v.isDefault = v == repository.vehicles[i];
                                    }
                                  }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Txt(
                                  repository.vehicles[i].isDefault
                                      ? '✓  Xe mặc định'
                                      : 'Đặt làm xe mặc định',
                                  size: 12,
                                  color:
                                      repository.vehicles[i].isDefault
                                          ? ParkColors.blue
                                          : ParkColors.muted,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa phương tiện',
                            onPressed:
                                () => edit(
                                  context,
                                  vehicle: repository.vehicles[i],
                                ),
                            icon: FigmaAsset(
                              '16:451',
                              i == 0 ? 'IconEdit' : 'IconEdit1',
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 20),
              ParkButton(
                'Thêm phương tiện mới',
                onPressed: () => edit(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 3),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Txt('Thông báo', size: 26, weight: FontWeight.w700),
              TextButton(
                onPressed:
                    () => repository.update(
                      () => repository.notificationsRead = true,
                    ),
                child: const Text('Đọc tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Txt('Hôm nay', size: 14, weight: FontWeight.w600),
          const SizedBox(height: 22),
          for (var i = 0; i < 4; i++) ...[
            ParkCard(
              onTap:
                  () => repository.update(
                    () => repository.notificationsRead = true,
                  ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          i == 1
                              ? const Color(0xFFFFF6E7)
                              : ParkColors.paleBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: FigmaAsset(
                        '16:590',
                        [
                          'IconTicket',
                          'IconClock',
                          'IconPercent',
                          'IconMessage',
                        ][i],
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Txt(
                          [
                            'Đặt chỗ thành công',
                            'Sắp hết giờ gửi xe',
                            'Ưu đãi cuối tuần',
                            'SmartPark xin chào!',
                          ][i],
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: 10),
                        Txt(
                          [
                            'Vị trí A07 tại Bãi xe Trung tâm đã được xác nhận.',
                            'Chỗ đỗ của bạn sẽ hết hạn trong 15 phút.',
                            'Giảm 20% cho lần đặt chỗ tiếp theo.',
                            'Khám phá các bãi đỗ gần bạn với giá minh bạch.',
                          ][i],
                          size: 12,
                          color: ParkColors.muted,
                          height: 1.45,
                        ),
                        const SizedBox(height: 16),
                        Txt(
                          ['14:30', '16:15', 'Hôm qua', '20/10'][i],
                          size: 11,
                          color: ParkColors.muted,
                        ),
                      ],
                    ),
                  ),
                  if (i == 0 && !repository.notificationsRead)
                    const FigmaAsset('16:590', 'Unread', size: 8),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
        ],
      ),
    ),
  );
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.repository});
  final MockParkRepository repository;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final name = TextEditingController(text: widget.repository.name),
      email = TextEditingController(text: widget.repository.email);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    child: Column(
      children: [
        const PageHeading('Thông tin cá nhân'),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Vui lòng nhập họ tên'
                              : null,
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator:
                      (v) =>
                          v == null ||
                                  !RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(v)
                              ? 'Email không hợp lệ'
                              : null,
                ),
                const SizedBox(height: 30),
                ParkButton(
                  'Lưu thông tin demo',
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    widget.repository.update(() {
                      widget.repository.name = name.text.trim();
                      widget.repository.email = email.text.trim();
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => const ParkPage(
    child: Column(
      children: [
        PageHeading('Trung tâm trợ giúp'),
        Padding(
          padding: EdgeInsets.all(24),
          child: Txt(
            'SmartPark đang ở chế độ demo. Các tính năng tài khoản, thanh toán, định vị và QR chưa kết nối dịch vụ thực tế. Dữ liệu chỉ được lưu trong phiên chạy hiện tại.',
          ),
        ),
      ],
    ),
  );
}
