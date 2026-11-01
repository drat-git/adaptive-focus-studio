import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:adaptive_focus_studio/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Saved or device motion preference keeps session status still', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final preferences in [
      [true, false],
      [false, true],
      [false, false],
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: preferences[1]),
            child: child!,
          ),
          home: FocusSessionScreen(
            preset: FocusPreset(
              id: 1,
              label: 'Motion fixture',
              moodTag: 'Calm',
              plannedSeconds: 1500,
            ),
            loadLogs: () async => [],
            loadReduceMotion: () async => preferences[0],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final status = tester.widget<AnimatedContainer>(
        find.byKey(const Key('session-status')),
      );
      if (preferences[0] || preferences[1]) {
        expect(status.duration, Duration.zero);
      } else {
        expect(status.duration, greaterThan(Duration.zero));
      }
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
    }
  });
}
