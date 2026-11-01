import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'focus_timer_test.dart' show FakeStopwatch;

Future<void> openTimer(
  WidgetTester tester, {
  required FakeStopwatch stopwatch,
  required Future<int> Function(SessionLog) saveLog,
  void Function(bool?)? onClosed,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final preset = FocusPreset(
    id: 4,
    label: 'Reading',
    moodTag: 'Calm',
    plannedSeconds: 120,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => FocusSessionScreen(
                    preset: preset,
                    stopwatch: stopwatch,
                    saveLog: saveLog,
                  ),
                ),
              );
              onClosed?.call(result);
            },
            child: const Text('Open session'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open session'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Finish freezes one receipt, blocks pending Back, and keeps saved ID',
    (tester) async {
      final stopwatch = FakeStopwatch();
      final pending = Completer<int>();
      final writes = <SessionLog>[];
      bool? closed;
      await openTimer(
        tester,
        stopwatch: stopwatch,
        saveLog: (log) {
          writes.add(log);
          return pending.future;
        },
        onClosed: (value) => closed = value,
      );
      await tester.tap(find.text('Start session'));
      stopwatch.advance(const Duration(milliseconds: 5900));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Finish'));
      await tester.tap(find.text('Finish'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, isNull);
      expect(writes, hasLength(1));
      expect(writes.single.id, isNull);
      expect(writes.single.presetId, 4);
      expect(writes.single.plannedSecondsSnapshot, 120);
      expect(writes.single.completedSeconds, 5);
      expect(writes.single.moodTagSnapshot, 'Calm');
      expect(writes.single.source, 'timer');
      expect(writes.single.status, 'finished');
      expect(stopwatch.isRunning, isFalse);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Reset'),
            )
            .onPressed,
        isNull,
      );
      stopwatch.advance(const Duration(seconds: 40));
      pending.complete(81);
      await tester.pumpAndSettle();
      expect(find.text('Session saved'), findsOneWidget);
      expect(find.text('Saved entry #81'), findsOneWidget);
      expect(find.text('Planned: 2 min'), findsOneWidget);
      expect(find.text('Completed: 0 min 5 sec'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
      await tester.tap(find.text('Return to presets'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(writes, hasLength(1));
    },
  );

  testWidgets('Failed insert retry reuses the original frozen receipt', (
    tester,
  ) async {
    final stopwatch = FakeStopwatch();
    final writes = <SessionLog>[];
    await openTimer(
      tester,
      stopwatch: stopwatch,
      saveLog: (log) async {
        writes.add(log);
        if (writes.length == 1) throw StateError('Write unavailable');
        return 82;
      },
    );
    await tester.tap(find.text('Start session'));
    stopwatch.advance(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Save failed'), findsOneWidget);
    expect(find.text('Not saved yet.'), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);
    expect(stopwatch.isRunning, isFalse);
    stopwatch.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes[1].toMap(), writes[0].toMap());
    expect(writes[1].completedSeconds, 7);
    expect(find.text('Saved entry #82'), findsOneWidget);
    expect(find.text('Retry save'), findsNothing);
  });

  testWidgets('Background pauses active time and foreground requires Resume', (
    tester,
  ) async {
    final stopwatch = FakeStopwatch();
    var writes = 0;
    await openTimer(
      tester,
      stopwatch: stopwatch,
      saveLog: (_) async {
        writes++;
        return 1;
      },
    );
    await tester.tap(find.text('Start session'));
    stopwatch.advance(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(stopwatch.isRunning, isFalse);
    stopwatch.advance(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Completed: 0 min 4 sec'), findsOneWidget);
    expect(stopwatch.isRunning, isFalse);
    await tester.tap(find.text('Resume'));
    stopwatch.advance(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Completed: 0 min 6 sec'), findsOneWidget);
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(stopwatch.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reset and Back confirmations pause first and Cancel stays paused',
    (tester) async {
      final stopwatch = FakeStopwatch();
      var writes = 0;
      await openTimer(
        tester,
        stopwatch: stopwatch,
        saveLog: (_) async {
          writes++;
          return 1;
        },
      );
      await tester.tap(find.text('Start session'));
      stopwatch.advance(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset this session?'), findsOneWidget);
      expect(stopwatch.isRunning, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      stopwatch.advance(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Completed: 0 min 8 sec'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      stopwatch.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard this session?'), findsOneWidget);
      expect(stopwatch.isRunning, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Completed: 0 min 10 sec'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Start session'), findsOneWidget);
      expect(stopwatch.elapsed, Duration.zero);
      expect(writes, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open session'), findsOneWidget);
    },
  );
}
