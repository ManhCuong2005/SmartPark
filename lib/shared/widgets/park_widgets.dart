import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/park_theme.dart';
export '../../core/theme/park_theme.dart';

class FigmaAsset extends StatelessWidget {
  const FigmaAsset(
    this.screen,
    this.name, {
    super.key,
    this.size = 22,
    this.width,
    this.height,
  });
  final String screen, name;
  final double size;
  final double? width, height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width ?? size,
    height: height ?? size,
    child: SvgPicture.asset(
      'assets/figma/${screen.replaceAll(':', '_')}_img$name.svg',
      fit: BoxFit.contain,
    ),
  );
}

class Txt extends StatelessWidget {
  const Txt(
    this.text, {
    super.key,
    this.size = 14,
    this.color = ParkColors.ink,
    this.weight = FontWeight.w400,
    this.height = 1.3,
    this.align,
  });
  final String text;
  final double size, height;
  final Color color;
  final FontWeight weight;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      color:
          Theme.of(context).brightness == Brightness.dark &&
                  color == ParkColors.ink
              ? Theme.of(context).colorScheme.onSurface
              : color,
      fontWeight: weight,
      height: height,
    ),
  );
}

class ParkButton extends StatelessWidget {
  const ParkButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor:
            secondary ? Theme.of(context).colorScheme.surface : ParkColors.blue,
        foregroundColor: secondary ? ParkColors.blue : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              secondary
                  ? const BorderSide(color: ParkColors.line)
                  : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class ParkCard extends StatelessWidget {
  const ParkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color:
        Theme.of(context).brightness == Brightness.dark && color == Colors.white
            ? Theme.of(context).colorScheme.surface
            : color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: ParkColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class ParkPage extends StatelessWidget {
  const ParkPage({
    super.key,
    required this.child,
    this.bottom,
    this.color = ParkColors.light,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final Widget? bottom;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ColoredBox(
          color:
              Theme.of(context).brightness == Brightness.dark &&
                      (color == ParkColors.light || color == Colors.white)
                  ? Theme.of(context).scaffoldBackgroundColor
                  : color,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(padding: padding, child: child),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.back = true,
    this.screen = '16:73',
  });
  final String title, screen;
  final String? subtitle;
  final bool back;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (back) ...[
              Semantics(
                label: 'Quay lại',
                button: true,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 16,
                      top: 5,
                      bottom: 5,
                    ),
                    child: FigmaAsset(
                      screen,
                      screen.startsWith('27:') ? 'IconBack' : 'IconArrowLeft',
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
            Expanded(child: Txt(title, size: 24, weight: FontWeight.w700)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 14),
          Txt(subtitle!, size: 13, color: ParkColors.muted),
        ],
      ],
    ),
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.last = false});
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Txt(label, size: 13, color: ParkColors.muted),
            ),
            Expanded(
              flex: 6,
              child: Txt(value, size: 13, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
      if (!last) const Divider(height: 1, color: ParkColors.line),
    ],
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.color,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? (selected ? ParkColors.blue : Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? ParkColors.blue : ParkColors.line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 7)],
              Txt(
                label,
                size: 12,
                color: selected ? Colors.white : ParkColors.ink,
                weight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ParkBottomNav extends StatelessWidget {
  const ParkBottomNav({super.key, required this.active, this.staff = false});
  final int active;
  final bool staff;
  @override
  Widget build(BuildContext context) {
    final labels =
        staff
            ? ['Trang chủ', 'Quét QR', 'Sơ đồ', 'Tài khoản']
            : ['Trang chủ', 'Tìm bãi', 'Vé xe', 'Cá nhân'];
    final icons =
        staff
            ? ['IconHome', 'IconScan', 'IconGrid', 'IconUser']
            : ['IconHome', 'IconMap', 'IconTicket', 'IconUser'];
    final routes =
        staff
            ? ['/staff/home', '/staff/scan', '/staff/slots', '/staff/account']
            : ['/home', '/parking/map', '/tickets', '/profile'];
    final navScreen =
        staff
            ? (active == 2 ? '27:191' : '27:42')
            : ['13:139', '13:236', '16:228', '16:508'][active];
    return Container(
      height: staff ? 81 : 86,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: ParkColors.line)),
      ),
      child: Row(
        children: List.generate(
          4,
          (i) => Expanded(
            child: InkWell(
              onTap:
                  () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    routes[i],
                    (r) => false,
                  ),
              child: Column(
                children: [
                  Container(
                    height: 3,
                    width: 32,
                    decoration: BoxDecoration(
                      color: active == i ? ParkColors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FigmaAsset(
                    navScreen,
                    navScreen == '13:139' && i == 3
                        ? 'IconUser1'
                        : navScreen == '16:508' && i == 2
                        ? 'IconTicket1'
                        : navScreen == '16:508' && i == 3
                        ? 'IconUser2'
                        : navScreen == '27:42' && (i == 1 || i == 2)
                        ? (i == 1 ? 'IconScan1' : 'IconGrid1')
                        : icons[i],
                    size: 23,
                  ),
                  const SizedBox(height: 9),
                  Txt(
                    labels[i],
                    size: 11,
                    weight: active == i ? FontWeight.w600 : FontWeight.w500,
                    color: active == i ? ParkColors.blue : ParkColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 20), child: child);
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Xác nhận SmartPark'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
    ) ??
    false;

Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showMessage(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString());
    return false;
  }
}

class AsyncParkButton extends StatefulWidget {
  const AsyncParkButton(
    this.label, {
    super.key,
    required this.action,
    this.onSuccess,
  });
  final String label;
  final Future<void> Function() action;
  final VoidCallback? onSuccess;
  @override
  State<AsyncParkButton> createState() => _AsyncParkButtonState();
}

class _AsyncParkButtonState extends State<AsyncParkButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ParkButton(
    busy ? 'Đang xử lý…' : widget.label,
    onPressed:
        busy
            ? null
            : () async {
              setState(() => busy = true);
              final success = await runAction(context, widget.action);
              if (!mounted) return;
              setState(() => busy = false);
              if (success) widget.onSuccess?.call();
            },
  );
}
