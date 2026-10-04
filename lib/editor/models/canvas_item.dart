import 'package:flutter/material.dart';

/// The kinds of content a user can drop into the editable content panel.
enum CanvasItemType {
  text,
  image,
  logo,
  sticker,
  gif,
  qrCode,
  emoji,
  socialIcon,
  watermark,
}

extension CanvasItemTypeX on CanvasItemType {
  String get label => switch (this) {
        CanvasItemType.text => 'Text',
        CanvasItemType.image => 'Image',
        CanvasItemType.logo => 'Logo',
        CanvasItemType.sticker => 'Sticker',
        CanvasItemType.gif => 'GIF',
        CanvasItemType.qrCode => 'QR Code',
        CanvasItemType.emoji => 'Emoji',
        CanvasItemType.socialIcon => 'Social',
        CanvasItemType.watermark => 'Watermark',
      };

  IconData get icon => switch (this) {
        CanvasItemType.text => Icons.title_rounded,
        CanvasItemType.image => Icons.image_rounded,
        CanvasItemType.logo => Icons.workspace_premium_rounded,
        CanvasItemType.sticker => Icons.emoji_emotions_rounded,
        CanvasItemType.gif => Icons.gif_box_rounded,
        CanvasItemType.qrCode => Icons.qr_code_2_rounded,
        CanvasItemType.emoji => Icons.mood_rounded,
        CanvasItemType.socialIcon => Icons.alternate_email_rounded,
        CanvasItemType.watermark => Icons.branding_watermark_rounded,
      };
}

/// A single editable overlay item.
///
/// Positions and sizes are stored as fractions (0..1) of the content panel so
/// items stay correctly placed when the panel is resized by dragging dividers.
class CanvasItem {
  CanvasItem({
    required this.id,
    required this.type,
    required this.center,
    required this.size,
    this.rotation = 0,
    this.opacity = 1,
    this.borderRadius = 8,
    this.hasShadow = false,
    this.locked = false,
    this.text = '',
    this.assetPath,
    this.color = Colors.white,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w700,
  });

  final String id;
  final CanvasItemType type;

  /// Center position as a fraction of the panel (0..1, 0..1).
  Offset center;

  /// Size as a fraction of the panel's shortest side.
  Size size;

  double rotation; // radians
  double opacity; // 0..1
  double borderRadius;
  bool hasShadow;
  bool locked;

  // Text-specific
  String text;
  Color color;
  double fontSize;
  FontWeight fontWeight;

  // Media-specific
  String? assetPath;

  CanvasItem copyWith({
    String? id,
    Offset? center,
    Size? size,
    double? rotation,
    double? opacity,
  }) {
    return CanvasItem(
      id: id ?? this.id,
      type: type,
      center: center ?? this.center,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      borderRadius: borderRadius,
      hasShadow: hasShadow,
      locked: locked,
      text: text,
      assetPath: assetPath,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }
}
