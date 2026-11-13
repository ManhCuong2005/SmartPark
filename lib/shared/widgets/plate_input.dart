import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'park_widgets.dart';

/// OCR suggests text only. The operator always confirms the editable plate.
class PlateInput extends StatefulWidget {
  const PlateInput({
    super.key,
    required this.controller,
    required this.capture,
  });
  final TextEditingController controller;
  final Future<List<String>?> Function() capture;
  @override
  State<PlateInput> createState() => _PlateInputState();
}

class _PlateInputState extends State<PlateInput> {
  bool busy = false;
  List<String> candidates = [];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ParkButton(
        busy ? 'Đang nhận diện…' : 'Chụp biển số · AI OCR',
        onPressed:
            busy
                ? null
                : () async {
                  setState(() => busy = true);
                  await runAction(context, () async {
                    final result = await widget.capture();
                    if (!mounted || result == null) return;
                    if (result.isNotEmpty) await HapticFeedback.mediumImpact();
                    if (!mounted) return;
                    setState(() {
                      candidates = result;
                      if (result.length == 1) {
                        widget.controller.text = result.first;
                      }
                    });
                    if (result.isEmpty && context.mounted) {
                      showMessage(
                        context,
                        'Chưa đọc được biển số. Hãy chụp lại hoặc nhập tay.',
                      );
                    }
                  });
                  if (mounted) setState(() => busy = false);
                },
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final plate in candidates)
            ActionChip(
              label: Text(plate),
              onPressed: () => widget.controller.text = plate,
            ),
        ],
      ),
      TextField(
        controller: widget.controller,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Biển số thực tế · có thể sửa',
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Đối chiếu biển số thực tế và sửa kết quả OCR trước khi xác nhận.',
      ),
    ],
  );
}
