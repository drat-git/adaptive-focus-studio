import 'package:flutter/material.dart';

import 'models/focus_preset.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.loadPresets, this.loadSummary});

  final Future<List<FocusPreset>> Function()? loadPresets;
  final Future<Map<String, Object?>> Function(String? moodTag)? loadSummary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Focus Studio',
      theme: buildAppTheme(),
      home: HomeScreen(loadPresets: loadPresets, loadSummary: loadSummary),
    );
  }
}
