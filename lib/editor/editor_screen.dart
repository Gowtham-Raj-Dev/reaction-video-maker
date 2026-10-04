import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/haptics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'controllers/canvas_controller.dart';
import 'controllers/layout_controller.dart';
import 'controllers/media_controller.dart';
import 'controllers/recorder_controller.dart';
import 'models/canvas_item.dart';
import 'widgets/add_content_sheet.dart';
import 'widgets/record_button.dart';
import 'widgets/text_editor_sheet.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/export_sheet.dart';
import 'widgets/item_inspector.dart';
import 'widgets/layout_presets_sheet.dart';
import 'widgets/recording_canvas.dart';

/// The main editing workspace. Composes the recording canvas, the floating
/// inspector and the glass toolbar, and owns the smooth animated transitions
/// used when applying layout presets.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.layout});

  final LayoutController layout;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  bool _previewing = false;

  // One live animation per divider so the two can animate at once (e.g. reset).
  final Map<ValueNotifier<double>, AnimationController> _presetAnims = {};

  LayoutController get layout => widget.layout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recorder = context.read<RecorderController>();
      bool wasRecording = recorder.recording;

      recorder.addListener(() {
        if (!mounted) return;
        final isRecording = recorder.recording;
        if (wasRecording && !isRecording) {
          final mediaCtrl = context.read<MediaController>();
          if (mediaCtrl.hasVideo) {
            mediaCtrl.setPlaying(false);
          }
          if (recorder.lastRecordingPath != null && recorder.error == null) {
            ExportSheet.show(context).then((_) {
              // Automatically reset studio after export is done
              if (mounted) {
                context.read<MediaController>().clearVideo();
                context.read<CanvasController>().clear();
                context.read<RecorderController>().clearRecording();
                layout.resetToDefault();
              }
            });
          } else if (recorder.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(recorder.error!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
        wasRecording = isRecording;
      });
    });
  }

  @override
  void dispose() {
    for (final c in _presetAnims.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Smoothly animates a divider [notifier] to [target].
  void _animateSplit(ValueNotifier<double> notifier, double target) {
    _presetAnims.remove(notifier)?.dispose();
    final from = notifier.value;
    final controller = AnimationController(
      vsync: this,
      duration: AppSpacing.medium,
    );
    final anim = CurvedAnimation(parent: controller, curve: AppSpacing.spring);
    anim.addListener(() {
      notifier.value = from + (target - from) * anim.value;
    });
    controller.forward().whenComplete(() {
      notifier.value = target;
      _presetAnims.remove(notifier);
      controller.dispose();
    });
    _presetAnims[notifier] = controller;
  }

  Future<void> _openAdd() async {
    final canvas = context.read<CanvasController>();
    canvas.add(CanvasItemType.text);

    // Immediately open the text editor so the user can type.
    final item = canvas.selected;
    if (item != null) {
      await TextEditorSheet.show(context, controller: canvas, item: item);
    }
  }

  void _openLayout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LayoutPresetsSheet(
        currentMode: layout.mode.value,
        onSelectMode: (mode) {
          layout.setMode(mode);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _togglePreview() {
    Haptics.heavy();
    setState(() => _previewing = !_previewing);
    if (_previewing) context.read<CanvasController>().select(null);
  }

  void _resetAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Reset Studio?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This will clear your uploaded videos, layouts, and all elements. This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<MediaController>().clearVideo();
              context.read<CanvasController>().clear();
              context.read<RecorderController>().clearRecording();
              layout.resetToDefault();
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecorderController>().recording;

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Features',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: context.read<LayoutController>().isOriginalAudio,
                builder: (context, isAudioEnabled, _) {
                  return ListTile(
                    leading: Icon(
                      isAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, 
                      color: AppColors.textPrimary
                    ),
                    title: Text(
                      isAudioEnabled ? 'Export Original Audio: ON' : 'Export Original Audio: OFF', 
                      style: const TextStyle(color: AppColors.textPrimary)
                    ),
                    subtitle: const Text(
                      'Turn OFF if you did not use headphones, to prevent double audio (echo).',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    onTap: () {
                      context.read<LayoutController>().toggleOriginalAudio();
                    },
                  );
                },
              ),
              const Divider(color: AppColors.strokeStrong),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textPrimary),
                title: const Text('Add Element', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openAdd();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_customize_rounded, color: AppColors.textPrimary),
                title: const Text('Layout Settings', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openLayout();
                },
              ),
              ListTile(
                leading: Icon(_previewing ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textPrimary),
                title: Text(_previewing ? 'Exit Preview' : 'Show Preview', style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _togglePreview();
                },
              ),
              const Divider(color: AppColors.strokeStrong),
              ListTile(
                leading: const Icon(Icons.flip_camera_android_rounded, color: AppColors.textPrimary),
                title: const Text('Flip Camera', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<RecorderController>().flipCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flip_rounded, color: AppColors.textPrimary),
                title: const Text('Mirror Camera', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<RecorderController>().toggleMirror();
                },
              ),
              ListTile(
                leading: Icon(
                  context.watch<RecorderController>().useCountdown ? Icons.timer_rounded : Icons.timer_off_rounded, 
                  color: AppColors.textPrimary
                ),
                title: Text(
                  context.watch<RecorderController>().useCountdown ? 'Countdown: ON (3s)' : 'Countdown: OFF', 
                  style: const TextStyle(color: AppColors.textPrimary)
                ),
                onTap: () {
                  context.read<RecorderController>().toggleCountdown();
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: context.read<LayoutController>().isRoundedCorners,
                builder: (context, isRounded, _) {
                  return ListTile(
                    leading: Icon(
                      isRounded ? Icons.rounded_corner_rounded : Icons.crop_square_rounded, 
                      color: AppColors.textPrimary
                    ),
                    title: Text(
                      isRounded ? 'Rounded Corners: ON' : 'Rounded Corners: OFF', 
                      style: const TextStyle(color: AppColors.textPrimary)
                    ),
                    onTap: () {
                      context.read<LayoutController>().toggleRoundedCorners();
                    },
                  );
                },
              ),
              const Divider(color: AppColors.strokeStrong),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, color: AppColors.accent),
                title: const Text('Export Video', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  ExportSheet.show(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: AppColors.error),
                title: const Text('Reset All', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _resetAll();
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.canvasBackdrop),
        child: SafeArea(
          child: Column(
            children: [
              if (!_previewing && !recording)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: _EditorAppBar(
                  onAdd: _openAdd,
                  onLayout: _openLayout,
                  onPreview: _togglePreview,
                  onExport: () => ExportSheet.show(context),
                  onReset: _resetAll,
                  previewing: _previewing,
                  mode: context.watch<LayoutController>().mode.value,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _buildCanvas(recording),
                    if (!_previewing)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Selector<CanvasController, CanvasItem?>(
                          selector: (_, c) => c.selected,
                          builder: (context, item, _) {
                            if (item == null) return const SizedBox.shrink();
                            return Center(
                              child: ItemInspector(
                                controller: context.read<CanvasController>(),
                                item: item,
                              ),
                            );
                          },
                        ),
                      ),
                    _buildFloatingControls(recording),
                    if (_previewing) _buildPreviewExit(),
                    _buildCountdownOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCanvas(bool recording) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        _previewing ? 0 : 8,
        8,
        _previewing ? 0 : 8,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<LayoutMode>(
          valueListenable: layout.mode,
          builder: (context, mode, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: layout.isRoundedCorners,
              builder: (context, isRounded, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isPip = mode == LayoutMode.pip;
                    final ratio = isPip ? 16 / 9 : 9 / 16;
                var width = constraints.maxWidth;
                var height = width / ratio;
                if (height > constraints.maxHeight) {
                  height = constraints.maxHeight;
                  width = height * ratio;
                }
                final radius = isRounded ? BorderRadius.circular(24) : BorderRadius.zero;
                return AnimatedContainer(
                  duration: AppSpacing.medium,
                  curve: AppSpacing.easeEmphasized,
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      if (!_previewing && !recording)
                        BoxShadow(
                          color: AppColors.accentSecondary.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: -10,
                          offset: const Offset(0, 20),
                        ),
                      if (!_previewing && !recording)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                    RecordingCanvas(
                      layout: layout,
                      editorMode: !_previewing && !recording,
                    ),
                    if (!_previewing && !recording)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.all(
                                color: AppColors.strokeStrong,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
      },
    ),
      ),
    );
  }

  Widget _buildFloatingControls(bool recording) {
    if (_previewing) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: ValueListenableBuilder<LayoutMode>(
          valueListenable: layout.mode,
          builder: (context, mode, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mode == LayoutMode.pip)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassFillStrong,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.strokeStrong),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text('Width', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: layout.pipSize,
                                  builder: (context, size, _) {
                                    return Slider(
                                      value: size,
                                      min: 0.15,
                                      max: 0.50,
                                      activeColor: AppColors.accentSecondary,
                                      inactiveColor: AppColors.strokeStrong,
                                      onChanged: (v) => layout.pipSize.value = v,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Height', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: layout.pipHeight,
                                  builder: (context, size, _) {
                                    return Slider(
                                      value: size,
                                      min: 0.15,
                                      max: 0.60,
                                      activeColor: AppColors.accent,
                                      inactiveColor: AppColors.strokeStrong,
                                      onChanged: (v) => layout.pipHeight.value = v,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const RecordButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewExit() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GestureDetector(
          onTap: _togglePreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.strokeStrong, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 10),
                    Text(
                      'Exit preview',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    final countdown = context.watch<RecorderController>().countdownValue;
    if (countdown == 0) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(countdown),
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                '$countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.onAdd,
    required this.onLayout,
    required this.onPreview,
    required this.onExport,
    required this.onReset,
    required this.previewing,
    required this.mode,
  });

  final VoidCallback onAdd;
  final VoidCallback onLayout;
  final VoidCallback onPreview;
  final VoidCallback onExport;
  final VoidCallback onReset;
  final bool previewing;
  final LayoutMode mode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.strokeStrong, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reaction Studio',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'PRO EDITOR',
                      style: TextStyle(
                        color: AppColors.accentSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary, size: 22),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
