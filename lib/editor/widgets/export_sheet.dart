import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/media_controller.dart';
import '../controllers/recorder_controller.dart';
import '../controllers/layout_controller.dart';
import '../controllers/canvas_controller.dart';
import '../persistence/file_saver.dart';
import '../persistence/video_merger.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'premium_button.dart';

enum _ExportPhase { working, success, nothing, failed }

/// Export dialog that actually saves a video file to the device gallery.
///
/// It saves the recorded reaction clip (preferred) or, if none was recorded,
/// the uploaded video. Full compositing of video + camera + overlays into a
/// single frame is done dynamically on Web.
class ExportSheet extends StatefulWidget {
  const ExportSheet({
    super.key,
    required this.sourcePath,
    required this.videoPath,
    required this.reactionPath,
    required this.videoSplit,
    required this.bottomSplit,
    required this.pipSize,
    required this.pipHeight,
    required this.items,
    required this.videoDuration,
    required this.isMirrored,
    required this.mode,
    required this.previewAspect,
    required this.isFrontCamera,
    required this.isTopCover,
    required this.isBottomCover,
    required this.isRoundedCorners,
    required this.isOriginalAudio,
  });

  final String? sourcePath;
  final String? videoPath;
  final String? reactionPath;
  final double videoSplit;
  final double bottomSplit;
  final double pipSize;
  final double pipHeight;
  final List<dynamic> items;
  final Duration? videoDuration;
  final bool isMirrored;
  final LayoutMode mode;
  final double previewAspect;
  final bool isFrontCamera;
  final bool isTopCover;
  final bool isBottomCover;
  final bool isRoundedCorners;
  final bool isOriginalAudio;

  static Future<void> show(BuildContext context) {
    // Prefer the recorded reaction; fall back to the uploaded clip.
    final recorder = context.read<RecorderController>();
    final media = context.read<MediaController>();
    final layout = context.read<LayoutController>();
    final canvas = context.read<CanvasController>();

    final recording = recorder.lastRecordingPath;
    final uploaded = media.videoPath;
    
    final source = recording ?? uploaded;

    final previewSize = recorder.camera?.value.previewSize;
    double previewAspect = 9 / 16;
    if (previewSize != null) {
      previewAspect = previewSize.height / previewSize.width;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => ExportSheet(
        sourcePath: source,
        videoPath: uploaded,
        reactionPath: recording,
        videoSplit: layout.videoSplit.value,
        bottomSplit: layout.bottomSplit.value,
        pipSize: layout.pipSize.value,
        pipHeight: layout.pipHeight.value,
        items: canvas.items,
        videoDuration: media.videoDuration,
        isMirrored: recorder.isMirrored,
        mode: layout.mode.value,
        previewAspect: previewAspect,
        isFrontCamera: recorder.isFrontCamera,
        isTopCover: layout.isTopCover.value,
        isBottomCover: layout.isBottomCover.value,
        isRoundedCorners: layout.isRoundedCorners.value,
        isOriginalAudio: layout.isOriginalAudio.value,
      ),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  _ExportPhase _phase = _ExportPhase.working;
  String? _message;
  String? _finalVideoPath;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final path = widget.sourcePath;
    if (path == null || (!kIsWeb && !File(path).existsSync())) {
      setState(() {
        _phase = _ExportPhase.nothing;
        _message =
            'Record your reaction or upload a video first, then export.';
      });
      return;
    }
    try {
      String finalPath = path;

      if (widget.videoPath != null && widget.reactionPath != null) {
        setState(() {
          _message = 'Generating combined reaction video... This might take a few seconds.';
        });

        double videoDurSec = widget.videoDuration?.inMilliseconds != null
            ? widget.videoDuration!.inMilliseconds / 1000.0
            : 15.0;
            
        double reactionDurSec = videoDurSec;
        try {
          final session = await FFprobeKit.getMediaInformation(widget.reactionPath!);
          final info = session.getMediaInformation();
          if (info != null) {
            final durStr = info.getDuration();
            if (durStr != null) {
              double parsed = double.tryParse(durStr) ?? videoDurSec;
              if (parsed > 0.1) {
                reactionDurSec = parsed;
              }
            }
          }
        } catch (_) {}
        
        // Use exact video duration so the uploaded video is never cut off
        double durationSec = videoDurSec;
        if (durationSec < 1.0) durationSec = 1.0; // Prevent 0.000s duration crash!

        finalPath = await mergeVideos(
          videoPath: widget.videoPath!,
          reactionPath: widget.reactionPath!,
          videoSplit: widget.videoSplit,
          bottomSplit: widget.bottomSplit,
          pipSize: widget.pipSize,
          pipHeight: widget.pipHeight,
          items: widget.items,
          durationSec: durationSec,
          isMirrored: widget.isMirrored,
          mode: widget.mode,
          previewAspect: widget.previewAspect,
          isFrontCamera: widget.isFrontCamera,
          isTopCover: widget.isTopCover,
          isBottomCover: widget.isBottomCover,
          isRoundedCorners: widget.isRoundedCorners,
          isOriginalAudio: widget.isOriginalAudio,
          onProgress: (percent) {
            if (mounted) {
              setState(() {
                _message = 'Exporting: ${(percent * 100).toInt()}%';
              });
            }
          },
        );
      }

      await saveVideoFile(finalPath);
      if (!mounted) return;
      setState(() {
        _phase = _ExportPhase.success;
        _finalVideoPath = finalPath;
        _message = kIsWeb
            ? 'Reaction video downloaded successfully.'
            : 'Saved to your gallery in “Reaction Studio”.';
      });
    } catch (e, stackTrace) {
        print("====== FFMPEG ERROR ======");
        print(e);
        print(stackTrace);
        print("==========================");
        if (!mounted) return;
        setState(() {
          _phase = _ExportPhase.failed;
          String errStr = e.toString();
          if (errStr.length > 400) {
            errStr = "..." + errStr.substring(errStr.length - 400);
          }
          _message = 'Could not save: $errStr';
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    final working = _phase == _ExportPhase.working;
    final success = _phase == _ExportPhase.success;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            _icon(),
            const SizedBox(height: 18),
            Text(
              _title(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _message ?? 'Saving your reaction video…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            if (working)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                ),
              )
            else
              PremiumButton(
                label: success ? 'Done' : 'Close',
                icon: success ? Icons.check_rounded : Icons.close_rounded,
                gradient: success
                    ? const LinearGradient(
                        colors: [AppColors.success, Color(0xFF3DDC84)])
                    : AppColors.brandGradient,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title() => switch (_phase) {
        _ExportPhase.working => 'Exporting…',
        _ExportPhase.success => 'Export saved',
        _ExportPhase.nothing => 'Nothing to export yet',
        _ExportPhase.failed => 'Export failed',
      };

  Widget _icon() {
    final (icon, gradient) = switch (_phase) {
      _ExportPhase.success => (
          Icons.check_rounded,
          const LinearGradient(colors: [AppColors.success, Color(0xFF3DDC84)])
        ),
      _ExportPhase.failed => (
          Icons.error_outline_rounded,
          const LinearGradient(colors: [AppColors.error, Color(0xFFFF6A5A)])
        ),
      _ExportPhase.nothing => (
          Icons.video_library_outlined,
          AppColors.violetGradient
        ),
      _ExportPhase.working => (
          Icons.movie_filter_rounded,
          AppColors.brandGradient
        ),
    };
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
