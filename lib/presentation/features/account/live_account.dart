import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key, required this.repository});
  final ParkController repository;
  Future<void> edit(BuildContext context, {Vehicle? old}) async {
    final label = TextEditingController(text: old?.label ?? ''),
        plate = TextEditingController(text: old?.plate ?? '');
    String kind = old?.kind ?? 'car';
    bool isDefault = old?.isDefault ?? repository.vehicles.isEmpty;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder:
          (dialog) => StatefulBuilder(
            builder:
                (dialog, set) => AlertDialog(
                  title: Text(
                    old == null ? 'Thêm phương tiện' : 'Sửa phương tiện',
                  ),
                  content: SingleChildScrollView(
                    child: Form(
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
                            decoration: const InputDecoration(
                              labelText: 'Biển số',
                            ),
                          ),
                          DropdownButton<String>(
                            value: kind,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'car',
                                child: Text('Ô tô'),
                              ),
                              DropdownMenuItem(
                                value: 'motorcycle',
                                child: Text('Xe máy'),
                              ),
                            ],
                            onChanged: (v) => set(() => kind = v!),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Phương tiện mặc định'),
                            value: isDefault,
                            onChanged: (v) => set(() => isDefault = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await runAction(
                          context,
                          () => repository.saveVehicle(
                            old: old,
                            label: label.text,
                            plate: plate.text,
                            kind: kind,
                            isDefault: isDefault,
                          ),
                          success:
                              'Đã lưu yêu cầu. Kiểm tra hàng đợi nếu chưa có mạng.',
                        );
                        if (ok && dialog.mounted) Navigator.pop(dialog);
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
          ),
    );
    // Wait for the dialog's exit animation before releasing its controllers.
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
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              if (repository.vehicles.isEmpty)
                const Text('Chưa có phương tiện. Thêm xe trước khi đặt chỗ.'),
              for (final v in repository.vehicles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ParkCard(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            v.kind == 'car'
                                ? Icons.directions_car
                                : Icons.two_wheeler,
                          ),
                          title: Text(v.label),
                          subtitle: Text(v.plate),
                          trailing:
                              v.isDefault
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: ParkColors.blue,
                                  )
                                  : null,
                        ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => edit(context, old: v),
                              child: const Text('Sửa'),
                            ),
                            TextButton(
                              onPressed:
                                  () => runAction(
                                    context,
                                    () => repository.saveVehicle(
                                      old: v,
                                      label: v.label,
                                      plate: v.plate,
                                      kind: v.kind,
                                      isDefault: true,
                                    ),
                                  ),
                              child: const Text('Đặt mặc định'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (await confirmAction(
                                      context,
                                      'Xóa phương tiện này?',
                                    ) &&
                                    context.mounted) {
                                  await runAction(
                                    context,
                                    () => repository.saveVehicle(
                                      old: v,
                                      label: v.label,
                                      plate: v.plate,
                                      kind: v.kind,
                                      deleted: true,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ParkButton('Thêm phương tiện', onPressed: () => edit(context)),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/sync'),
                child: Text('Thao tác chờ: ${repository.operations.length}'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    bottom: const ParkBottomNav(active: 3),
    child: Column(
      children: [
        const PageHeading('Thông báo'),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              AsyncParkButton(
                'Đọc tất cả',
                action: repository.markNotificationsRead,
              ),
              if (repository.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có thông báo.'),
                ),
              for (final n in repository.notifications)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ParkCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        n['read'] == true
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                      ),
                      title: Text(n['title'] as String),
                      subtitle: Text(
                        '${n['body']}\n${DateTime.parse(n['created_at'] as String).toLocal()}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final name = TextEditingController(text: widget.repository.name),
      phone = TextEditingController(
        text: widget.repository.profile['phone'] as String? ?? '',
      );
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ParkPage(
    child: Column(
      children: [
        const PageHeading('Thông tin cá nhân'),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Họ tên'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              const SizedBox(height: 20),
              Text(widget.repository.email),
              const SizedBox(height: 24),
              AsyncParkButton(
                'Lưu thông tin',
                action: () async {
                  if (name.text.trim().isEmpty) {
                    throw const ParkFailure('Vui lòng nhập họ tên.');
                  }
                  await widget.repository.updateProfile(
                    name.text.trim(),
                    phone.text.trim(),
                  );
                },
                onSuccess: () => Navigator.pop(context),
              ),
            ],
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
          child: Text(
            'Đặt chỗ cần kết nối mạng và được máy chủ xác nhận. Xuất trình QR khi vào/ra bãi. Nhân viên kiểm tra và sửa kết quả OCR trước khi xác nhận. Khi mất mạng, các thao tác được phép nằm trong mục Đồng bộ dữ liệu; chỗ trống đã lưu có thể không còn chính xác. Liên hệ chủ bãi để xử lý vé có xung đột.',
          ),
        ),
      ],
    ),
  );
}
