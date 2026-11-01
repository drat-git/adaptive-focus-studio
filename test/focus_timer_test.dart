import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStopwatch extends Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  void advance(Duration duration) {
    if (_running) _elapsed += duration;
  }

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isRunning => _running;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() => _elapsed = Duration.zero;
}

Future<void> showTimer(
  WidgetTester tester, {
  FocusPreset? preset,
  required FakeStopwatch stopwatch,
  Future<int> Function(SessionLog)? saveLog,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: FocusSessionScreen(
        preset: preset,
        stopwatch: stopwatch,
        saveLog: saveLog,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Focus timer measures active time and pauses before resuming', (
    tester,
  ) async {
    final stopwatch = FakeStopwatch();
    await showTimer(
      tester,
      preset: FocusPreset(
        id: 4,
        label: 'Reading',
        moodTag: 'Calm',
        plannedSeconds: 1250,
      ),
      stopwatch: stopwatch,
    );
    expect(find.text('20:50'), findsOneWidget);
    expect(find.text('Planned time: 20 min 50 sec'), findsOneWidget);
    await tester.tap(find.text('Start session'));
    await tester.pump();
    expect(find.text('Running'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(stopwatch.isRunning, isTrue);

    stopwatch.advance(const Duration(milliseconds: 5900));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('20:45'), findsOneWidget);
    expect(find.text('Completed: 0 min 5 sec'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('20:45'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(stopwatch.isRunning, isFalse);
    stopwatch.advance(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('20:45'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    stopwatch.advance(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('20:42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(stopwatch.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Focus timer uses the chosen duration and caps completion', (
    tester,
  ) async {
    final stopwatch = FakeStopwatch();
    final preset = FocusPreset(
      id: 4,
      label: 'Short block',
      moodTag: 'Focused',
      plannedSeconds: 60,
    );
    await showTimer(
      tester,
      preset: preset,
      stopwatch: stopwatch,
      saveLog: (_) async => 8,
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(120);
    await tester.pump();
    expect(find.text('02:00'), findsOneWidget);
    expect(preset.plannedSeconds, 60);
    await tester.tap(find.text('Start session'));
    stopwatch.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Session saved'), findsOneWidget);
    expect(find.text('Saved entry #8'), findsOneWidget);
    expect(find.text('Completed: 2 min'), findsOneWidget);
    expect(find.text('Source: Measured timer'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(stopwatch.isRunning, isFalse);
    stopwatch.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Completed: 2 min'), findsOneWidget);
  });

  testWidgets('Focus timer requires a saved preset before Start', (
    tester,
  ) async {
    final stopwatch = FakeStopwatch();
    await showTimer(tester, stopwatch: stopwatch);
    expect(find.text('No preset selected.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start session'),
          )
          .onPressed,
      isNull,
    );
    await showTimer(
      tester,
      preset: FocusPreset(
        label: 'Unsaved block',
        moodTag: 'Calm',
        plannedSeconds: 1500,
      ),
      stopwatch: stopwatch,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start session'),
          )
          .onPressed,
      isNull,
    );
    expect(stopwatch.isRunning, isFalse);
  });
}
