import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/layout_controller.dart';
import '../controllers/media_controller.dart';
import 'panel_frame.dart';
import 'premium_button.dart';

enum _VideoStatus { empty, loading, ready, error }

/// The top canvas section that plays the uploaded reaction video, with a
/// premium animated empty state, an explicit loading state, and a clear error
/// state if a clip can't be decoded.
class VideoPanel extends StatefulWidget {
  const VideoPanel({
    super.key,
    this.editorMode = true,
    this.isBottomVideo = false,
  });

  final bool editorMode;
  final bool isBottomVideo;

  @override
  State<VideoPanel> createState() => _VideoPanelState();
}

class _VideoPanelState extends State<VideoPanel> {
  VideoPlayerController? _controller;
  String? _loadedPath;
  _VideoStatus _status = _VideoStatus.empty;
  int _lastResetCount = 0;
  MediaController? _mediaCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = context.watch<MediaController>();
    
    if (_mediaCtrl != media) {
      _mediaCtrl?.removeListener(_onMediaChanged);
      _mediaCtrl = media;
      _mediaCtrl?.addListener(_onMediaChanged);
    }

    final path = widget.isBottomVideo ? media.bottomVideoPath : media.videoPath;
    _syncController(path);

    if (_lastResetCount != media.resetRequestCount) {
      _lastResetCount = media.resetRequestCount;
      _controller?.seekTo(Duration.zero);
    }
  }

  void _onMediaChanged() {
    final media = _mediaCtrl;
    if (media == null) return;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      if (media.isPlaying && !c.value.isPlaying) {
        c.play();
      } else if (!media.isPlaying && c.value.isPlaying) {
        c.pause();
      }
    }
  }

  @override
  void dispose() {
    _mediaCtrl?.removeListener(_onMediaChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _syncController(String? path) async {
    if (path == _loadedPath) return;
    _loadedPath = path;
    await _controller?.dispose();
    _controller = null;

    if (path == null) {
      _setStatus(_VideoStatus.empty);
      return;
    }

    _setStatus(_VideoStatus.loading);
    final VideoPlayerController controller;
    if (kIsWeb) {
      controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      controller = VideoPlayerController.file(File(path));
    }
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      // NOTE: do not auto-play — playback is driven by the global Play button.
    } catch (_) {
      await controller.dispose();
      _setStatus(_VideoStatus.error);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _status = _VideoStatus.ready;
    });
  }

  void _setStatus(_VideoStatus s) {
    if (!mounted) return;
    setState(() => _status = s);
  }


  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaController>();
    final controller = _controller;

    Widget body;
    switch (_status) {
      case _VideoStatus.ready when controller != null:
        body = _VideoSurface(
          controller: controller,
          editorMode: widget.editorMode,
          isBottomVideo: widget.isBottomVideo,
          playing: media.isPlaying,
          onTogglePlay: () => context.read<MediaController>().togglePlay(),
          onReplace: () => widget.isBottomVideo
              ? context.read<MediaController>().pickBottomVideo()
              : context.read<MediaController>().pickVideo(),
        );
      case _VideoStatus.loading:
        body = const _LoadingState();
      case _VideoStatus.error:
        body = _ErrorState(
          onRetry: () => widget.isBottomVideo
              ? context.read<MediaController>().pickBottomVideo()
              : context.read<MediaController>().pickVideo(),
        );
      default:
        body = _EmptyVideoState(
          loading: media.picking,
          isBottomVideo: widget.isBottomVideo,
          onUpload: () => widget.isBottomVideo
              ? context.read<MediaController>().pickBottomVideo()
              : context.read<MediaController>().pickVideo(),
        );
    }

    return PanelFrame(
      icon: widget.isBottomVideo ? Icons.video_library_rounded : Icons.movie_creation_rounded,
      label: widget.isBottomVideo ? 'Reaction Video' : 'Uploaded Video',
      editorMode: widget.editorMode,
      child: body,
    );
  }
}

class _VideoSurface extends StatefulWidget {
  const _VideoSurface({
    required this.controller,
    required this.editorMode,
    required this.isBottomVideo,
    required this.playing,
    required this.onTogglePlay,
    required this.onReplace,
  });

  final VideoPlayerController controller;
  final bool editorMode;
  final bool isBottomVideo;
  final bool playing;
  final VoidCallback onTogglePlay;
  final VoidCallback onReplace;

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface> {
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _pan = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final layout = context.watch<LayoutController>();
    final isCover = widget.isBottomVideo ? layout.isBottomCover.value : layout.isTopCover.value;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        ClipRect(
          child: Transform.translate(
            offset: _pan,
            child: Transform.scale(
              scale: _scale,
              child: FittedBox(
                fit: isCover ? BoxFit.cover : BoxFit.contain,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: widget.controller.value.size.width,
                  height: widget.controller.value.size.height,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              Haptics.selection();
              widget.onReplace();
            },
            onScaleStart: (details) {
              _baseScale = _scale;
            },
            onScaleUpdate: (details) {
              if (!widget.editorMode) return;
              setState(() {
                _pan += details.focalPointDelta;
                _scale = (_baseScale * details.scale).clamp(1.0, 5.0);
              });
            },
          ),
        ),
        if (widget.editorMode)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.controller.value.duration.inSeconds} sec',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.editorMode)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                if (widget.isBottomVideo) {
                  layout.isBottomCover.value = !layout.isBottomCover.value;
                } else {
                  layout.isTopCover.value = !layout.isTopCover.value;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isCover ? Icons.fit_screen_rounded : Icons.crop_free_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      isCover ? 'Cover' : 'Fit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.accentSecondary),
              ),
            ),
            SizedBox(height: 12),
            Text('Loading video…',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.warning, size: 34),
            const SizedBox(height: 10),
            const Text("Couldn't play this clip",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Try another video format (MP4 works best).',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            PremiumButton(
              label: 'Choose another',
              icon: Icons.folder_open_rounded,
              compact: true,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVideoState extends StatefulWidget {
  const _EmptyVideoState({
    required this.onUpload,
    required this.loading,
    this.isBottomVideo = false,
  });

  final VoidCallback onUpload;
  final bool loading;
  final bool isBottomVideo;

  @override
  State<_EmptyVideoState> createState() => _EmptyVideoStateState();
}

class _EmptyVideoStateState extends State<_EmptyVideoState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1, 1 - 2 * t),
              colors: const [
                Color(0xFF15151B),
                Color(0xFF1C1830),
                Color(0xFF15151B),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.isBottomVideo) ...[
                      _PulsingIcon(t: t),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      widget.isBottomVideo ? 'Upload Reaction' : 'Upload Video',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: widget.isBottomVideo ? 15 : 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isBottomVideo
                          ? 'Upload your recorded reaction here.'
                          : 'Upload the clip you want to react to.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: widget.isBottomVideo ? 11 : 12.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: widget.loading ? 'Opening…' : 'Upload Video',
                      icon: Icons.file_upload_outlined,
                      compact: widget.isBottomVideo,
                      gradient: AppColors.brandGradient,
                      busy: widget.loading,
                      onTap: widget.onUpload,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingIcon extends StatelessWidget {
  const _PulsingIcon({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.violetGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentSecondary.withValues(alpha: 0.35 * pulse),
            blurRadius: 26 + 14 * pulse,
            spreadRadius: 2 * pulse,
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
    );
  }
}
