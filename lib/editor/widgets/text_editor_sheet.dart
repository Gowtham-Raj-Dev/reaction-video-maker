import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../models/canvas_item.dart';
import 'premium_button.dart';

/// Bottom sheet for typing / styling a text (or watermark) item. Edits the
/// item live and closes with the Done button.
class TextEditorSheet extends StatefulWidget {
  const TextEditorSheet({
    super.key,
    required this.controller,
    required this.item,
  });

  final CanvasController controller;
  final CanvasItem item;

  static Future<void> show(
    BuildContext context, {
    required CanvasController controller,
    required CanvasItem item,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Padding(
        // Lift above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: TextEditorSheet(controller: controller, item: item),
      ),
    );
  }

  @override
  State<TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<TextEditorSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.item.text);

  static const _colors = [
    Colors.white,
    AppColors.accent,
    AppColors.accentSecondary,
    AppColors.warning,
    AppColors.success,
    Colors.black,
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply(void Function(CanvasItem) mutate) {
    widget.controller.update(widget.item.id, mutate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.stroke),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.strokeStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: AppColors.accentSecondary,
              decoration: InputDecoration(
                hintText: 'Type your text…',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide:
                      const BorderSide(color: AppColors.accentSecondary),
                ),
              ),
              onChanged: (v) => _apply((i) => i.text = v),
            ),
            const SizedBox(height: 16),
            const Text('Color',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in _colors)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        Haptics.selection();
                        _apply((i) => i.color = c);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.color == c
                                ? AppColors.accentSecondary
                                : AppColors.stroke,
                            width: item.color == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.format_size_rounded,
                    size: 18, color: AppColors.textSecondary),
                Expanded(
                  child: Slider(
                    value: item.fontSize.clamp(12, 64),
                    min: 12,
                    max: 64,
                    activeColor: AppColors.accentSecondary,
                    onChanged: (v) => _apply((i) => i.fontSize = v),
                  ),
                ),
                _weightToggle(item),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightToggle(CanvasItem item) {
    final bold = item.fontWeight.value >= FontWeight.w600.value;
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        _apply((i) =>
            i.fontWeight = bold ? FontWeight.w400 : FontWeight.w800);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bold ? AppColors.accentSecondary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(Icons.format_bold_rounded,
            color: bold ? Colors.white : AppColors.textSecondary),
      ),
    );
  }
}
