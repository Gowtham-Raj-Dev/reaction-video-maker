import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../models/split_config.dart';
import 'snap_guides.dart';
import 'split_divider.dart';

/// A high-performance two-pane split with a premium draggable divider.
///
/// Only the panes flex around the divider rebuild during a drag — the [leading]
/// and [trailing] subtrees are captured once and reused, so a live camera or
/// playing video is never torn down while resizing. This is what keeps dragging
/// smooth at 60fps and avoids flicker.
class AdjustableSplit extends StatelessWidget {
  const AdjustableSplit({
    super.key,
    required this.axis,
    required this.fraction,
    required this.dragging,
    required this.snapGuide,
    required this.config,
    required this.onDragStart,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.leading,
    required this.trailing,
    this.dividerThickness = 22,
    this.editorMode = true,
  });

  /// [Axis.vertical] stacks [leading] above [trailing]; [Axis.horizontal] places
  /// them side by side.
  final Axis axis;
  final ValueListenable<double> fraction;
  final ValueListenable<bool> dragging;
  final ValueListenable<double?> snapGuide;
  final SplitConfig config;

  final VoidCallback onDragStart;

  /// Called with a movement expressed as a fraction of the available extent.
  /// Returns whether a new snap point engaged so we can fire haptics once.
  final bool Function(double deltaFraction) onDragDelta;
  final VoidCallback onDragEnd;

  final Widget leading;
  final Widget trailing;
  final double dividerThickness;
  final bool editorMode;

  bool get _isVertical => axis == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    // Capture children once so the drag rebuilds never re-create them.
    final Widget leadingChild = leading;
    final Widget trailingChild = trailing;
    final double actualThickness = editorMode ? dividerThickness : 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = _isVertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final available = (extent - actualThickness).clamp(0.0, extent);

        return Stack(
          children: [
            AnimatedBuilder(
              animation: fraction,
              builder: (context, _) {
                final leadingSize = (available * fraction.value)
                    .clamp(0.0, available);
                final trailingSize = available - leadingSize;

                final panes = <Widget>[
                  SizedBox(
                    width: _isVertical ? double.infinity : leadingSize,
                    height: _isVertical ? leadingSize : double.infinity,
                    child: leadingChild,
                  ),
                  _DividerHandle(
                    axis: axis,
                    thickness: actualThickness,
                    available: available,
                    dragging: dragging,
                    snapGuide: snapGuide,
                    onStart: onDragStart,
                    onDelta: onDragDelta,
                    onEnd: onDragEnd,
                    editorMode: editorMode,
                  ),
                  SizedBox(
                    width: _isVertical ? double.infinity : trailingSize,
                    height: _isVertical ? trailingSize : double.infinity,
                    child: trailingChild,
                  ),
                ];

                return _isVertical
                    ? Column(children: panes)
                    : Row(children: panes);
              },
            ),
            // Snap guide overlay only paints while dragging.
            if (editorMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: SnapGuidesOverlay(
                    axis: axis,
                    available: available,
                    dividerThickness: actualThickness,
                    config: config,
                    dragging: dragging,
                    activeSnap: snapGuide,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wraps the visual [SplitDivider] with the pan gesture + haptics.
class _DividerHandle extends StatelessWidget {
  const _DividerHandle({
    required this.axis,
    required this.thickness,
    required this.available,
    required this.dragging,
    required this.snapGuide,
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
    this.editorMode = true,
  });

  final Axis axis;
  final double thickness;
  final double available;
  final ValueListenable<bool> dragging;
  final ValueListenable<double?> snapGuide;
  final VoidCallback onStart;
  final bool Function(double) onDelta;
  final VoidCallback onEnd;
  final bool editorMode;

  bool get _isVertical => axis == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: editorMode
          ? (_isVertical
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn)
          : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: editorMode
            ? (_) {
                Haptics.selection();
                onStart();
              }
            : null,
        onPanUpdate: editorMode
            ? (details) {
                if (available <= 0) return;
                final pixels = _isVertical ? details.delta.dy : details.delta.dx;
                final engagedNew = onDelta(pixels / available);
                if (engagedNew) Haptics.snap();
              }
            : null,
        onPanEnd: editorMode
            ? (_) {
                Haptics.tap();
                onEnd();
              }
            : null,
        child: ValueListenableBuilder<bool>(
          valueListenable: dragging,
          builder: (context, isDragging, _) {
            return ValueListenableBuilder<double?>(
              valueListenable: snapGuide,
              builder: (context, snap, child) {
                return SplitDivider(
                  axis: axis,
                  dragging: isDragging,
                  snapped: snap != null,
                  thickness: thickness,
                  editorMode: editorMode,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
