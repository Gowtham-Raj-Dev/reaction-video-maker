// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class ScreenRecorderHelper {
  static html.MediaStream? _stream;
  static html.MediaRecorder? _recorder;
  static html.VideoElement? _videoElement;
  static html.CanvasElement? _recordCanvas;
  static int? _animationFrameId;
  static final List<html.Blob> _chunks = [];
  static Completer<String?>? _completer;
  static void Function(String url)? onStoppedExternally;

  static bool get isSupported => true;

  static Future<void> start({
    double x = 0,
    double y = 0,
    double w = 0,
    double h = 0,
    double dpr = 1,
  }) async {
    _chunks.clear();
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Media devices not supported on this browser');
      }

      // Call getDisplayMedia via JS interop. The dart:html MediaDevices
      // binding doesn't expose getDisplayMedia in all SDK versions, so a
      // dynamic call throws NoSuchMethodError. Invoking the underlying JS
      // method directly avoids that.
      final hasGetDisplayMedia =
          js_util.hasProperty(mediaDevices, 'getDisplayMedia');
      if (!hasGetDisplayMedia) {
        throw Exception(
          'Screen recording is not supported in this browser',
        );
      }

      // Capture the screen/tab with audio if available.
      final constraints = js_util.jsify({
        'video': {
          'displaySurface': 'browser', // hint to prefer tab sharing
        },
        'audio': true,
      });
      _stream = await js_util.promiseToFuture<html.MediaStream>(
        js_util.callMethod(mediaDevices, 'getDisplayMedia', [constraints]),
      );

      // Create a virtual video player to extract frames from the viewport capture stream
      _videoElement = html.VideoElement()
        ..srcObject = _stream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.display = 'none';
      html.document.body?.append(_videoElement!);

      // Create a canvas of the exact crop size (initially based on logical * dpr)
      _recordCanvas = html.CanvasElement()
        ..width = (w * dpr).round()
        ..height = (h * dpr).round();
      final ctx = _recordCanvas!.getContext('2d') as html.CanvasRenderingContext2D;

      double scaleX = dpr;
      double scaleY = dpr;
      bool canvasResolutionSet = false;

      // Draw loop to crop frames on the fly
      bool drawing = false;
      void drawFrame() {
        if (_stream == null || _videoElement == null || _recordCanvas == null) return;
        if (drawing) return;
        drawing = true;
        try {
          final videoW = _videoElement!.videoWidth;
          final videoH = _videoElement!.videoHeight;
          if (videoW > 0 && videoH > 0) {
            if (!canvasResolutionSet) {
              final viewW = html.window.innerWidth ?? 1;
              final viewH = html.window.innerHeight ?? 1;
              scaleX = videoW / viewW;
              scaleY = videoH / viewH;
              _recordCanvas!.width = (w * scaleX).round();
              _recordCanvas!.height = (h * scaleY).round();
              canvasResolutionSet = true;
            }

            final realSx = (x * scaleX).round();
            final realSy = (y * scaleY).round();
            final realSw = _recordCanvas!.width!;
            final realSh = _recordCanvas!.height!;

            ctx.drawImageScaledFromSource(
              _videoElement!,
              realSx,
              realSy,
              realSw,
              realSh,
              0,
              0,
              realSw,
              realSh,
            );
          }
        } catch (_) {}
        _animationFrameId = html.window.requestAnimationFrame((_) {
          drawing = false;
          drawFrame();
        });
      }

      _videoElement!.onPlay.listen((_) => drawFrame());
      _videoElement!.play().then((_) => drawFrame()).catchError((_) {});
      drawFrame();

      // Capture a stream of the cropped canvas at 30 fps
      final canvasStream = _recordCanvas!.captureStream(30);

      // If screen share contains audio (e.g. system/tab audio), add it to the final clip
      final audioTracks = _stream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        canvasStream.addTrack(audioTracks.first);
      }

      _recorder = html.MediaRecorder(canvasStream);
      _recorder!.addEventListener('dataavailable', (html.Event event) {
        final html.Blob blob = (event as html.BlobEvent).data!;
        if (blob.size > 0) {
          _chunks.add(blob);
        }
      });

      _recorder!.addEventListener('stop', (html.Event event) {
        final blob = html.Blob(_chunks, 'video/webm');
        final url = html.Url.createObjectUrlFromBlob(blob);

        if (_animationFrameId != null) {
          html.window.cancelAnimationFrame(_animationFrameId!);
          _animationFrameId = null;
        }

        _stream?.getTracks().forEach((track) => track.stop());
        _stream = null;

        _videoElement?.remove();
        _videoElement?.pause();
        _videoElement = null;
        _recordCanvas = null;
        _recorder = null;

        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(url);
        } else {
          onStoppedExternally?.call(url);
        }
      });

      _recorder!.start();
    } catch (e) {
      if (_animationFrameId != null) {
        html.window.cancelAnimationFrame(_animationFrameId!);
        _animationFrameId = null;
      }
      _stream?.getTracks().forEach((track) => track.stop());
      _stream = null;
      _videoElement?.remove();
      _videoElement?.pause();
      _videoElement = null;
      _recordCanvas = null;
      _recorder = null;
      rethrow;
    }
  }

  static Future<String?> stop() async {
    if (_recorder == null || _recorder!.state != 'recording' && _recorder!.state != 'paused') {
      return null;
    }
    _completer = Completer<String?>();
    _recorder!.stop();
    return _completer!.future;
  }

  static Future<void> pause() async {
    if (_recorder != null && _recorder!.state == 'recording') {
      _recorder!.pause();
    }
  }

  static Future<void> resume() async {
    if (_recorder != null && _recorder!.state == 'paused') {
      _recorder!.resume();
    }
  }
}
