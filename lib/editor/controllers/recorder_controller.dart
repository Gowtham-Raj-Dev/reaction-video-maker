import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'layout_controller.dart';
import 'media_controller.dart';

/// Owns the live camera + reaction recording lifecycle so both the camera
/// preview panel and the floating record button can share one controller.
class RecorderController extends ChangeNotifier {
  RecorderController();

  Timer? _autoStopTimer;

  CameraController? _camera;
  CameraController? get camera => _camera;

  bool _initializing = false;
  bool get initializing => _initializing;

  String? _error;
  String? get error => _error;

  bool get ready => _camera != null && _camera!.value.isInitialized;

  bool _recording = false;
  bool get recording => _recording;

  bool _paused = false;
  bool get paused => _paused;

  bool _isMirrored = false;
  bool get isMirrored => _isMirrored;

  bool _useCountdown = false;
  bool get useCountdown => _useCountdown;

  int _countdownValue = 0;
  int get countdownValue => _countdownValue;

  bool get isFrontCamera => _camera?.description.lensDirection == CameraLensDirection.front;

  void toggleMirror() {
    _isMirrored = !_isMirrored;
    notifyListeners();
  }

  void toggleCountdown() {
    _useCountdown = !_useCountdown;
    notifyListeners();
  }

  /// Path of the most recently captured reaction clip.
  String? lastRecordingPath;

  void clearRecording() {
    lastRecordingPath = null;
    notifyListeners();
  }

  Future<void> init() async {
    if (_camera != null || _initializing) return;
    _initializing = true;
    _error = null;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _error = 'No camera found. Please make sure a camera is connected.';
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.veryHigh,
        enableAudio: true, // Enable camera audio so microphone reaction is recorded
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException(
            'Camera access timed out. Please ensure no other app is using your camera and try again.',
          );
        },
      );
      _camera = controller;
    } catch (e) {
      if (e is TimeoutException) {
        _error = e.message;
      } else {
        _error = 'Camera unavailable. Please allow camera access in your browser settings.';
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> toggleRecording({
    BuildContext? context,
    LayoutController? layout,
  }) async {
    Duration? duration;
    if (context != null) {
      try {
        final mediaCtrl = Provider.of<MediaController>(context, listen: false);
        duration = mediaCtrl.videoDuration;
      } catch (_) {}
    }

    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    try {
      if (_recording) {
        _autoStopTimer?.cancel();
        _autoStopTimer = null;

        if (context != null && context.mounted) {
          try {
            final mediaCtrl = Provider.of<MediaController>(context, listen: false);
            mediaCtrl.setPlaying(false);
          } catch (_) {}
        }

        final file = await camera.stopVideoRecording();
        lastRecordingPath = file.path;
        _recording = false;
        _paused = false;
      } else {
        if (_useCountdown && context != null && context.mounted) {
          for (int i = 3; i > 0; i--) {
            if (context.mounted) {
              _countdownValue = i;
              notifyListeners();
              await Future.delayed(const Duration(seconds: 1));
            }
          }
          _countdownValue = 0;
          notifyListeners();
          
          if (!context.mounted) return;
        }

        await camera.startVideoRecording();
        _recording = true;
        _paused = false;

        _autoStopTimer?.cancel();
        _autoStopTimer = null;

        if (context != null && context.mounted) {
          final mediaCtrl = Provider.of<MediaController>(context, listen: false);
          // 1. Reset video to start
          mediaCtrl.resetVideo();
          // 2. Play the video
          mediaCtrl.setPlaying(true);

          if (duration != null) {
            _autoStopTimer = Timer(duration, () async {
              if (_recording) {
                await toggleRecording(context: null, layout: layout);
              }
            });
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      _error = 'Recording failed: $e';
      _recording = false;
      _paused = false;
      if (context != null && context.mounted) {
        try {
          final mediaCtrl = Provider.of<MediaController>(context, listen: false);
          mediaCtrl.setPlaying(false);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> pauseRecording() async {
    if (!_recording || _paused) return;
    try {
      await _camera?.pauseVideoRecording();
      _paused = true;
      notifyListeners();
    } catch (e) {
      _error = 'Pause failed';
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (!_recording || !_paused) return;
    try {
      await _camera?.resumeVideoRecording();
      _paused = false;
      notifyListeners();
    } catch (e) {
      _error = 'Resume failed';
      notifyListeners();
    }
  }

  Future<void> flipCamera() async {
    if (_camera == null || _recording || _initializing) return;
    
    _initializing = true;
    notifyListeners();

    try {
      final cameras = await availableCameras();
      if (cameras.length > 1) {
        final currentDirection = _camera!.description.lensDirection;
        final newCamera = cameras.firstWhere(
          (c) => c.lensDirection != currentDirection,
          orElse: () => cameras.firstWhere((c) => c != _camera!.description),
        );

        await _camera!.dispose();
        
        final controller = CameraController(
          newCamera,
          ResolutionPreset.veryHigh,
          enableAudio: true,
        );
        
        await controller.initialize();
        _camera = controller;
      }
    } catch (e) {
      _error = 'Failed to switch camera: $e';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }
}
