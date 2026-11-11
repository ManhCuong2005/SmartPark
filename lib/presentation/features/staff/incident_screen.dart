import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';

class StaffIncidentScreen extends StatefulWidget {
  const StaffIncidentScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<StaffIncidentScreen> createState() => _StaffIncidentScreenState();
}
class _StaffIncidentScreenState extends State<StaffIncidentScreen> {
  final description = TextEditingController();
  String? lotId;
  String category = 'wrong_slot';
  bool busy = false;
  @override
  void dispose() { description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final lots = repo.lots.where((l) => repo.snapshot.rows('memberships').any((m) => m['lot_id'] == l.id && m['user_id'] == repo.userId && m['active'] == true) || repo.snapshot.rows('lots').any((r) => r['id'] == l.id && r['owner_id'] == repo.userId)).toList();
    lotId ??= lots.firstOrNull?.id;
    return ParkPage(bottom: const ParkBottomNav(active: 0, staff: true), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading('Báo cáo sự cố'),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: Text('Ghi nhận tình huống để chủ bãi theo dõi và cập nhật cách xử lý. Cần kết nối mạng để gửi báo cáo.')),
      Padding(padding: const EdgeInsets.all(22), child: ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bãi đỗ'), const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: lotId, items: lots.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(), onChanged: busy ? null : (v) => setState(() => lotId = v)),
        const SizedBox(height: 18), const Text('Loại sự cố'), const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: category, items: const [DropdownMenuItem(value: 'wrong_slot', child: Text('Xe đỗ sai ô')), DropdownMenuItem(value: 'ticket_mismatch', child: Text('Vé không khớp')), DropdownMenuItem(value: 'vehicle_damage', child: Text('Hư hỏng phương tiện')), DropdownMenuItem(value: 'equipment', child: Text('Thiết bị bãi đỗ')), DropdownMenuItem(value: 'safety', child: Text('An toàn / an ninh')), DropdownMenuItem(value: 'other', child: Text('Khác'))], onChanged: busy ? null : (v) => setState(() => category = v ?? category)),
        const SizedBox(height: 18), TextField(controller: description, minLines: 4, maxLines: 7, maxLength: 2000, decoration: const InputDecoration(labelText: 'Mô tả sự cố', hintText: 'Nêu vị trí, tình huống và việc đã xử lý…', border: OutlineInputBorder())),
        const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy || !repo.online || lotId == null ? null : () async {
          setState(() => busy = true);
          try { await repo.reportIncident(lotId!, null, category, description.text); if (!context.mounted) return; description.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo sự cố.'))); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không gửi được: $e'))); }
          finally { if (mounted) setState(() => busy = false); }
        }, icon: const Icon(Icons.report_outlined), label: Text(busy ? 'Đang gửi…' : 'Gửi báo cáo'))),
        if (!repo.online) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Đang ngoại tuyến. Hãy kết nối lại để gửi báo cáo.', style: TextStyle(color: Colors.deepOrange))),
      ])))
    ]));
  }
}
