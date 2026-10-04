import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'editor/controllers/layout_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Restore the user's last saved divider layout before first paint so the
  // exact arrangement is shown immediately on launch.
  final layout = LayoutController();
  await layout.load();

  runApp(ReactionVideoApp(layout: layout));
}
