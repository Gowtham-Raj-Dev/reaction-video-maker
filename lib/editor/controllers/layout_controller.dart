import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/split_config.dart';
import '../persistence/layout_store.dart';

enum LayoutMode {
  classic, // Top video, bottom split content/camera
  topVideo, // Top video, bottom camera (70/30)
  topCamera, // Top camera, bottom video (30/70)
  pip, // Picture in picture
}

/// Owns the two divider positions for the editor.
///
/// Design notes for 60fps dragging:
/// * Positions are exposed as [ValueNotifier]s, so a drag only rebuilds the
///   two panels that flex around the divider — never the whole tree.
/// * Snapping / clamping is pure ([SplitConfig]) and runs synchronously per
///   frame, so there is no async jank while dragging.
/// * Persistence is debounced and happens off the drag hot-path.
class LayoutController {
  LayoutController({LayoutStore store = const LayoutStore()}) : _store = store;

  final LayoutStore _store;
  final GlobalKey canvasKey = GlobalKey();

  // ---- Configs (constraints + snap points) --------------------------------

  /// Vertical divider between Video (top / leading) and Bottom section.
  /// Min video height 30%, min bottom height 20%.
  static const videoConfig = SplitConfig(minLeading: 0.30, minTrailing: 0.20);

  /// Horizontal divider between Text (leading) and Camera (trailing).
  /// Min text width 20%, min camera width 20%.
  static const bottomConfig = SplitConfig(minLeading: 0.20, minTrailing: 0.20);

  // ---- Live state ----------------------------------------------------------

  /// Fraction of the canvas height occupied by the video section.
  final ValueNotifier<double> videoSplit = ValueNotifier(0.70);

  /// Fraction of the bottom section width occupied by the text/content panel.
  final ValueNotifier<double> bottomSplit = ValueNotifier(0.50);

  /// Fraction of the canvas width occupied by the PiP camera.
  final ValueNotifier<double> pipSize = ValueNotifier(0.25);

  /// Fraction of the canvas height occupied by the PiP camera.
  final ValueNotifier<double> pipHeight = ValueNotifier(0.35);

  final ValueNotifier<LayoutMode> mode = ValueNotifier(LayoutMode.classic);
  
  /// Fit/Cover mode for the top/main video.
  final ValueNotifier<bool> isTopCover = ValueNotifier(true);

  /// Fit/Cover mode for the bottom reaction video.
  final ValueNotifier<bool> isBottomCover = ValueNotifier(true);

  /// Enable/disable rounded corners for the video panels.
  final ValueNotifier<bool> isRoundedCorners = ValueNotifier(true);
  final ValueNotifier<bool> isOriginalAudio = ValueNotifier(true);

  /// The snap fraction currently engaged for the vertical divider (for the
  /// snap-guide UI). Null when free-dragging.
  final ValueNotifier<double?> videoSnapGuide = ValueNotifier(null);
  final ValueNotifier<double?> bottomSnapGuide = ValueNotifier(null);

  /// Whether a given divider is actively being dragged (drives glow / scale).
  final ValueNotifier<bool> videoDragging = ValueNotifier(false);
  final ValueNotifier<bool> bottomDragging = ValueNotifier(false);

  Timer? _saveDebounce;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ---- Load / persist ------------------------------------------------------

  Future<void> load() async {
    final saved = await _store.load();
    if (saved.videoSplit != null) {
      videoSplit.value = videoConfig.clamp(saved.videoSplit!);
    }
    if (saved.bottomSplit != null) {
      bottomSplit.value = bottomConfig.clamp(saved.bottomSplit!);
    }
    if (saved.mode != null) {
      mode.value = saved.mode!;
    }
    if (saved.isRoundedCorners != null) {
      isRoundedCorners.value = saved.isRoundedCorners!;
    }
    if (saved.isOriginalAudio != null) {
      isOriginalAudio.value = saved.isOriginalAudio!;
    }
    _loaded = true;
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      _store.save(
        videoSplit: SplitConfig.round(videoSplit.value),
        bottomSplit: SplitConfig.round(bottomSplit.value),
        mode: mode.value,
        isRoundedCorners: isRoundedCorners.value,
        isOriginalAudio: isOriginalAudio.value,
      );
    });
  }

  // ---- Drag handlers -------------------------------------------------------

  /// Called on every drag frame. [delta] is the pointer movement expressed as a
  /// fraction of the axis extent. Returns whether a *new* snap point engaged
  /// (so the caller can fire haptics exactly once per snap).
  bool updateVideo(double delta) {
    final raw = videoConfig.clamp(videoSplit.value + delta);
    final snap = videoConfig.snapTarget(raw);
    final engagedNew = snap != null && snap != videoSnapGuide.value;
    videoSnapGuide.value = snap;
    videoSplit.value = snap ?? raw;
    return engagedNew;
  }

  bool updateBottom(double delta) {
    final raw = bottomConfig.clamp(bottomSplit.value + delta);
    final snap = bottomConfig.snapTarget(raw);
    final engagedNew = snap != null && snap != bottomSnapGuide.value;
    bottomSnapGuide.value = snap;
    bottomSplit.value = snap ?? raw;
    return engagedNew;
  }

  void beginVideoDrag() => videoDragging.value = true;
  void beginBottomDrag() => bottomDragging.value = true;

  void endVideoDrag() {
    videoDragging.value = false;
    videoSnapGuide.value = null;
    _scheduleSave();
  }

  void endBottomDrag() {
    bottomDragging.value = false;
    bottomSnapGuide.value = null;
    _scheduleSave();
  }

  /// Programmatically set a split (e.g. from a preset button). Animated by the
  /// widget layer; here we just resolve + persist.
  void setVideoSplit(double fraction) {
    videoSplit.value = videoConfig.resolve(fraction);
    _scheduleSave();
  }

  void setBottomSplit(double fraction) {
    bottomSplit.value = bottomConfig.resolve(fraction);
    _scheduleSave();
  }

  void setMode(LayoutMode newMode) {
    mode.value = newMode;
    if (newMode == LayoutMode.topCamera) {
      videoSplit.value = 0.30; // Top gets 30%, bottom gets 70%
    } else if (newMode == LayoutMode.pip) {
      videoSplit.value = 1.0;
    } else {
      // For classic and topVideo modes, top gets 70%
      videoSplit.value = 0.70;
    }
    _scheduleSave();
  }

  void toggleRoundedCorners() {
    isRoundedCorners.value = !isRoundedCorners.value;
    _scheduleSave();
  }

  void toggleOriginalAudio() {
    isOriginalAudio.value = !isOriginalAudio.value;
    _scheduleSave();
  }

  void resetToDefault() {
    videoSplit.value = 0.70;
    bottomSplit.value = 0.50;
    mode.value = LayoutMode.classic;
    isRoundedCorners.value = true;
    isOriginalAudio.value = true;
    _scheduleSave();
  }

  void dispose() {
    _saveDebounce?.cancel();
    videoSplit.dispose();
    bottomSplit.dispose();
    pipSize.dispose();
    pipHeight.dispose();
    mode.dispose();
    isTopCover.dispose();
    isBottomCover.dispose();
    isRoundedCorners.dispose();
    isOriginalAudio.dispose();
    videoSnapGuide.dispose();
    bottomSnapGuide.dispose();
    videoDragging.dispose();
    bottomDragging.dispose();
  }
}
