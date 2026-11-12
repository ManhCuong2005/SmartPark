import 'package:flutter/material.dart';
import 'park_controller.dart';
import '../shared/widgets/park_widgets.dart';

class SyncQueueScreen extends StatelessWidget {
  const SyncQueueScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  Widget build(BuildContext context) => ParkPage(
    child: Column(
      children: [
        const PageHeading(
          'Đồng bộ tự động',
          subtitle:
              'Ứng dụng tự gửi khi có mạng. Bạn không cần đồng bộ thủ công.',
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              ParkCard(
                child: Row(
                  children: [
                    Icon(
                      repository.operations.isEmpty
                          ? Icons.cloud_done_outlined
                          : Icons.schedule,
                      color: ParkColors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        repository.operations.isEmpty
                            ? 'Không có thao tác chờ.'
                            : 'Thay đổi đã được lưu trên thiết bị và sẽ tự gửi khi kết nối được máy chủ.',
                      ),
                    ),
                  ],
                ),
              ),
              if (repository.operations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Bạn có thể tiếp tục sử dụng ứng dụng bình thường.',
                  ),
                ),
              for (final op in repository.operations)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          operationLabel(op.kind),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          op.state == 'conflict'
                              ? 'Cần kiểm tra xung đột'
                              : 'Sẽ tự động gửi lại khi có kết nối',
                        ),
                        if (op.error != null) Text(op.error!),
                        if (op.state == 'conflict')
                          const Text(
                            'Máy chủ yêu cầu kiểm tra dữ liệu hoặc quyền truy cập. Xem lại vé; nếu cần, bỏ thao tác cũ và tạo thao tác mới từ dữ liệu hiện tại.',
                          ),
                        if (op.state == 'conflict')
                          Wrap(
                            children: [
                              TextButton(
                                onPressed:
                                    () => runAction(
                                      context,
                                      () => repository.retryOperation(op.id),
                                    ),
                                child: const Text('Thử lại sau khi kiểm tra'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (await confirmAction(
                                        context,
                                        'Bỏ thao tác khỏi hàng đợi? Nếu máy chủ đã nhận, việc bỏ không hoàn tác dữ liệu trên máy chủ.',
                                      ) &&
                                      context.mounted) {
                                    await runAction(
                                      context,
                                      () => repository.discardOperation(op.id),
                                    );
                                  }
                                },
                                child: const Text('Bỏ thao tác'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'Nếu đóng ứng dụng, thao tác vẫn được giữ trên thiết bị và tự tiếp tục khi mở lại.',
                  style: TextStyle(fontSize: 12, color: ParkColors.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String operationLabel(String kind) =>
    const {
      'staff.check_in': 'Xác nhận xe vào bãi',
      'staff.check_out': 'Xác nhận xe ra bãi',
      'vehicle.save': 'Cập nhật phương tiện',
      'notifications.read': 'Đánh dấu thông báo đã đọc',
    }[kind] ??
    'Thao tác đang chờ';
