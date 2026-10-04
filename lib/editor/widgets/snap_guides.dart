import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/split_config.dart';

/// Paints faint guide lines at every valid snap position while a divider is
/// being dragged, and highlights the one currently engaged. Gives the same
/// "magnetic guide" feel as Figma / Canva.
class SnapGuidesOverlay extends StatelessWidget {
  const SnapGuidesOverlay({
    super.key,
    required this.axis,
    required this.available,
    required this.dividerThickness,
    required this.config,
    required this.dragging,
    required this.activeSnap,
  });

  final Axis axis;
  final double available;
  final double dividerThickness;
  final SplitConfig config;
  final ValueListenable<bool> dragging;
  final ValueListenable<double?> activeSnap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: dragging,
      builder: (context, isDragging, _) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isDragging ? 1 : 0,
          child: ValueListenableBuilder<double?>(
            valueListenable: activeSnap,
            builder: (context, snap, child) {
              return CustomPaint(
                painter: _SnapGuidePainter(
                  axis: axis,
                  available: available,
                  dividerThickness: dividerThickness,
                  points: config.snapPoints.where((p) {
                    return p >= config.minLeading &&
                        p <= 1 - config.minTrailing;
                  }).toList(),
                  active: snap,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SnapGuidePainter extends CustomPainter {
  _SnapGuidePainter({
    required this.axis,
    required this.available,
    required this.dividerThickness,
    required this.points,
    required this.active,
  });

  final Axis axis;
  final double available;
  final double dividerThickness;
  final List<double> points;
  final double? active;

  bool get _isVertical => axis == Axis.vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = AppColors.strokeStrong
      ..strokeWidth = 1;
    final activePaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2;

    for (final p in points) {
      final center = available * p + dividerThickness / 2;
      final isActive = active != null && (active! - p).abs() < 0.001;
      final paint = isActive ? activePaint : base;
      if (_isVertical) {
        _dashedLine(canvas, Offset(0, center), Offset(size.width, center),
            paint, isActive);
      } else {
        _dashedLine(canvas, Offset(center, 0), Offset(center, size.height),
            paint, isActive);
      }
    }
  }

  void _dashedLine(
      Canvas canvas, Offset a, Offset b, Paint paint, bool solid) {
    if (solid) {
      canvas.drawLine(a, b, paint);
      return;
    }
    const dash = 6.0;
    const gap = 6.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double drawn = 0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * (drawn + dash).clamp(0, total).toDouble();
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_SnapGuidePainter old) =>
      old.active != active ||
      old.available != available ||
      old.points.length != points.length;
}
