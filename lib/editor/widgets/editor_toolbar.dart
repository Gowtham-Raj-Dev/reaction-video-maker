import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'glass.dart';
import 'premium_button.dart';

/// The floating glassmorphism bottom toolbar. Supports expand / collapse and
/// never appears in exported video (it lives in the editor scaffold only).
class EditorToolbar extends StatefulWidget {
  const EditorToolbar({
    super.key,
    required this.onAdd,
    required this.onLayout,
    required this.onPreview,
    required this.onExport,
    required this.onFlipCamera,
    required this.onMirror,
    required this.previewing,
  });

  final VoidCallback onAdd;
  final VoidCallback onLayout;
  final VoidCallback onPreview;
  final VoidCallback onExport;
  final VoidCallback onFlipCamera;
  final VoidCallback onMirror;
  final bool previewing;

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _collapseHandle(),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: AppSpacing.medium,
          curve: AppSpacing.easeEmphasized,
          child: _expanded
              ? GlassContainer(
                  strong: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassIconButton(
                        icon: Icons.add_rounded,
                        label: 'Add',
                        onTap: widget.onAdd,
                      ),
                      const SizedBox(width: 6),
                      GlassIconButton(
                        icon: Icons.dashboard_rounded,
                        label: 'Layout',
                        onTap: widget.onLayout,
                      ),
                      const SizedBox(width: 6),
                      GlassIconButton(
                        icon: Icons.flip_camera_android_rounded,
                        label: 'Flip',
                        onTap: widget.onFlipCamera,
                      ),
                      const SizedBox(width: 6),
                      GlassIconButton(
                        icon: Icons.flip_rounded,
                        label: 'Mirror',
                        onTap: widget.onMirror,
                      ),
                      const SizedBox(width: 6),
                      GlassIconButton(
                        icon: widget.previewing
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        label: widget.previewing ? 'Editing' : 'Preview',
                        active: widget.previewing,
                        tint: AppColors.accentSecondary,
                        onTap: widget.onPreview,
                      ),
                      const SizedBox(width: 12),
                      PremiumButton(
                        label: 'Export',
                        icon: Icons.ios_share_rounded,
                        compact: true,
                        onTap: widget.onExport,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: 60, height: 0),
        ),
      ],
    );
  }

  Widget _collapseHandle() {
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        setState(() => _expanded = !_expanded);
      },
      child: GlassContainer(
        borderRadius: 100,
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: AnimatedRotation(
          duration: AppSpacing.medium,
          turns: _expanded ? 0 : 0.5,
          child: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
