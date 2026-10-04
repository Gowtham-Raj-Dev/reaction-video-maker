import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/layout_controller.dart';

/// Persists the user's last divider positions so the exact layout is restored
/// on the next launch. Values are stored as plain fractions (0..1).
class LayoutStore {
  static const _kVideoSplit = 'layout.videoSplit';
  static const _kBottomSplit = 'layout.bottomSplit';
  static const _kMode = 'layout.mode';
  static const _kRoundedCorners = 'layout.roundedCorners';
  static const _kOriginalAudio = 'layout.originalAudio';

  const LayoutStore();

  Future<({double? videoSplit, double? bottomSplit, LayoutMode? mode, bool? isRoundedCorners, bool? isOriginalAudio})> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    LayoutMode? loadedMode;
    final modeStr = prefs.getString(_kMode);
    if (modeStr != null) {
      loadedMode = LayoutMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => LayoutMode.classic,
      );
    }

    return (
      videoSplit: prefs.getDouble(_kVideoSplit),
      bottomSplit: prefs.getDouble(_kBottomSplit),
      mode: loadedMode,
      isRoundedCorners: prefs.getBool(_kRoundedCorners),
      isOriginalAudio: prefs.getBool(_kOriginalAudio),
    );
  }

  Future<void> save({
    required double videoSplit,
    required double bottomSplit,
    required LayoutMode mode,
    required bool isRoundedCorners,
    required bool isOriginalAudio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVideoSplit, videoSplit);
    await prefs.setDouble(_kBottomSplit, bottomSplit);
    await prefs.setString(_kMode, mode.name);
    await prefs.setBool(_kRoundedCorners, isRoundedCorners);
    await prefs.setBool(_kOriginalAudio, isOriginalAudio);
  }
}
