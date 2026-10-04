import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The premium, Figma/Canva-style draggable divider handle.
///
/// Purely presentational — gesture handling lives in [AdjustableSplit]. It
/// animates a scale + glow while [dragging] is true and shows a subtle snap
/// pulse whenever [snapped] is true.
class SplitDivider extends StatelessWidget {
  const SplitDivider({
    super.key,
    required this.axis,
    required this.dragging,
    required this.snapped,
    this.thickness = 22,
    this.editorMode = true,
  });

  /// [Axis.vertical] means the divider itself is horizontal (it separates a
  /// top and bottom section). [Axis.horizontal] separates left/right.
  final Axis axis;
  final bool dragging;
  final bool snapped;
  final double thickness;
  final bool editorMode;

  @override
  Widget build(BuildContext context) {
    final isHorizontalDivider = axis == Axis.vertical;
    if (!editorMode) {
      return SizedBox(
        width: isHorizontalDivider ? double.infinity : thickness,
        height: isHorizontalDivider ? thickness : double.infinity,
      );
    }

    final glow = dragging
        ? (snapped ? AppColors.success : AppColors.accent)
        : Colors.transparent;

    return AnimatedContainer(
      duration: AppSpacing.fast,
      curve: Curves.easeOut,
      color: Colors.transparent,
      width: isHorizontalDivider ? double.infinity : thickness,
      height: isHorizontalDivider ? thickness : double.infinity,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faint full-length track line.
            Align(
              child: Container(
                width: isHorizontalDivider ? double.infinity : 1.2,
                height: isHorizontalDivider ? 1.2 : double.infinity,
                color: AppColors.stroke,
              ),
            ),
            // The pill handle.
            AnimatedScale(
              duration: AppSpacing.medium,
              curve: AppSpacing.spring,
              scale: dragging ? 1.18 : 1.0,
              child: AnimatedContainer(
                duration: AppSpacing.fast,
                width: isHorizontalDivider ? 46 : 6,
                height: isHorizontalDivider ? 6 : 46,
                decoration: BoxDecoration(
                  gradient: dragging
                      ? LinearGradient(colors: [glow, glow])
                      : null,
                  color: dragging ? null : AppColors.strokeStrong,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    if (dragging)
                      BoxShadow(
                        color: glow.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
