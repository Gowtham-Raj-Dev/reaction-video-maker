import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../controllers/canvas_controller.dart';
import '../controllers/media_controller.dart';
import '../models/canvas_item.dart';
import 'text_editor_sheet.dart';

/// Renders a single [CanvasItem] with interactive move / resize / rotate
/// handles. Fraction-based geometry keeps items anchored correctly as the
/// content panel is resized by the dividers.
class CanvasItemWidget extends StatefulWidget {
  const CanvasItemWidget({
    super.key,
    required this.item,
    required this.panelSize,
    required this.selected,
    required this.controller,
    required this.editorMode,
  });

  final CanvasItem item;
  final Size panelSize;
  final bool selected;
  final CanvasController controller;

  /// When false (export / preview) no handles or outlines are drawn.
  final bool editorMode;

  @override
  State<CanvasItemWidget> createState() => _CanvasItemWidgetState();
}

class _CanvasItemWidgetState extends State<CanvasItemWidget> {
  static const double _minPx = 40;

  Size get _panel => widget.panelSize;

  double get _shortest => math.max(_panel.width, _panel.height);

  // Pixel geometry derived from the item's fractional geometry.
  Size get _pxSize => Size(
        widget.item.size.width * _shortest,
        widget.item.size.height * _shortest,
      );

  Offset get _pxCenter => Offset(
        widget.item.center.dx * _panel.width,
        widget.item.center.dy * _panel.height,
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = _pxSize;
    final center = _pxCenter;
    final left = center.dx - size.width / 2;
    final top = center.dy - size.height / 2;

    return Positioned(
      left: left,
      top: top,
      width: size.width,
      height: size.height,
      child: Transform.rotate(
        angle: item.rotation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.editorMode
              ? () {
                  Haptics.selection();
                  // Tapping a text item that's already selected opens the
                  // editor so users can just tap-tap to type.
                  if (_isTextual(item) && widget.selected) {
                    _editText(context);
                  } else {
                    widget.controller.select(item.id);
                  }
                }
              : null,
          onDoubleTap: widget.editorMode && _isTextual(item)
              ? () => _editText(context)
              : null,
          onPanUpdate: widget.editorMode && !item.locked
              ? (details) => _move(details.delta)
              : null,
          onPanEnd: widget.editorMode ? (_) => _commit() : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildContent(item, size),
              if (widget.editorMode && widget.selected) ...[
                _selectionBorder(),
                _resizeHandle(),
                _rotateHandle(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CanvasItem item, Size size) {
    Widget child;
    switch (item.type) {
      case CanvasItemType.text:
      case CanvasItemType.watermark:
        child = Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: AutoSizeText(
            item.text,
            textAlign: TextAlign.center,
            wrapWords: false,
            minFontSize: 8,
            maxLines: 10,
            style: TextStyle(
              color: item.color,
              fontSize: item.fontSize,
              fontWeight: item.fontWeight,
              height: 1.1,
            ),
          ),
        );
      case CanvasItemType.emoji:
        child = Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(item.text.isEmpty ? '😀' : item.text),
          ),
        );
      case CanvasItemType.image:
      case CanvasItemType.logo:
      case CanvasItemType.sticker:
      case CanvasItemType.gif:
      case CanvasItemType.qrCode:
      case CanvasItemType.socialIcon:
        child = _mediaPlaceholder(item);
    }

    return Opacity(
      opacity: item.opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(item.borderRadius),
          boxShadow: item.hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(item.borderRadius),
          child: child,
        ),
      ),
    );
  }

  Widget _mediaPlaceholder(CanvasItem item) {
    if (item.assetPath != null) {
      if (kIsWeb) {
        final mediaCtrl = Provider.of<MediaController>(context, listen: false);
        final bytes = mediaCtrl.webImageBytes[item.assetPath];
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholderBox(item),
          );
        }
        return Image.network(
          item.assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _placeholderBox(item),
        );
      } else {
        return Image.file(
          File(item.assetPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _placeholderBox(item),
        );
      }
    }
    return _placeholderBox(item);
  }

  Widget _placeholderBox(CanvasItem item) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.card, AppColors.accentSecondary, 0.25)!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.type.icon, color: AppColors.textSecondary, size: 26),
          const SizedBox(height: 4),
          Text(
            item.type.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionBorder() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accentSecondary, width: 1.5),
            borderRadius: BorderRadius.circular(widget.item.borderRadius),
          ),
        ),
      ),
    );
  }

  Widget _rotateHandle() {
    return Positioned(
      top: -34,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onPanUpdate: _rotate,
          onPanEnd: (_) => _commit(),
          child: _handleDot(Icons.rotate_right_rounded),
        ),
      ),
    );
  }

  Widget _resizeHandle() {
    return Positioned(
      right: -12,
      bottom: -12,
      child: GestureDetector(
        onPanUpdate: _resize,
        onPanEnd: (_) => _commit(),
        child: _handleDot(Icons.open_in_full_rounded),
      ),
    );
  }

  Widget _handleDot(IconData icon) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.accentSecondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentSecondary.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(icon, size: 13, color: Colors.white),
    );
  }

  // ---- Interactions --------------------------------------------------------

  bool _isTextual(CanvasItem item) =>
      item.type == CanvasItemType.text ||
      item.type == CanvasItemType.watermark;

  void _editText(BuildContext context) {
    Haptics.selection();
    widget.controller.select(widget.item.id);
    TextEditorSheet.show(
      context,
      controller: widget.controller,
      item: widget.item,
    );
  }

  void _move(Offset delta) {
    setState(() {
      widget.controller.update(widget.item.id, (item) {
        final next = item.center +
            Offset(delta.dx / _panel.width, delta.dy / _panel.height);
        item.center = Offset(
          next.dx.clamp(0.0, 1.0),
          next.dy.clamp(0.0, 1.0),
        );
      }, notify: false);
    });
  }

  void _resize(DragUpdateDetails details) {
    setState(() {
      widget.controller.update(widget.item.id, (item) {
        final newW = (_pxSize.width + details.delta.dx).clamp(_minPx, _shortest);
        final newH =
            (_pxSize.height + details.delta.dy).clamp(_minPx, _shortest);
        item.size = Size(newW / _shortest, newH / _shortest);
      }, notify: false);
    });
  }

  void _rotate(DragUpdateDetails details) {
    setState(() {
      widget.controller.update(widget.item.id, (item) {
        // Convert vertical drag on the rotate handle into an angle change.
        item.rotation += details.delta.dx * 0.02;
      }, notify: false);
    });
  }

  void _commit() {
    Haptics.tap();
    // Final notify so the inspector reflects the settled geometry.
    widget.controller.update(widget.item.id, (_) {});
  }
}
