import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Color, Colors;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../models/canvas_item.dart';
import '../controllers/layout_controller.dart';

Future<File> _generateOverlayMask(
  int width, int height, 
  double videoSplit, double bottomSplit, 
  double pipSize, double pipHeight,
  String tempDir,
  LayoutMode mode,
  bool isRoundedCorners,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Background color matching AppColors.background exactly
  final bgPaint = ui.Paint()..color = const Color(0xFF141019);
  
  if (mode == LayoutMode.pip) {
    // Fill the mask with transparent initially, so the background video shows through fully
    final clearPaint = ui.Paint()..blendMode = ui.BlendMode.clear;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), clearPaint);
    
    // Calculate PIP dimensions
    int _even(num value) {
      int v = value.round();
      return v.isOdd ? v + 1 : v;
    }
    
    int pipW = _even(width * pipSize);
    int pipH = _even(height * pipHeight);
    int pipX = width - pipW - 40;
    int pipY = height - pipH - 40;
    
    double r = isRoundedCorners ? (pipW / 300.0) * 12.0 : 0.0;

    // Create a path that covers the entire PIP area
    final pipRect = ui.Rect.fromLTWH(pipX.toDouble(), pipY.toDouble(), pipW.toDouble(), pipH.toDouble());
    final pipPath = ui.Path()..addRect(pipRect);
    
    // Create a path for the rounded PIP area
    final roundedPipPath = ui.Path()..addRRect(ui.RRect.fromRectAndRadius(pipRect, ui.Radius.circular(r)));
    
    // Subtract the rounded area from the full area to get JUST the 4 sharp corner covers
    final cornerCovers = ui.Path.combine(ui.PathOperation.difference, pipPath, roundedPipPath);
    
    // Draw the corner covers in the background color to hide the sharp camera corners
    canvas.drawPath(cornerCovers, bgPaint);
  } else {
    // Draw solid background
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    final scale = width / 400.0;
    final scaledMargin = isRoundedCorners ? 8.0 * scale : 0.0; 
    final radius = isRoundedCorners ? 30.0 * scale : 0.0;

    final topH = height * videoSplit;
    final clearPaint = ui.Paint()..blendMode = ui.BlendMode.clear;

    if (mode == LayoutMode.classic) {
      final leftW = width * bottomSplit;
      // Top Video Rect
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTRB(scaledMargin, scaledMargin, width - scaledMargin, topH - scaledMargin),
          ui.Radius.circular(radius),
        ),
        clearPaint,
      );
      // Bottom Left Rect (Content)
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTRB(scaledMargin, topH + scaledMargin, leftW - scaledMargin, height - scaledMargin),
          ui.Radius.circular(radius),
        ),
        clearPaint,
      );
      // Bottom Right Rect (Camera)
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTRB(leftW + scaledMargin, topH + scaledMargin, width - scaledMargin, height - scaledMargin),
          ui.Radius.circular(radius),
        ),
        clearPaint,
      );
    } else {
      // Both Top Video and Top Camera just have 2 full-width sections
      // Top Rect
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTRB(scaledMargin, scaledMargin, width - scaledMargin, topH - scaledMargin),
          ui.Radius.circular(radius),
        ),
        clearPaint,
      );
      // Bottom Rect
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTRB(scaledMargin, topH + scaledMargin, width - scaledMargin, height - scaledMargin),
          ui.Radius.circular(radius),
        ),
        clearPaint,
      );
    }
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  
  final file = File('$tempDir/mask_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

Future<File> _generatePipCameraMask(
  int width, int height, 
  String tempDir,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  final clearPaint = ui.Paint()..blendMode = ui.BlendMode.clear;
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), clearPaint);

  final fgPaint = ui.Paint()..color = const Color(0xFFFFFFFF);
  
  final radius = (width / 300.0) * 12.0;
  
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Radius.circular(radius),
    ),
    fgPaint,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  
  final file = File('$tempDir/pip_mask_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
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
  bool isTopCover = true,
  bool isBottomCover = true,
  required bool isRoundedCorners,
  required bool isOriginalAudio,
  void Function(double)? onProgress,
}) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath = '${tempDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';

  // Ensure PIP exports in Landscape 16:9, just like the UI container!
  int outW = mode == LayoutMode.pip ? 1920 : 1080;
  int outH = mode == LayoutMode.pip ? 1080 : 1920;

  final maskFile = await _generateOverlayMask(outW, outH, videoSplit, bottomSplit, pipSize, pipHeight, tempDir.path, mode, isRoundedCorners);
  File? pipMaskFile;

  int _even(num value) {
    int v = value.round();
    return v.isOdd ? v + 1 : v;
  }

  final int topH = _even(outH * videoSplit);
  final int botH = outH - topH;
  final int leftW = mode == LayoutMode.classic ? _even(outW * bottomSplit) : 0;
  final int rightW = mode == LayoutMode.classic ? outW - leftW : outW;

  String fontPath = "fontfile=/system/fonts/Roboto-Regular.ttf";
  if (Platform.isIOS) {
    fontPath = "font='Helvetica'";
  }

  bool shouldFlip = isFrontCamera ? !isMirrored : isMirrored;

  String filter = "";
  
  String _scaleString(String label, int targetW, int targetH, bool isCover) {
    if (isCover) {
      return "scale='ceil(max($targetW, iw*$targetH/ih)/2)*2':'ceil(max($targetH, ih*$targetW/iw)/2)*2',crop=$targetW:$targetH[$label]";
    } else {
      return "scale='ceil(min($targetW, iw*$targetH/ih)/2)*2':'ceil(min($targetH, ih*$targetW/iw)/2)*2',pad=$targetW:$targetH:-1:-1:color='#141019'[$label]";
    }
  }

  if (mode == LayoutMode.classic) {
    String cameraFilter = "[1:v]crop='min(iw, ih*$previewAspect)':'min(ih, iw/$previewAspect)',${_scaleString('bot', rightW, botH, isBottomCover).replaceAll('[bot]', '')}[bot];";
    if (shouldFlip) cameraFilter = cameraFilter.replaceAll('[bot];', ',hflip[bot];');

    filter = 
      "[0:v]${_scaleString('top', outW, topH, isTopCover)};"
      "$cameraFilter"
      "color=c='#141019':s=${outW}x${outH}[bg];"
      "[bg][top]overlay=x=0:y=0:eof_action=pass[bg1];"
      "[bg1][bot]overlay=x=$leftW:y=$topH:eof_action=pass[v_base];";
  } else if (mode == LayoutMode.topVideo) {
    String cameraFilter = "[1:v]crop='min(iw, ih*$previewAspect)':'min(ih, iw/$previewAspect)',${_scaleString('bot', outW, botH, isBottomCover).replaceAll('[bot]', '')}[bot];";
    if (shouldFlip) cameraFilter = cameraFilter.replaceAll('[bot];', ',hflip[bot];');

    filter = 
      "[0:v]${_scaleString('top', outW, topH, isTopCover)};"
      "$cameraFilter"
      "color=c='#141019':s=${outW}x${outH}[bg];"
      "[bg][top]overlay=x=0:y=0:eof_action=pass[bg1];"
      "[bg1][bot]overlay=x=0:y=$topH:eof_action=pass[v_base];";
  } else if (mode == LayoutMode.pip) {
    int pipW = (outW * pipSize).round();
    pipW = _even(pipW);
    int pipH = (outH * pipHeight).round();
    pipH = _even(pipH);
    int pipX = outW - pipW - 40;
    int pipY = outH - pipH - 40; // Bottom right margin

    String cameraFilter = "[1:v]${_scaleString('bot', pipW, pipH, isBottomCover).replaceAll('[bot]', '')}[bot];";
    if (shouldFlip) cameraFilter = cameraFilter.replaceAll('[bot];', ',hflip[bot];');

    filter = 
      "[0:v]${_scaleString('top', outW, outH, isTopCover)};"
      "$cameraFilter"
      "[top][bot]overlay=x=$pipX:y=$pipY:eof_action=pass[v_base];";
  } else if (mode == LayoutMode.topCamera) {
    String cameraFilter = "[1:v]crop='min(iw, ih*$previewAspect)':'min(ih, iw/$previewAspect)',${_scaleString('top', outW, topH, isBottomCover).replaceAll('[top]', '')}[top];";
    if (shouldFlip) cameraFilter = cameraFilter.replaceAll('[top];', ',hflip[top];');

    filter = 
      "[0:v]${_scaleString('bot', outW, botH, isTopCover)};"
      "$cameraFilter"
      "color=c='#141019':s=${outW}x${outH}[bg];"
      "[bg][top]overlay=x=0:y=0:eof_action=pass[bg1];"
      "[bg1][bot]overlay=x=0:y=$topH:eof_action=pass[v_base];";
  }
  bool hasAudio0 = false;
  try {
    final s = await FFprobeKit.getMediaInformation(videoPath);
    final info = s.getMediaInformation();
    if (info != null) {
      for (final stream in info.getStreams()) {
        if (stream.getType() == "audio") hasAudio0 = true;
      }
    }
  } catch (_) {}

  bool hasAudio1 = false;
  try {
    final s = await FFprobeKit.getMediaInformation(reactionPath);
    final info = s.getMediaInformation();
    if (info != null) {
      for (final stream in info.getStreams()) {
        if (stream.getType() == "audio") hasAudio1 = true;
      }
    }
  } catch (_) {}

  String audioMapping = "";
  if (hasAudio0 && hasAudio1 && isOriginalAudio) {
    // Both videos have audio, and user wants original audio included
    // Use amix to combine them
    filter += "[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[aout];";
    audioMapping = "-map [aout] -c:a aac";
  } else if (hasAudio1) {
    // Just the camera audio (e.g. original audio is turned off to prevent echo)
    audioMapping = "-map 1:a:0 -c:a aac";
  } else if (hasAudio0 && isOriginalAudio) {
    // Camera has no audio, but video does
    audioMapping = "-map 0:a:0 -c:a aac";
  } else {
    // No audio to map
    audioMapping = ""; 
  }

  String lastOut = "v_base";
  int textCount = 0;

  for (var itemObj in items) {
    if (itemObj is CanvasItem) {
      if (itemObj.type == CanvasItemType.text || itemObj.type == CanvasItemType.watermark) {
        double sizeFactor = outW / 300;
        int fontSize = ((itemObj.fontSize ?? 22) * sizeFactor).round();
        
        int maxCharsPerLine = ((itemObj.size.width * outW) / (fontSize * 0.45)).round();
        if (maxCharsPerLine < 1) maxCharsPerLine = 1;

        String wrappedText = '';
        final lines = itemObj.text.split('\n');
        for (final line in lines) {
          final words = line.split(' ');
          String currentLine = '';
          for (final word in words) {
            if (currentLine.isEmpty) {
              currentLine = word;
            } else if ((currentLine + ' ' + word).length > maxCharsPerLine) {
              wrappedText += '$currentLine\n';
              currentLine = word;
            } else {
              currentLine += ' $word';
            }
          }
          if (currentLine.isNotEmpty) {
            wrappedText += '$currentLine\n';
          }
        }
        wrappedText = wrappedText.trimRight();

        final textFile = File('${tempDir.path}/text_$textCount.txt');
        await textFile.writeAsString(wrappedText);
        
        String hex = itemObj.color.value.toRadixString(16).padLeft(8, '0');
        String colorHex = hex.substring(2); 
        
        int itemX = (itemObj.center.dx * outW).round();
        int itemY = (itemObj.center.dy * outH).round();
        
        String nextOut = "v_out_$textCount";
        filter += "[$lastOut]drawtext=$fontPath:textfile='${textFile.path}':fontcolor=#$colorHex:fontsize=$fontSize:x=$itemX-tw/2:y=$itemY-th/2:line_spacing=10[$nextOut];";
        lastOut = nextOut;
        textCount++;
      }
    }
  }

  // Apply the UI layout mask at the very end to clip all contents cleanly
  String finalOut = "v_final_masked";
  filter += "[$lastOut][2:v]overlay=x=0:y=0:eof_action=pass[$finalOut];";
  lastOut = finalOut;

  // We cap the output to exact duration to eliminate EOF buffering. No extra pipMaskFile needed!
  String durStr = durationSec.toStringAsFixed(3);
  String cmd = "-v error -stats -y -i '$videoPath' -i '$reactionPath' -framerate 30 -loop 1 -i '${maskFile.path}' ";
  
  cmd += "-filter_complex \"$filter\" -map \"[$lastOut]\" $audioMapping -c:v libx264 -preset ultrafast -crf 28 -threads 2 -pix_fmt yuv420p -max_muxing_queue_size 1024 -t $durStr '$outputPath'";

  // Create a completer to wait for FFmpeg to actually finish
  final completer = Completer<String>();

  await FFmpegKit.executeAsync(
    cmd,
    (session) async {
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        if (onProgress != null) onProgress(1.0);
        completer.complete(outputPath);
      } else {
        completer.completeError('FFmpeg process failed: $output');
      }
    },
    (log) {}, 
    (statistics) {
      if (onProgress != null && durationSec > 0) {
        final timeInMilliseconds = statistics.getTime();
        if (timeInMilliseconds > 0) {
          final progress = timeInMilliseconds / (durationSec * 1000.0);
          onProgress(progress.clamp(0.0, 1.0));
        }
      }
    },
  );

  return completer.future;
}
