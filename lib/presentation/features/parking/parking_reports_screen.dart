import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/parking_rules.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../../../shared/widgets/plate_input.dart';

const reportStatuses = {
  'open': 'Mới gửi',
  'move_requested': 'Đã yêu cầu di chuyển',
  'assigned': 'Đã giao nhân viên',
  'in_progress': 'Đang xử lý',
  'resolved': 'Đã giải quyết',
  'rejected': 'Đã từ chối',
};

class ParkingReportsScreen extends StatefulWidget {
  const ParkingReportsScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<ParkingReportsScreen> createState() => _ParkingReportsScreenState();
}

class _ParkingReportsScreenState extends State<ParkingReportsScreen> {
  final plate = TextEditingController(), description = TextEditingController();
  String operationId = const Uuid().v4(), reportId = const Uuid().v4();
  Json? submitted;
  @override
  void dispose() {
    plate.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    return ParkPage(
      child: Column(
        children: [
          PageHeading(
            repo.canStaff ? 'Báo cáo được phân công' : 'Báo cáo đỗ sai',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                if (!repo.canStaff) ...[
                  DropdownButton<String>(
                    isExpanded: true,
                    value:
                        repo.lots.any((l) => l.id == repo.lot.id)
                            ? repo.lot.id
                            : null,
                    items: [
                      for (final l in repo.lots)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged:
                        (id) => repo.update(
                          () =>
                              repo.lot = repo.lots.firstWhere(
                                (l) => l.id == id,
                              ),
                        ),
                  ),
                  PlateInput(controller: plate, capture: repo.recognizePlate),
                  TextField(
                    controller: description,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Vị trí và tình trạng đỗ sai',
                    ),
                  ),
                  AsyncParkButton(
                    'Xác nhận biển số và gửi báo cáo',
                    action: () async {
                      final actor = repo.userId, lotId = repo.lot.id;
                      final normalized = normalizePlate(plate.text);
                      if (!isValidPlate(normalized) ||
                          description.text.trim().isEmpty) {
                        throw const ParkFailure(
                          'Kiểm tra biển số và nhập mô tả.',
                        );
                      }
                      if (!await confirmAction(
                        context,
                        'Gửi báo cáo xe $normalized tại ${repo.lot.name}?',
                      )) {
                        return;
                      }
                      if (repo.userId != actor || repo.lot.id != lotId) {
                        throw const ParkFailure(
                          'Tài khoản hoặc bãi đã thay đổi. Hãy gửi lại báo cáo.',
                        );
                      }
                      final payload = <String, dynamic>{
                        'id': reportId,
                        'lot_id': repo.lot.id,
                        'plate': normalized,
                        'description': description.text.trim(),
                      };
                      if (submitted != null &&
                          payload.entries.any(
                            (e) => submitted![e.key] != e.value,
                          )) {
                        operationId = const Uuid().v4();
                        reportId = const Uuid().v4();
                        payload['id'] = reportId;
                      }
                      submitted = payload;
                      await repo.backend.execute(
                        operationId,
                        'report.create',
                        payload,
                      );
                      if (!mounted || repo.userId != actor) {
                        return;
                      }
                      operationId = const Uuid().v4();
                      reportId = const Uuid().v4();
                      submitted = null;
                      plate.clear();
                      description.clear();
                      await repo.refresh();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                for (final r in repo.snapshot.rows('reports'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ParkCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['plate'] as String,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            repo.lots
                                    .where((l) => l.id == r['lot_id'])
                                    .firstOrNull
                                    ?.name ??
                                '',
                          ),
                          Text(r['description'] as String),
                          Text(
                            reportStatuses[r['status']] ??
                                r['status'] as String,
                          ),
                          for (final e in repo.snapshot
                              .rows('report_events')
                              .where((e) => e['report_id'] == r['id']))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                reportStatuses[e['status']] ??
                                    e['status'] as String,
                              ),
                              subtitle: Text(
                                '${DateTime.parse(e['created_at'] as String).toLocal()} · ${e['note']}',
                              ),
                            ),
                          if (repo.canStaff &&
                              r['assigned_to'] == repo.userId &&
                              ['assigned', 'in_progress'].contains(r['status']))
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final status in [
                                  'in_progress',
                                  'resolved',
                                ])
                                  AsyncParkButton(
                                    reportStatuses[status]!,
                                    action: () async {
                                      await repo.backend.execute(
                                        const Uuid().v4(),
                                        'report.progress',
                                        {
                                          'report_id': r['id'],
                                          'expected_version': r['version'],
                                          'status': status,
                                        },
                                      );
                                      await repo.refresh();
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (repo.snapshot.rows('reports').isEmpty)
                  const Text('Chưa có báo cáo.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
