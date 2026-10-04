import 'package:flutter/material.dart';

/// Centralised premium color palette for the whole app.
///
/// The values map 1:1 to the design spec so that every screen shares the
/// exact same tones. Prefer referencing these constants instead of hard
/// coding hex values inside widgets.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0B0B0B);
  static const Color surface = Color(0xFF151515);
  static const Color card = Color(0xFF1F1F1F);

  // Accents
  static const Color accent = Color(0xFFFF3B30);
  static const Color accentSecondary = Color(0xFF6C63FF);

  // Semantic
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);

  // Neutrals derived for text / strokes.
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9A9AA2);
  static const Color textMuted = Color(0xFF5C5C66);
  static const Color stroke = Color(0x1AFFFFFF); // 10% white
  static const Color strokeStrong = Color(0x33FFFFFF); // 20% white

  /// Signature brand gradient used on primary actions and highlights.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFFF6A3D)],
  );

  /// Cool secondary gradient for creative accents.
  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentSecondary, Color(0xFF8E7BFF)],
  );

  /// Subtle glassmorphism fill for floating panels.
  static const Color glassFill = Color(0x14FFFFFF); // ~8% white
  static const Color glassFillStrong = Color(0x24FFFFFF);

  /// Elegant vignette used behind the recording canvas.
  static const RadialGradient canvasBackdrop = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.4,
    colors: [Color(0xFF1A1A20), Color(0xFF0B0B0B)],
  );
}
