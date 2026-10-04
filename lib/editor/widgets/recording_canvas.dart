import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/layout_controller.dart';
import '../controllers/canvas_controller.dart';
import 'adjustable_split.dart';
import 'camera_panel.dart';
import 'content_panel.dart';
import 'video_panel.dart';
import 'canvas_item_widget.dart';

/// The recording canvas: the ONLY thing that gets exported.
///
/// Layout:
///   ┌───────────────────────────┐
///   │        Uploaded Video      │   <- videoSplit (vertical divider)
///   ├─────────────┬─────────────┤
///   │   Content   │   Camera     │   <- bottomSplit (horizontal divider)
///   └─────────────┴─────────────┘
///
/// When [editorMode] is false all editor guides (dividers, chips, handles) are
/// hidden so the frame renders exactly like the exported video.
class RecordingCanvas extends StatelessWidget {
  RecordingCanvas({
    required this.layout,
    this.editorMode = true,
  }) : super(key: layout.canvasKey);

  final LayoutController layout;
  final bool editorMode;

  Widget _buildPanel(Widget child, bool isRounded) {
    return Container(
      margin: isRounded ? const EdgeInsets.all(AppSpacing.sm) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: isRounded ? BorderRadius.circular(AppSpacing.radiusXl) : BorderRadius.zero,
        color: AppColors.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: layout.isRoundedCorners,
      builder: (context, isRounded, _) {
        return ValueListenableBuilder<LayoutMode>(
          valueListenable: layout.mode,
          builder: (context, mode, _) {
            if (mode == LayoutMode.topVideo) {
              return ColoredBox(
                color: AppColors.background,
                child: AdjustableSplit(
                  axis: Axis.vertical,
                  fraction: layout.videoSplit,
                  dragging: layout.videoDragging,
                  snapGuide: layout.videoSnapGuide,
                  config: LayoutController.videoConfig,
                  onDragStart: layout.beginVideoDrag,
                  onDragDelta: layout.updateVideo,
                  onDragEnd: layout.endVideoDrag,
                  leading: _buildPanel(VideoPanel(editorMode: editorMode), isRounded),
                  trailing: _buildPanel(CameraPanel(editorMode: editorMode), isRounded),
                  editorMode: false,
                ),
              );
            } else if (mode == LayoutMode.topCamera) {
              return ColoredBox(
                color: AppColors.background,
                child: AdjustableSplit(
                  axis: Axis.vertical,
                  fraction: layout.videoSplit,
                  dragging: layout.videoDragging,
                  snapGuide: layout.videoSnapGuide,
                  config: LayoutController.videoConfig,
                  onDragStart: layout.beginVideoDrag,
                  onDragDelta: layout.updateVideo,
                  onDragEnd: layout.endVideoDrag,
                  leading: _buildPanel(CameraPanel(editorMode: editorMode), isRounded),
                  trailing: _buildPanel(VideoPanel(editorMode: editorMode), isRounded),
                  editorMode: false,
                ),
              );
            } else if (mode == LayoutMode.pip) {
              return ColoredBox(
                color: AppColors.background,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: Listenable.merge([layout.pipSize, layout.pipHeight]),
                      builder: (context, _) {
                        final pipW = constraints.maxWidth * layout.pipSize.value;
                        final pipH = constraints.maxHeight * layout.pipHeight.value;
                        final radius = math.min(12.0, pipW * 0.06);
                        
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: _buildPanel(VideoPanel(editorMode: editorMode), isRounded),
                            ),
                            Positioned(
                              bottom: 16, // Change to bottom right
                              right: 16,
                              width: pipW,
                              height: pipH,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: isRounded ? BorderRadius.circular(radius) : BorderRadius.zero,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: isRounded ? BorderRadius.circular(radius) : BorderRadius.zero,
                                  child: _buildPanel(CameraPanel(editorMode: editorMode), isRounded),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    );
                  }
                ),
              );
            }

            // Classic mode
            final bottomSection = AdjustableSplit(
              axis: Axis.horizontal,
              fraction: layout.bottomSplit,
              dragging: layout.bottomDragging,
              snapGuide: layout.bottomSnapGuide,
              config: LayoutController.bottomConfig,
              onDragStart: layout.beginBottomDrag,
              onDragDelta: layout.updateBottom,
              onDragEnd: layout.endBottomDrag,
              leading: _buildPanel(ContentPanel(editorMode: editorMode), isRounded),
              trailing: _buildPanel(CameraPanel(editorMode: editorMode), isRounded),
              editorMode: false,
            );

            Widget layoutWidget = ColoredBox(
              color: AppColors.background,
              child: AdjustableSplit(
                axis: Axis.vertical,
                fraction: layout.videoSplit,
                dragging: layout.videoDragging,
                snapGuide: layout.videoSnapGuide,
                config: LayoutController.videoConfig,
                onDragStart: layout.beginVideoDrag,
                onDragDelta: layout.updateVideo,
                onDragEnd: layout.endVideoDrag,
                leading: _buildPanel(VideoPanel(editorMode: editorMode), isRounded),
                trailing: bottomSection,
                editorMode: false,
              ),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final panelSize = Size(constraints.maxWidth, constraints.maxHeight);
                final controller = context.watch<CanvasController>();
                final items = controller.items;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: editorMode ? () => controller.select(null) : null,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(child: layoutWidget),
                      for (final item in items)
                        CanvasItemWidget(
                          key: ValueKey(item.id),
                          item: item,
                          panelSize: panelSize,
                          selected: item.id == controller.selectedId,
                          controller: controller,
                          editorMode: editorMode,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
