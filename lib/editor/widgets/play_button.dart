import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/media_controller.dart';
import '../controllers/recorder_controller.dart';

/// The overall Play / Pause button that drives the whole preview (currently the
/// uploaded video). In addition, when recording is active, it controls the pause/resume
/// states of both the video playback and the camera/screen recorder.
class OverallPlayButton extends StatelessWidget {
  const OverallPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaController>();
    final recorder = context.watch<RecorderController>();
    final enabled = media.hasVideo || recorder.recording;
    final playing = recorder.recording ? !recorder.paused : media.isPlaying;

    return GestureDetector(
      onTap: enabled
          ? () async {
              Haptics.heavy();
              final mediaCtrl = context.read<MediaController>();
              final recorderCtrl = context.read<RecorderController>();

              if (recorderCtrl.recording) {
                if (recorderCtrl.paused) {
                  if (mediaCtrl.hasVideo && !mediaCtrl.isPlaying) {
                    mediaCtrl.setPlaying(true);
                  }
                  await recorderCtrl.resumeRecording();
                } else {
                  if (mediaCtrl.isPlaying) {
                    mediaCtrl.setPlaying(false);
                  }
                  await recorderCtrl.pauseRecording();
                }
              } else {
                mediaCtrl.togglePlay();
              }
            }
          : null,
      child: AnimatedContainer(
        duration: AppSpacing.fast,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.glassFill,
          border: Border.all(
            color: enabled ? AppColors.strokeStrong : AppColors.stroke,
            width: 2,
          ),
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          size: 30,
        ),
      ),
    );
  }
}
