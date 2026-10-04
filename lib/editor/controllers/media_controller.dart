import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Holds the uploaded reaction video path plus the global play/pause state for
/// the whole preview.
class MediaController extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  String? _videoPath;
  String? get videoPath => _videoPath;
  bool get hasVideo => _videoPath != null;

  String? _bottomVideoPath;
  String? get bottomVideoPath => _bottomVideoPath;
  bool get hasBottomVideo => _bottomVideoPath != null;

  Duration? _videoDuration;
  Duration? get videoDuration => _videoDuration;

  bool _picking = false;
  bool get picking => _picking;

  /// Global "is the preview playing" flag. Starts paused.
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _resetRequestCount = 0;
  int get resetRequestCount => _resetRequestCount;

  final Map<String, Uint8List> webImageBytes = {};

  void resetVideo() {
    _resetRequestCount++;
    notifyListeners();
  }

  Future<void> pickVideo() async {
    if (_picking) return;
    _picking = true;
    notifyListeners();
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        _videoPath = file.path;
        _isPlaying = false; // don't auto-play a freshly picked clip

        final VideoPlayerController tempController;
        if (kIsWeb) {
          tempController = VideoPlayerController.networkUrl(Uri.parse(file.path));
        } else {
          tempController = VideoPlayerController.file(File(file.path));
        }

        try {
          await tempController.initialize();
          _videoDuration = tempController.value.duration;
          await tempController.dispose();
        } catch (e) {
          debugPrint('Error getting video duration: $e');
          _videoDuration = null;
        }
      }
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  Future<void> pickBottomVideo() async {
    if (_picking) return;
    _picking = true;
    notifyListeners();
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        _bottomVideoPath = file.path;
      }
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  Future<String?> pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      if (kIsWeb) {
        try {
          final bytes = await file.readAsBytes();
          webImageBytes[file.path] = bytes;
        } catch (e) {
          debugPrint('Error reading picked image bytes: $e');
        }
      }
      return file.path;
    }
    return null;
  }

  void togglePlay() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void setPlaying(bool value) {
    if (_isPlaying == value) return;
    _isPlaying = value;
    notifyListeners();
  }

  void clearVideo() {
    _videoPath = null;
    _bottomVideoPath = null;
    _videoDuration = null;
    _isPlaying = false;
    notifyListeners();
  }
}
