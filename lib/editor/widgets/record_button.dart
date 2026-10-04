import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/layout_controller.dart';
import '../controllers/recorder_controller.dart';

/// The prominent circular record button. Starts / stops recording the live
/// camera through the shared [RecorderController] and pulses while recording.
class RecordButton extends StatefulWidget {
  const RecordButton({super.key});

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<RecorderController>();
    final recording = recorder.recording;
    final enabled = recorder.ready;

    return GestureDetector(
      onTap: enabled
          ? () async {
              Haptics.heavy();
              final recorderCtrl = context.read<RecorderController>();
              final layout = context.read<LayoutController>();

              await recorderCtrl.toggleRecording(context: context, layout: layout);
            }
          : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = recording ? (0.4 + 0.4 * _pulse.value) : 0.35;
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassFill,
              border: Border.all(
                color: enabled ? Colors.white : AppColors.strokeStrong,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: glow),
                  blurRadius: recording ? 28 : 18,
                  spreadRadius: recording ? 2 : 0,
                ),
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: AppSpacing.medium,
                curve: AppSpacing.spring,
                width: recording ? 28 : 54,
                height: recording ? 28 : 54,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.accent : AppColors.textMuted,
                  borderRadius:
                      BorderRadius.circular(recording ? 8 : 100),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
