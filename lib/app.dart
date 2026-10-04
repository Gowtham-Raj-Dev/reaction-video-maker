import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'editor/controllers/canvas_controller.dart';
import 'editor/controllers/layout_controller.dart';
import 'editor/controllers/media_controller.dart';
import 'editor/controllers/recorder_controller.dart';
import 'theme/app_theme.dart';
import 'splash_screen.dart';

/// Root widget. Wires up the shared controllers and the premium dark theme.
class ReactionVideoApp extends StatelessWidget {
  const ReactionVideoApp({super.key, required this.layout});

  final LayoutController layout;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LayoutController>.value(value: layout),
        ChangeNotifierProvider(create: (_) => CanvasController()),
        ChangeNotifierProvider(create: (_) => MediaController()),
        ChangeNotifierProvider(create: (_) => RecorderController()),
      ],
      child: MaterialApp(
        title: 'Reaction Studio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: SplashScreen(layout: layout),
      ),
    );
  }
}
