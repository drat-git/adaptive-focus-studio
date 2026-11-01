import 'package:flutter/material.dart';

import 'models/focus_preset.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.loadPresets});

  final Future<List<FocusPreset>> Function()? loadPresets;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Focus Studio',
      theme: buildAppTheme(),
      home: HomeScreen(loadPresets: loadPresets),
    );
  }
}
