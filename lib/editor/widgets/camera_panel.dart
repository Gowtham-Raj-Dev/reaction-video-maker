import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/recorder_controller.dart';
import 'panel_frame.dart';

/// Live camera preview section. Uses the shared [RecorderController] so the
/// floating record button controls the very same camera. Shows a premium
/// animated loading / permission state while the camera is unavailable.
class CameraPanel extends StatefulWidget {
  const CameraPanel({super.key, this.editorMode = true});

  final bool editorMode;

  @override
  State<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<CameraPanel> {
  @override
  void initState() {
    super.initState();
    // Kick off camera init once, after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecorderController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<RecorderController>();
    final controller = recorder.camera;
    return PanelFrame(
      icon: Icons.videocam_rounded,
      label: 'Camera',
      editorMode: widget.editorMode,
      accent: AppColors.accent.withValues(alpha: 0.35),
      child: recorder.ready
          ? _PreviewWithGlow(
              controller: controller!,
              recording: recorder.recording,
              isMirrored: recorder.isMirrored,
            )
          : _CameraPlaceholder(error: recorder.error),
    );
  }
}

class _PreviewWithGlow extends StatelessWidget {
  const _PreviewWithGlow({required this.controller, required this.recording, required this.isMirrored});
  final CameraController controller;
  final bool recording;
  final bool isMirrored;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1080,
            height: controller.value.previewSize?.width ?? 1920,
            child: isMirrored
                ? Transform.scale(
                    scaleX: -1,
                    child: CameraPreview(controller),
                  )
                : CameraPreview(controller),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x33000000), Colors.transparent],
            ),
          ),
        ),
        if (recording)
          const Positioned(
            top: 10,
            right: 10,
            child: _RecBadge(),
          ),
      ],
    );
  }
}

class _RecBadge extends StatefulWidget {
  const _RecBadge();

  @override
  State<_RecBadge> createState() => _RecBadgeState();
}

class _RecBadgeState extends State<_RecBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _anim,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('REC',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatefulWidget {
  const _CameraPlaceholder({this.error});
  final String? error;

  @override
  State<_CameraPlaceholder> createState() => _CameraPlaceholderState();
}

class _CameraPlaceholderState extends State<_CameraPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.error != null;
    return Container(
      color: AppColors.card,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(_anim),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Icon(
                    isError
                        ? Icons.no_photography_rounded
                        : Icons.photo_camera_front_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  isError ? widget.error! : 'Starting camera…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isError) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    context.read<RecorderController>().init();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Retry / Allow Camera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
