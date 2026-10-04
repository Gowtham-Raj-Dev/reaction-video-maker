/// Mobile stub for screen recording (we use the camera package on mobile).
class ScreenRecorderHelper {
  static bool get isSupported => false;
  static void Function(String url)? onStoppedExternally;
  static Future<void> start({
    double x = 0,
    double y = 0,
    double w = 0,
    double h = 0,
    double dpr = 1,
  }) async {}
  static Future<String?> stop() async => null;
  static Future<void> pause() async {}
  static Future<void> resume() async {}
}
