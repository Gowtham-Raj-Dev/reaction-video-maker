import 'package:flutter_test/flutter_test.dart';

import 'package:reaction_video_maker/editor/models/split_config.dart';

void main() {
  group('SplitConfig snapping & constraints', () {
    const config = SplitConfig(minLeading: 0.30, minTrailing: 0.20);

    test('clamps to min leading / trailing', () {
      expect(config.clamp(0.05), 0.30);
      expect(config.clamp(0.95), 0.80);
      expect(config.clamp(0.5), 0.5);
    });

    test('snaps to nearby snap points within threshold', () {
      expect(config.snapTarget(0.505), 0.50);
      expect(config.snapTarget(0.60), 0.60);
    });

    test('does not snap in free-drag territory', () {
      expect(config.snapTarget(0.555), isNull);
    });

    test('resolve respects the min-size envelope over snapping', () {
      // 0.90 is a snap point but violates minTrailing (0.20), so a large
      // fraction clamps to 0.80 instead of snapping past the minimum.
      expect(config.resolve(0.95), 0.80);
    });
  });
}
