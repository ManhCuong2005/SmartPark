import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/providers.dart';
import '../../../domain/parking_rules.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../booking/booking_screens.dart';

class StaffScannerScreen extends StatefulWidget {
  const StaffScannerScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends State<StaffScannerScreen>
    with WidgetsBindingObserver {
  final scanner = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool processing = false;
  bool get supported =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!supported) return;
    if (state == AppLifecycleState.resumed && !processing) {
      scanner.start();
    } else if (state == AppLifecycleState.inactive) {
      scanner.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanner.dispose();
    super.dispose();
  }

  Future<void> open(String raw) async {
    if (processing) return;
    setState(() => processing = true);
    if (supported) await scanner.stop();
    if (!mounted) return;
    final ok = await runAction(
      context,
      () => widget.repository.openTicket(raw),
    );
    if (ok && mounted) await Navigator.pushNamed(context, '/staff/confirm');
    if (!mounted) return;
    setState(() => processing = false);
    if (supported) await scanner.start();
  }

  Future<void> manual() async {
    final text = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Nhập nội dung QR'),
            content: TextField(
              controller: text,
              decoration: const InputDecoration(labelText: 'smartpark:v1:…'),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, text.text),
                child: const Text('Kiểm tra vé'),
              ),
            ],
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    if (result != null) await open(result);
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    color: ParkColors.navy,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Txt(
                'Quét mã QR',
                size: 26,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
              Txt('Đưa vé điện tử vào khung quét', color: Colors.white),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 330,
                  child:
                      supported
                          ? MobileScanner(
                            controller: scanner,
                            onDetect: (capture) {
                              final value =
                                  capture.barcodes.firstOrNull?.rawValue;
                              if (value != null) open(value);
                            },
                          )
                          : const Center(
                            child: Text(
                              'Camera quét QR hỗ trợ Android/iOS và trình duyệt.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 24),
              ParkButton(
                'Nhập nội dung QR thủ công',
                onPressed: processing ? null : manual,
              ),
              if (supported)
                TextButton(
                  onPressed: () => scanner.toggleTorch(),
                  child: const Text('Bật / tắt đèn'),
                ),
              const Text(
                'Offline chỉ xử lý vé đã có trong cache của nhân viên. Thao tác sẽ chờ máy chủ kiểm tra khi kết nối lại.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StaffConfirmationScreen extends StatefulWidget {
  const StaffConfirmationScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<StaffConfirmationScreen> createState() =>
      _StaffConfirmationScreenState();
}

class _StaffConfirmationScreenState extends State<StaffConfirmationScreen> {
  final plate = TextEditingController();
  bool recognizing = false;
  List<String> candidates = [];
  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  Future<void> recognize() async {
    setState(() => recognizing = true);
    await runAction(context, () async {
      final result = await widget.repository.recognizePlate();
      if (result == null || !mounted) return;
      setState(() {
        candidates = result;
        if (result.length == 1) plate.text = result.first;
      });
      if (result.isEmpty && mounted) {
        showMessage(
          context,
          'Chưa nhận diện được biển số. Chụp rõ hơn hoặc nhập thủ công.',
        );
      }
    });
    if (mounted) setState(() => recognizing = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository, b = repo.ticket;
    if (b == null) return const ParkPage(child: PageHeading('Chưa chọn vé'));
    final entering = b['status'] == 'confirmed';
    final pending = repo.operations.any(
      (o) => o.payload['booking_id'] == b['id'],
    );
    final preview =
        b['checked_in_at'] == null
            ? null
            : calculateFee(
              DateTime.parse(b['checked_in_at'] as String),
              DateTime.now(),
              b['hourly_rate'] as int,
              b['free_minutes'] as int,
            );
    return ParkPage(
      child: Column(
        children: [
          const PageHeading(
            'Xác nhận vé',
            subtitle: 'Kiểm tra QR và biển số thực tế',
            screen: '27:144',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                ParkCard(
                  child: Column(
                    children: [
                      DetailRow('Biển số trên vé', b['plate'] as String),
                      DetailRow(
                        'Trạng thái',
                        statusLabel(b['status'] as String),
                      ),
                      if (preview != null && b['status'] == 'parked')
                        DetailRow('Phí tạm tính', money(preview)),
                      if (b['status'] == 'completed' &&
                          b['local_pending'] != true)
                        DetailRow('Đã thu', money(b['amount'] as int)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ParkButton(
                  recognizing ? 'Đang nhận diện…' : 'Chụp biển số · AI OCR',
                  onPressed: recognizing ? null : recognize,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children:
                      candidates
                          .map(
                            (p) => ActionChip(
                              label: Text(p),
                              onPressed: () => setState(() => plate.text = p),
                            ),
                          )
                          .toList(),
                ),
                TextField(
                  controller: plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Biển số thực tế · có thể sửa',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'OCR có thể sai. Đối chiếu biển số và sửa kết quả trước khi xác nhận. Phí chính thức do máy chủ tính.',
                ),
                const SizedBox(height: 20),
                if (pending)
                  const Text(
                    'Vé có thao tác chờ. Trạng thái trên thiết bị chưa được máy chủ xác nhận. Xem hàng đợi để biết kết quả hoặc xung đột.',
                  ),
                if (['confirmed', 'parked'].contains(b['status']))
                  AsyncParkButton(
                    entering
                        ? 'Xác nhận xe vào'
                        : 'Xác nhận thu tiền mặt và xe ra',
                    action: () async {
                      if (!await confirmAction(
                        context,
                        entering
                            ? 'Xác nhận biển số thực tế và cho xe vào bãi?'
                            : 'Xác nhận đã thu tiền mặt theo thời gian gửi xe và cho xe ra?',
                      )) {
                        return;
                      }
                      await repo.staffAction(entering, plate.text);
                      if (context.mounted) {
                        showMessage(
                          context,
                          repo.operations.any(
                                (o) => o.payload['booking_id'] == b['id'],
                              )
                              ? 'Thao tác đang chờ máy chủ xác nhận. Kiểm tra hàng đợi.'
                              : 'Máy chủ đã xác nhận.',
                        );
                      }
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/sync'),
                  child: const Text('Xem hàng đợi đồng bộ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StaffSlotsScreen extends StatelessWidget {
  const StaffSlotsScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) {
    final assigned =
        repository.lots
            .where(
              (l) =>
                  repository.snapshot
                      .rows('memberships')
                      .any(
                        (m) =>
                            m['lot_id'] == l.id &&
                            m['user_id'] == repository.userId &&
                            m['active'] == true,
                      ) ||
                  repository.snapshot
                      .rows('lots')
                      .any(
                        (r) =>
                            r['id'] == l.id &&
                            r['owner_id'] == repository.userId,
                      ),
            )
            .toList();
    return ParkPage(
      bottom: const ParkBottomNav(active: 2, staff: true),
      child: Column(
        children: [
          const PageHeading(
            'Sơ đồ vị trí',
            subtitle: 'Tình trạng bãi và danh sách xe đang gửi',
            screen: '27:191',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                DropdownButton<String>(
                  isExpanded: true,
                  value:
                      assigned.any((l) => l.id == repository.lot.id)
                          ? repository.lot.id
                          : null,
                  hint: const Text('Chọn bãi được phân công'),
                  items:
                      assigned
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (id) => repository.update(
                        () =>
                            repository.lot = assigned.firstWhere(
                              (l) => l.id == id,
                            ),
                      ),
                ),
                const SizedBox(height: 20),
                if (assigned.any((l) => l.id == repository.lot.id))
                  SlotGrid(
                    selected: '',
                    occupied: repository.occupied,
                    codes:
                        repository.slots
                            .map((s) => s['code'] as String)
                            .toList(),
                    staff: true,
                    onSelect: (_) {
                      showMessage(
                        context,
                        'Thay đổi trạng thái bằng vé QR và check-in/check-out.',
                      );
                    },
                  ),
                const SizedBox(height: 20),
                for (final b in repository.parked.where(
                  (b) => b['lot_id'] == repository.lot.id,
                ))
                  ParkCard(
                    child: ListTile(
                      title: Text(b['plate'] as String),
                      subtitle: Text(
                        'Vào lúc ${DateTime.parse(b['checked_in_at'] as String).toLocal()}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (await runAction(
                              context,
                              () => repository.openTicket(
                                TicketIdentity(
                                  b['id'] as String,
                                  b['qr_token'] as String,
                                ).encoded,
                              ),
                            ) &&
                            context.mounted) {
                          Navigator.pushNamed(context, '/staff/confirm');
                        }
                      },
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

class StaffAccountScreen extends ConsumerWidget {
  const StaffAccountScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ParkPage(
    bottom: const ParkBottomNav(active: 3, staff: true),
    child: Column(
      children: [
        const PageHeading('Tài khoản nhân viên'),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              ParkCard(
                child: ListTile(
                  title: Text(repository.name),
                  subtitle: Text(repository.email),
                ),
              ),
              ListTile(
                title: const Text('Đồng bộ dữ liệu'),
                subtitle: Text('${repository.operations.length} thao tác chờ'),
                trailing: const Icon(Icons.sync),
                onTap: () => Navigator.pushNamed(context, '/sync'),
              ),
              SwitchListTile(
                title: const Text('Giao diện tối'),
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged:
                    (dark) =>
                        ref.read(themeModeProvider.notifier).state =
                            dark ? ThemeMode.dark : ThemeMode.light,
              ),
              AsyncParkButton(
                'Đăng xuất',
                action: repository.signOut,
                onSuccess:
                    () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/staff/login',
                      (r) => false,
                    ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
