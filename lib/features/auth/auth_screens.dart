import 'package:flutter/material.dart';
import '../../core/data/mock_repository.dart';
import '../../shared/widgets/park_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => ParkPage(
    color: ParkColors.navy,
    child: InkWell(
      onTap: () => Navigator.pushReplacementNamed(context, '/onboarding'),
      child: SizedBox(
        height: 810,
        child: Stack(
          children: [
            const Positioned(
              top: -77,
              right: -78,
              child: FigmaAsset('13:3', 'GlowA', size: 265),
            ),
            const Positioned(
              left: -128,
              bottom: -19,
              child: FigmaAsset('13:3', 'GlowB', size: 276),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(43, 217, 30, 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 6,
                    decoration: BoxDecoration(
                      color: ParkColors.teal,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 41),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: ParkColors.blue,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Stack(
                      children: [
                        Center(child: FigmaAsset('13:3', 'IconCar', size: 46)),
                        Positioned(
                          right: 14,
                          top: 12,
                          child: CircleAvatar(
                            radius: 5.5,
                            backgroundColor: ParkColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Txt(
                    'smartpark.',
                    size: 37,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: 17),
                  const Txt(
                    'Tìm chỗ đỗ nhanh hơn.\nTận hưởng hành trình nhiều hơn.',
                    size: 18,
                    color: Color(0xFFD8E7F8),
                    height: 1.5,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (final w in [55.0, 17.0, 17.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: w,
                            height: 5,
                            decoration: BoxDecoration(
                              color:
                                  w == 55
                                      ? ParkColors.teal
                                      : const Color(0xFF55708D),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 19),
                  const Txt(
                    'ỨNG DỤNG ĐỖ XE THÔNG MINH',
                    size: 10,
                    color: Color(0xFF9FB6D2),
                    weight: FontWeight.w600,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => ParkPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 46, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Txt(
            'Mọi hành trình,\nmột chỗ đỗ an tâm.',
            size: 31,
            weight: FontWeight.w700,
            height: 1.23,
          ),
          const SizedBox(height: 20),
          const Txt(
            'Tìm, đặt và quản lý chỗ đỗ xe chỉ trong vài chạm.',
            color: ParkColors.muted,
          ),
          const SizedBox(height: 52),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LayoutBuilder(
                builder:
                    (context, c) => Stack(
                      children: [
                        Container(color: const Color(0xFFE8F0FF)),
                        const Positioned(
                          right: -40,
                          top: -37,
                          child: FigmaAsset('13:25', 'Atmosphere', size: 173),
                        ),
                        Positioned(
                          left: 19,
                          right: 17,
                          top: 133,
                          child: Container(
                            height: 37,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Positioned(
                          left: c.maxWidth * .415,
                          top: 23,
                          child: Container(
                            width: 42,
                            height: 259,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        for (var i = 0; i < 3; i++) ...[
                          Positioned(
                            left: 25 + i * 99,
                            top: 21,
                            child: Container(
                              width: 55,
                              height: 63,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9D8F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 17 + i * 104,
                            top: 197,
                            child: Container(
                              width: 75,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6E2F4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                        const Positioned(
                          left: 23,
                          top: 92,
                          child: ParkCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                FigmaAsset('13:25', 'Dot', size: 9),
                                SizedBox(width: 8),
                                Txt(
                                  'Còn 24 chỗ',
                                  size: 12,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 194,
                          top: 95,
                          child: FigmaAsset(
                            '13:25',
                            'PrimaryPin',
                            width: 87,
                            height: 90,
                          ),
                        ),
                        const Positioned(
                          right: 23,
                          bottom: 36,
                          child: ParkCard(
                            padding: EdgeInsets.all(16),
                            child: Txt(
                              'Từ 12.000đ/giờ',
                              size: 12,
                              color: ParkColors.blue,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          const SizedBox(height: 37),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FigmaAsset('13:25', 'PageMarker1', width: 25, height: 6),
              SizedBox(width: 6),
              FigmaAsset('13:25', 'PageMarker2', size: 6),
            ],
          ),
          const SizedBox(height: 25),
          const Txt('Nhanh chóng', size: 22, weight: FontWeight.w700),
          const SizedBox(height: 5),
          const Txt(
            'Thông tin minh bạch, đặt chỗ trước\nđể không phải tìm kiếm vòng quanh.',
            color: ParkColors.muted,
            height: 1.5,
          ),
          const SizedBox(height: 47),
          ParkButton(
            'Bắt đầu trải nghiệm',
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.repository,
    this.register = false,
    this.staff = false,
  });
  final MockParkRepository repository;
  final bool register, staff;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController();
  bool obscure = true, agreed = true;
  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    String placeholder,
    String icon,
    TextEditingController controller, {
    bool password = false,
    TextInputType? type,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Txt(label, size: 13, weight: FontWeight.w600),
      const SizedBox(height: 9),
      TextFormField(
        controller: controller,
        obscureText: password && obscure,
        keyboardType: type,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
          if (type == TextInputType.emailAddress &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
            return 'Email không hợp lệ';
          }
          if (password && v.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
          if (type == TextInputType.phone && !RegExp(r'^0\d{9}$').hasMatch(v)) {
            return 'Số điện thoại gồm 10 chữ số';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: placeholder,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(16),
            child: FigmaAsset(
              widget.staff
                  ? '27:7'
                  : widget.register
                  ? '13:96'
                  : '13:61',
              icon,
              size: 20,
            ),
          ),
          suffixIcon:
              password && !widget.register && !widget.staff
                  ? IconButton(
                    tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: const FigmaAsset('13:61', 'IconEye', size: 18),
                  )
                  : null,
        ),
      ),
    ],
  );
  void submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (widget.register && !agreed) {
      mockMessage(context, 'Vui lòng đồng ý Điều khoản và Chính sách bảo mật');
      return;
    }
    widget.repository.update(() {
      widget.repository.signedIn = true;
      widget.repository.email = _email.text.trim();
      if (widget.register) widget.repository.name = _name.text.trim();
    });
    mockMessage(context, 'Đăng nhập demo • chưa kết nối Firebase');
    Navigator.pushNamedAndRemoveUntil(
      context,
      widget.staff ? '/staff/home' : '/home',
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg = widget.register, staff = widget.staff;
    return ParkPage(
      color: Colors.white,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (staff)
              Container(
                height: 281,
                width: double.infinity,
                color: ParkColors.navy,
                child: Stack(
                  children: [
                    const Positioned(
                      right: -51,
                      top: -51,
                      child: FigmaAsset('27:7', 'HeroGlow', size: 194),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 50, 26, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: ParkColors.blue,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Center(
                                  child: FigmaAsset(
                                    '27:7',
                                    'IconCar',
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Txt(
                                'SMARTPARK / STAFF',
                                size: 12,
                                color: Color(0xFFBDD0EB),
                                weight: FontWeight.w600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Txt(
                            'Quản lý ra vào\nnhanh và chính xác.',
                            size: 27,
                            color: Colors.white,
                            weight: FontWeight.w700,
                            height: 1.22,
                          ),
                          const SizedBox(height: 17),
                          const Txt(
                            'Dành riêng cho nhân viên bãi đỗ.',
                            size: 13,
                            color: Color(0xFFB3C6DE),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (!reg)
              Container(
                height: 188,
                color: ParkColors.paleBlue,
                child: const Stack(
                  children: [
                    Positioned(
                      right: -5,
                      top: 6,
                      child: FigmaAsset('13:61', 'DecorativeCircle', size: 144),
                    ),
                    Positioned(
                      right: 35,
                      top: 42,
                      child: FigmaAsset('13:61', 'IconCar', size: 78),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 23, 0, 0),
                child: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context),
                  icon: const FigmaAsset('13:96', 'IconArrowLeft', size: 20),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                reg
                    ? 20
                    : staff
                    ? 24
                    : 15,
                24,
                36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Txt(
                    staff
                        ? 'Đăng nhập ca làm việc'
                        : reg
                        ? 'Tạo tài khoản\nSmartPark'
                        : 'Chào mừng\ntrở lại 👋',
                    size: staff ? 23 : 31,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                  const SizedBox(height: 12),
                  Txt(
                    staff
                        ? 'Sử dụng tài khoản do quản lý cấp.'
                        : reg
                        ? 'Thêm một bước tới trải nghiệm đỗ xe dễ dàng.'
                        : 'Đăng nhập để tiếp tục với SmartPark.',
                    size: 13,
                    color: ParkColors.muted,
                  ),
                  SizedBox(
                    height:
                        reg
                            ? 34
                            : staff
                            ? 32
                            : 36,
                  ),
                  if (reg) ...[
                    field('Họ và tên', 'Nguyễn Văn A', 'IconUser', _name),
                    const SizedBox(height: 22),
                  ],
                  field(
                    staff
                        ? 'Email nhân viên'
                        : reg
                        ? 'Email'
                        : 'Địa chỉ email',
                    staff ? 'staff@smartpark.vn' : 'email@example.com',
                    'IconMail',
                    _email,
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 22),
                  if (reg) ...[
                    field(
                      'Số điện thoại',
                      '09xxxxxxxx',
                      'IconPhone',
                      _phone,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 22),
                  ],
                  field(
                    'Mật khẩu',
                    reg ? 'Ít nhất 8 ký tự' : '••••••••',
                    'IconLock',
                    _password,
                    password: true,
                  ),
                  if (!reg && !staff)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            () => mockMessage(
                              context,
                              'Khôi phục mật khẩu chưa kết nối backend.',
                            ),
                        child: const Txt(
                          'Quên mật khẩu?',
                          size: 13,
                          color: ParkColors.blue,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (reg) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: agreed,
                          onChanged: (v) => setState(() => agreed = v ?? false),
                        ),
                        const Expanded(
                          child: Txt(
                            'Tôi đồng ý với Điều khoản và Chính sách bảo mật',
                            size: 11,
                            color: ParkColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (staff) ...[
                    const SizedBox(height: 35),
                    const Pill(
                      '●  Chế độ bảo mật',
                      color: ParkColors.paleGreen,
                    ),
                  ],
                  SizedBox(
                    height:
                        reg
                            ? 16
                            : staff
                            ? 34
                            : 25,
                  ),
                  ParkButton(
                    reg ? 'Tạo tài khoản' : 'Đăng nhập',
                    onPressed: submit,
                  ),
                  if (!reg && !staff) ...[
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Txt(
                          'Chưa có tài khoản?',
                          size: 13,
                          color: ParkColors.muted,
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.pushNamed(context, '/register'),
                          child: const Txt(
                            'Đăng ký',
                            size: 13,
                            color: ParkColors.blue,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
