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
          'Đồng bộ dữ liệu',
          subtitle: 'Thao tác chờ chưa được máy chủ xác nhận.',
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              AsyncParkButton('Đồng bộ ngay', action: repository.refresh),
              if (repository.operations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không có thao tác chờ.'),
                ),
              for (final op in repository.operations)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          op.kind,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          op.state == 'conflict'
                              ? 'Cần kiểm tra xung đột'
                              : 'Đang chờ gửi · đã thử ${op.attempts} lần',
                        ),
                        if (op.error != null) Text(op.error!),
                        if (op.state == 'conflict')
                          const Text(
                            'Tải dữ liệu mới và kiểm tra vé trước khi tạo thao tác mới.',
                          ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed:
                                  () => runAction(
                                    context,
                                    () => repository.retryOperation(op.id),
                                  ),
                              child: const Text('Thử lại cùng mã'),
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
            ],
          ),
        ),
      ],
    ),
  );
}
