import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'focus_timer_test.dart' show FakeStopwatch;

final preset = FocusPreset(
  id: 4,
  label: 'Reading',
  moodTag: 'Calm',
  plannedSeconds: 1500,
);

List<SessionLog> history({int median = 1200}) {
  return [
    SessionLog(
      id: 3,
      presetId: 4,
      startedAt: 3000,
      plannedSecondsSnapshot: 1500,
      completedSeconds: median,
      moodTagSnapshot: 'Calm',
      status: 'finished',
      source: 'manual',
    ),
    SessionLog(
      id: 2,
      presetId: 4,
      startedAt: 2000,
      plannedSecondsSnapshot: 1500,
      completedSeconds: 600,
      moodTagSnapshot: 'Calm',
      status: 'finished',
      source: 'timer',
    ),
    SessionLog(
      id: 1,
      presetId: 4,
      startedAt: 1000,
      plannedSecondsSnapshot: 1500,
      completedSeconds: 3600,
      moodTagSnapshot: 'Calm',
      status: 'finished',
      source: 'edited_timer',
    ),
  ];
}

Future<void> showScout(
  WidgetTester tester, {
  FocusPreset? selectedPreset,
  required FakeStopwatch stopwatch,
  required Future<List<SessionLog>> Function() loadLogs,
  Future<int> Function(SessionLog)? saveLog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FocusSessionScreen(
        preset: selectedPreset,
        stopwatch: stopwatch,
        loadLogs: loadLogs,
        saveLog: saveLog,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Scout Apply fills only duration and allows manual adjustment', (
    tester,
  ) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    var writes = 0;
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () async => history(),
      saveLog: (_) async {
        writes++;
        return 1;
      },
    );
    expect(find.text('Suggested duration: 20 min'), findsOneWidget);
    expect(find.text('Fixed baseline: 25 min'), findsOneWidget);
    expect(find.textContaining('Manual entry'), findsOneWidget);
    expect(find.textContaining('Corrected timer'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1200);
    expect(preset.plannedSeconds, 1500);
    expect(stopwatch.isRunning, isFalse);
    expect(writes, 0);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1800);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1800);
    expect(
      find.text('Duration set to 20 min. Start when ready.'),
      findsNothing,
    );
    expect(writes, 0);
  });

  testWidgets('Not now dismisses only the current suggestion', (tester) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    var writes = 0;
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () async => history(),
      saveLog: (_) async {
        writes++;
        return 1;
      },
    );
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(find.text('Session Scout'), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1500);
    expect(stopwatch.isRunning, isFalse);
    expect(writes, 0);
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () async => history(median: 1800),
    );
    expect(find.text('Suggested duration: 30 min'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1500);
  });

  testWidgets('Scout read retry and feedback leave the core timer available', (
    tester,
  ) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    var reads = 0;
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () async {
        reads++;
        if (reads == 1) throw StateError('Read unavailable');
        return [];
      },
    );
    expect(
      find.textContaining('Could not load Session Scout history.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start session'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.textContaining('Not enough history.'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
    await showScout(
      tester,
      stopwatch: stopwatch,
      loadLogs: () async => history(),
    );
    expect(
      find.text(
        'Choose a saved preset with a valid mood to use Session Scout.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start session'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Queued Apply and late history cannot change an active plan', (
    tester,
  ) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    var writes = 0;
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () async => history(),
      saveLog: (_) async {
        writes++;
        return 1;
      },
    );
    final apply = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Apply'))
        .onPressed!;
    await tester.tap(find.text('Start session'));
    apply();
    await tester.pump();
    expect(find.text('Planned time: 25 min'), findsOneWidget);
    expect(find.text('Session Scout'), findsNothing);
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());

    final pending = Completer<List<SessionLog>>();
    await showScout(
      tester,
      selectedPreset: preset,
      stopwatch: stopwatch,
      loadLogs: () => pending.future,
      saveLog: (_) async {
        writes++;
        return 1;
      },
    );
    expect(find.text('Loading recent history…'), findsOneWidget);
    await tester.tap(find.text('Start session'));
    pending.complete(history());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Planned time: 25 min'), findsOneWidget);
    expect(find.text('Session Scout'), findsNothing);
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
