import 'dart:math' as math;

/// Immutable configuration describing constraints + snapping behaviour for a
/// single draggable divider. Keeping this separate from the mutable controller
/// makes the snapping logic trivial to unit-test.
class SplitConfig {
  const SplitConfig({
    required this.minLeading,
    required this.minTrailing,
    this.snapPoints = defaultSnapPoints,
    this.snapThreshold = 0.02,
  });

  /// Minimum fraction (0..1) the leading section may occupy.
  final double minLeading;

  /// Minimum fraction (0..1) the trailing section may occupy.
  final double minTrailing;

  /// Fractions the divider magnetically snaps to.
  final List<double> snapPoints;

  /// How close (in fraction units) to a snap point before it engages.
  final double snapThreshold;

  /// Design-spec snap points: 25/33/40/50/60/66/75/80/90 %.
  static const List<double> defaultSnapPoints = [
    0.25,
    0.33,
    0.40,
    0.50,
    0.60,
    0.66,
    0.75,
    0.80,
    0.90,
  ];

  /// Clamps [fraction] so both sections respect their minimum sizes.
  double clamp(double fraction) {
    return fraction.clamp(minLeading, 1 - minTrailing);
  }

  /// Returns the snap point within [snapThreshold] of [fraction], or `null` if
  /// the divider is in free-drag territory. Only snap points that also satisfy
  /// the min-size constraints are considered.
  double? snapTarget(double fraction) {
    double? best;
    double bestDistance = snapThreshold;
    for (final point in snapPoints) {
      if (point < minLeading || point > 1 - minTrailing) continue;
      final distance = (point - fraction).abs();
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }
    return best;
  }

  /// Applies clamping and, when close enough, snapping in a single call.
  double resolve(double fraction) {
    final clamped = clamp(fraction);
    return snapTarget(clamped) ?? clamped;
  }

  /// Rounds to the nearest hundredth for tidy persistence / display.
  static double round(double v) => (v * 100).roundToDouble() / 100;

  static double lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);

  static double distanceToNearestSnap(double fraction, List<double> points) {
    double best = double.infinity;
    for (final p in points) {
      best = math.min(best, (p - fraction).abs());
    }
    return best;
  }
}
