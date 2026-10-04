// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import '../models/canvas_item.dart';
import '../controllers/layout_controller.dart';

void _injectJsMerger() {
  final existing = html.document.getElementById('reaction-video-merger-script');
  if (existing != null) {
    existing.remove();
  }
  
  final script = html.ScriptElement()
    ..id = 'reaction-video-merger-script'
    ..text = '''
      window.mergeReactionVideos = async function(video1Src, video2Src, videoSplit, bottomSplit, pipSize, pipHeight, textOverlaysJson, durationSec, isMirrored, mode, callback) {
        try {
          console.log("Starting Web video merge...");
          const overlays = JSON.parse(textOverlaysJson);
          
          const canvas = document.createElement('canvas');
          canvas.width = mode === 'pip' ? 1920 : 1080;
          canvas.height = mode === 'pip' ? 1080 : 1920;
          const ctx = canvas.getContext('2d');
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'medium';

          // Preload overlay images
          await Promise.all(overlays.map(item => {
            if (item.assetPath) {
              return new Promise((resolve) => {
                const img = new Image();
                img.onload = () => {
                  item.imgElement = img;
                  resolve();
                };
                img.onerror = () => {
                  console.warn("Failed to load overlay image:", item.assetPath);
                  resolve();
                };
                img.src = item.assetPath;
              });
            }
            return Promise.resolve();
          }));

          const v1 = document.createElement('video');
          v1.src = video1Src;
          v1.crossOrigin = 'anonymous';
          v1.muted = false;
          v1.volume = 1.0;
          v1.playsInline = true;

          const v2 = document.createElement('video');
          v2.src = video2Src;
          v2.crossOrigin = 'anonymous';
          v2.muted = false;
          v2.volume = 1.0;
          v2.playsInline = true;

          let loadedCount = 0;
          const onVideoLoaded = () => {
            loadedCount++;
            if (loadedCount === 2) {
              startMerging();
            }
          };
          v1.onloadedmetadata = onVideoLoaded;
          v2.onloadedmetadata = onVideoLoaded;
          v1.onerror = () => callback(null, 'Failed to load uploaded video');
          v2.onerror = () => callback(null, 'Failed to load reaction camera video');
          
          v1.load();
          v2.load();

          async function startMerging() {
            let audioStream = null;
            try {
              const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
              if (audioCtx.state === 'suspended') {
                await audioCtx.resume();
              }
              const dest = audioCtx.createMediaStreamDestination();
              
              const source1 = audioCtx.createMediaElementSource(v1);
              source1.connect(dest);
              source1.connect(audioCtx.destination);
              
              const source2 = audioCtx.createMediaElementSource(v2);
              source2.connect(dest);
              source2.connect(audioCtx.destination);
              
              audioStream = dest.stream;
            } catch (e) {
              console.warn("Audio mixing failed:", e);
            }

            v1.currentTime = 0;
            v2.currentTime = 0;
            v1.play();
            v2.play();

            const canvasStream = canvas.captureStream(30);
            if (audioStream && audioStream.getAudioTracks().length > 0) {
              canvasStream.addTrack(audioStream.getAudioTracks()[0]);
            }

            const chunks = [];
            let options = { mimeType: 'video/webm;codecs=h264' };
            if (!MediaRecorder.isTypeSupported(options.mimeType)) {
              options = { mimeType: 'video/webm;codecs=vp8' };
            }
            if (!MediaRecorder.isTypeSupported(options.mimeType)) {
              options = { mimeType: 'video/webm' };
            }
            if (!MediaRecorder.isTypeSupported(options.mimeType)) {
              options = { mimeType: 'video/mp4;codecs=h264' };
            }
            if (!MediaRecorder.isTypeSupported(options.mimeType)) {
              options = { mimeType: 'video/mp4' };
            }
            options.videoBitsPerSecond = 8000000;
            options.audioBitsPerSecond = 128000;
            options.bitsPerSecond = 8128000;

            const recorder = new MediaRecorder(canvasStream, options);
            
            recorder.ondataavailable = (e) => {
              if (e.data && e.data.size > 0) {
                chunks.push(e.data);
              }
            };

            recorder.onstop = () => {
              const blob = new Blob(chunks, { type: options.mimeType });
              const url = URL.createObjectURL(blob);
              callback(url, null);
            };

            recorder.start();

            const drawLoop = () => {
              if (v1.currentTime >= durationSec || v2.currentTime >= durationSec || v1.ended || v2.ended) {
                recorder.stop();
                v1.pause();
                v2.pause();
                return;
              }

              // Clear canvas with backdrop color
              ctx.fillStyle = '#141019';
              ctx.fillRect(0, 0, canvas.width, canvas.height);

              const topH = canvas.height * videoSplit;
              const bottomY = topH;
              const bottomH = canvas.height - topH;

              if (mode === 'classic') {
                // Top: Video
                drawVideoContain(ctx, v1, 0, 0, canvas.width, topH, false);

                // Bottom Left: Content Panel
                const leftW = canvas.width * bottomSplit;
                const grad = ctx.createLinearGradient(0, bottomY, leftW, bottomY + bottomH);
                grad.addColorStop(0, '#141019');
                grad.addColorStop(1, '#0F0F14');
                ctx.fillStyle = grad;
                ctx.fillRect(0, bottomY, leftW, bottomH);
                drawCanvasOverlays(ctx, overlays, 0, bottomY, leftW, bottomH);

                // Bottom Right: Camera
                const rightX = leftW;
                const rightW = canvas.width - leftW;
                drawVideoCover(ctx, v2, rightX, bottomY, rightW, bottomH, isMirrored);
              } else if (mode === 'topVideo') {
                // Top: Video
                drawVideoContain(ctx, v1, 0, 0, canvas.width, topH, false);
                // Bottom: Camera Full Width
                drawVideoCover(ctx, v2, 0, bottomY, canvas.width, bottomH, isMirrored);
              } else if (mode === 'topCamera') {
                // Top: Camera
                drawVideoCover(ctx, v2, 0, 0, canvas.width, topH, isMirrored);
                // Bottom: Video Full Width
                drawVideoContain(ctx, v1, 0, bottomY, canvas.width, bottomH, false);
              } else if (mode === 'pip') {
                // Background: Full Video
                drawVideoContain(ctx, v1, 0, 0, canvas.width, canvas.height, false);
                
                // Overlay: Picture in Picture Camera at bottom right
                const pipW = Math.round(canvas.width * pipSize);
                const pipH = Math.round(canvas.height * pipHeight);
                const pipX = canvas.width - pipW - 40;
                const pipY = canvas.height - pipH - 40;
                
                // Add simple border and shadow for PIP on web
                ctx.save();
                ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
                ctx.shadowBlur = 12;
                ctx.shadowOffsetX = 0;
                ctx.shadowOffsetY = 4;
                
                // Draw rounded rect for pip background and clipping
                const radius = 12;
                ctx.beginPath();
                ctx.moveTo(pipX + radius, pipY);
                ctx.lineTo(pipX + pipW - radius, pipY);
                ctx.quadraticCurveTo(pipX + pipW, pipY, pipX + pipW, pipY + radius);
                ctx.lineTo(pipX + pipW, pipY + pipH - radius);
                ctx.quadraticCurveTo(pipX + pipW, pipY + pipH, pipX + pipW - radius, pipY + pipH);
                ctx.lineTo(pipX + radius, pipY + pipH);
                ctx.quadraticCurveTo(pipX, pipY + pipH, pipX, pipY + pipH - radius);
                ctx.lineTo(pipX, pipY + radius);
                ctx.quadraticCurveTo(pipX, pipY, pipX + radius, pipY);
                ctx.closePath();
                
                ctx.fillStyle = '#000000';
                ctx.fill();
                ctx.clip(); // Clip the video to rounded corners

                drawVideoCover(ctx, v2, pipX, pipY, pipW, pipH, isMirrored);
                ctx.restore();
              }
              
              if (window.flutterExportProgress && durationSec > 0) {
                const currentSec = (performance.now() - startTime) / 1000;
                let pct = currentSec / durationSec;
                if (pct > 1.0) pct = 1.0;
                window.flutterExportProgress(pct);
              }

              requestAnimationFrame(drawLoop);
            };

            requestAnimationFrame(drawLoop);
          }
        } catch (err) {
          callback(null, err.toString());
        }
      };

      function drawVideoCover(ctx, video, x, y, w, h, mirrored) {
        const vw = video.videoWidth || w;
        const vh = video.videoHeight || h;
        const videoRatio = vw / vh;
        const targetRatio = w / h;
        
        let sx, sy, sw, sh;
        if (videoRatio > targetRatio) {
          sh = vh;
          sw = vh * targetRatio;
          sx = (vw - sw) / 2;
          sy = 0;
        } else {
          sw = vw;
          sh = vw / targetRatio;
          sx = 0;
          sy = (vh - sh) / 2;
        }

        ctx.save();
        if (mirrored) {
          ctx.translate(x + w, y);
          ctx.scale(-1, 1);
          ctx.drawImage(video, sx, sy, sw, sh, 0, 0, w, h);
        } else {
          ctx.drawImage(video, sx, sy, sw, sh, x, y, w, h);
        }
        ctx.restore();
      }

      function drawVideoContain(ctx, video, x, y, w, h, mirrored) {
        const vw = video.videoWidth || w;
        const vh = video.videoHeight || h;
        const videoRatio = vw / vh;
        const targetRatio = w / h;
        
        let dx, dy, dw, dh;
        if (videoRatio > targetRatio) {
          dw = w;
          dh = w / videoRatio;
          dx = x;
          dy = y + (h - dh) / 2;
        } else {
          dw = h * videoRatio;
          dh = h;
          dx = x + (w - dw) / 2;
          dy = y;
        }
        ctx.fillStyle = '#000000';
        ctx.fillRect(x, y, w, h);

        ctx.save();
        if (mirrored) {
          ctx.translate(dx + dw, dy);
          ctx.scale(-1, 1);
          ctx.drawImage(video, 0, 0, dw, dh);
        } else {
          ctx.drawImage(video, dx, dy, dw, dh);
        }
        ctx.restore();
      }

      function drawCanvasOverlays(ctx, items, x, y, w, h) {
        const shortest = Math.min(w, h);
        items.forEach(item => {
          ctx.save();
          ctx.globalAlpha = item.opacity !== undefined ? item.opacity : 1;
          
          const itemW = item.width * shortest;
          const itemH = item.height * shortest;
          const itemX = x + (item.centerX * w);
          const itemY = y + (item.centerY * h);
          
          ctx.translate(itemX, itemY);
          if (item.rotation) {
            ctx.rotate(item.rotation);
          }
          
          if (item.imgElement) {
            const borderRadius = item.borderRadius || 0;
            const rx = -itemW / 2;
            const ry = -itemH / 2;
            
            if (item.hasShadow) {
              ctx.save();
              ctx.shadowColor = 'rgba(0, 0, 0, 0.45)';
              ctx.shadowBlur = 18 * (shortest / 300);
              ctx.shadowOffsetX = 0;
              ctx.shadowOffsetY = 8 * (shortest / 300);
              ctx.beginPath();
              if (ctx.roundRect) {
                ctx.roundRect(rx, ry, itemW, itemH, borderRadius * (shortest / 300));
              } else {
                ctx.rect(rx, ry, itemW, itemH);
              }
              ctx.fillStyle = '#000000';
              ctx.fill();
              ctx.restore();
            }
            
            ctx.save();
            if (borderRadius > 0) {
              ctx.beginPath();
              if (ctx.roundRect) {
                ctx.roundRect(rx, ry, itemW, itemH, borderRadius * (shortest / 300));
              } else {
                ctx.rect(rx, ry, itemW, itemH);
              }
              ctx.clip();
            }
            ctx.drawImage(item.imgElement, rx, ry, itemW, itemH);
            ctx.restore();
          } else if (item.text) {
            if (item.hasShadow) {
              ctx.shadowColor = 'rgba(0, 0, 0, 0.45)';
              ctx.shadowBlur = 18 * (shortest / 300);
              ctx.shadowOffsetX = 0;
              ctx.shadowOffsetY = 8 * (shortest / 300);
            }
            
            ctx.fillStyle = item.color || '#FFFFFF';
            const baseFontSize = (item.fontSize || 22) * (shortest / 300);
            const isBold = item.fontWeight && item.fontWeight.includes('w800');
            ctx.font = (isBold ? 'bold ' : '') + baseFontSize + 'px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            
            const metrics = ctx.measureText(item.text);
            const textWidth = metrics.width;
            
            let scale = 1;
            if (textWidth > itemW) {
              scale = itemW / textWidth;
            }
            
            ctx.scale(scale, scale);
            ctx.fillText(item.text, 0, 0);
          }
          
          ctx.restore();
        });
      }
    ''';
  html.document.head?.append(script);
}

