import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] so haptics can be globally toggled and
/// so call sites read clearly (`Haptics.snap()` instead of raw platform calls).
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Fired when a divider locks onto a snap point.
  static void snap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void tap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
