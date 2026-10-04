import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Premium rounded frame shared by every canvas section. Provides the rounded
/// corners, soft border and optional floating label chip.
///
/// [editorMode] toggles the editor-only chrome (label chip, dashed active
/// border) so the exact same widget can render the clean exported frame.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.child,
    required this.icon,
    required this.label,
    this.editorMode = true,
    this.margin = const EdgeInsets.all(6),
    this.accent = AppColors.stroke,
  });

  final Widget child;
  final IconData icon;
  final String label;
  final bool editorMode;
  final EdgeInsets margin;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: editorMode ? accent : Colors.transparent,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
