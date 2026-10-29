export 'live_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.repository});
  final ParkController repository;
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
                  child: Row(
                    children: [
                      FigmaAsset('16:508', 'IconTicket', size: 36),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Txt(
                              '${repository.bookings.where((b) => b['customer_id'] == repository.userId).length} lượt đỗ xe',
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
                            '/sync',
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
                              'Đồng bộ dữ liệu',
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
              Consumer(
                builder:
                    (context, ref, _) => SwitchListTile(
                      title: const Text('Giao diện tối'),
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged:
                          (dark) =>
                              ref.read(themeModeProvider.notifier).state =
                                  dark ? ThemeMode.dark : ThemeMode.light,
                    ),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await runAction(context, repository.signOut);
                  if (!ok || !context.mounted) return;
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