Future<String> mergeVideos({
  required String videoPath,
  required String reactionPath,
  required double videoSplit,
  required double bottomSplit,
  required double pipSize,
  required double pipHeight,
  required List<dynamic> items,
  required double durationSec,
  required bool isMirrored,
  required LayoutMode mode,
  double previewAspect = 9 / 16,
  bool isFrontCamera = true,
  void Function(double)? onProgress,
}) async {
  _injectJsMerger();
  
  final overlaysJson = jsonEncode(items.map((dynamic itemObj) {
    final item = itemObj as CanvasItem;
    return {
      'type': item.type.name,
      'text': item.text,
      'centerX': item.center.dx,
      'centerY': item.center.dy,
      'width': item.size.width,
      'height': item.size.height,
      'fontSize': item.fontSize,
      'color': '#${item.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'assetPath': item.assetPath,
      'rotation': item.rotation,
      'opacity': item.opacity,
      'borderRadius': item.borderRadius,
      'hasShadow': item.hasShadow,
      'fontWeight': item.fontWeight.toString(),
    };
  }).toList());

  final completer = Completer<String>();

  if (onProgress != null) {
    js.context['flutterExportProgress'] = js.allowInterop((num percent) {
      onProgress(percent.toDouble());
    });
  }

  js.context.callMethod('mergeReactionVideos', [
    videoPath,
    reactionPath,
    videoSplit,
    bottomSplit,
    pipSize,
    pipHeight,
    overlaysJson,
    durationSec,
    isMirrored,
    mode.name,
    js.JsFunction.withThis((_, url, error) {
      if (error != null) {
        completer.completeError(error.toString());
      } else {
        completer.complete(url.toString());
      }
    })
  ]);
  
  return completer.future;
}
