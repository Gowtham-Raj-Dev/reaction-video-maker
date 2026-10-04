import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../controllers/canvas_controller.dart';
import '../models/canvas_item.dart';
import 'glass.dart';
import 'text_editor_sheet.dart';

/// Floating inspector shown when a canvas item is selected. Exposes the item's
/// editable properties: opacity, border radius, shadow, plus quick actions
/// (duplicate, lock, layer ordering, delete).
class ItemInspector extends StatelessWidget {
  const ItemInspector({
    super.key,
    required this.controller,
    required this.item,
  });

  final CanvasController controller;
  final CanvasItem item;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      strong: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(item.type.icon, size: 16, color: AppColors.accentSecondary),
          const SizedBox(width: 8),
          Text(
            item.type.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (item.type == CanvasItemType.text ||
              item.type == CanvasItemType.watermark)
            _action(Icons.keyboard_rounded, 'Edit text', () {
              TextEditorSheet.show(context,
                  controller: controller, item: item);
            }),
          _action(Icons.delete_outline_rounded, 'Delete',
              () => controller.remove(item.id),
              tint: AppColors.error),
          // Close the inspector / deselect.
          _action(Icons.close_rounded, 'Close',
              () => controller.select(null)),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String tip, VoidCallback onTap,
      {bool active = false, Color? tint}) {
    final color = tint ?? (active ? AppColors.accent : AppColors.textSecondary);
    return Tooltip(
      message: tip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () {
          Haptics.selection();
          onTap();
        },
        icon: Icon(icon, size: 18, color: color),
      ),
    );
  }


}
