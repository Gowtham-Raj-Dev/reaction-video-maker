// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of video saver.
Future<void> saveVideoFile(String path) async {
  final anchor = html.AnchorElement(href: path)
    ..setAttribute('download', 'reaction-video.mp4')
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
}
