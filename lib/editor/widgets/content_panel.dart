import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import 'canvas_item_widget.dart';
import 'panel_frame.dart';
import 'text_editor_sheet.dart';
import '../models/canvas_item.dart';

/// The editable content area (left / bottom-left panel). Hosts freely placed
/// overlay items (text, images, stickers, emoji, …) stacked in layer order.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, this.editorMode = true});

  final bool editorMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanvasController>();

    return PanelFrame(
      icon: Icons.dashboard_customize_rounded,
      label: 'Content',
      editorMode: editorMode,
      accent: AppColors.accentSecondary.withValues(alpha: 0.35),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelSize = Size(constraints.maxWidth, constraints.maxHeight);
          final items = controller.items;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: editorMode ? () => controller.select(null) : null,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(child: _ContentBackdrop()),
                if (items.isEmpty && editorMode)
                  const Positioned.fill(child: _EmptyContentState()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContentBackdrop extends StatelessWidget {
  const _ContentBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141019), Color(0xFF0F0F14)],
        ),
      ),
    );
  }
}

class _EmptyContentState extends StatelessWidget {
  const _EmptyContentState();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final canvas = context.read<CanvasController>();
        canvas.add(CanvasItemType.text);
        final item = canvas.selected;
        if (item != null) {
          await TextEditorSheet.show(context, controller: canvas, item: item);
        }
      },
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.violetGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentSecondary.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Add Text',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tap the + button below or click here to type.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
