import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'focus_timer_test.dart' show FakeStopwatch;

Future<void> openRegressionTimer(
  WidgetTester tester,
  FakeStopwatch stopwatch,
  Future<int> Function(SessionLog) saveLog,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => FocusSessionScreen(
                  preset: FocusPreset(
                    id: 7,
                    label: 'Timer fixture',
                    moodTag: 'Focused',
                    plannedSeconds: 60,
                  ),
                  stopwatch: stopwatch,
                  saveLog: saveLog,
                  loadLogs: () async => [],
                ),
              ),
            ),
            child: const Text('Open timer'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open timer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start session'));
  await tester.pump();
}

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Natural completion caps once while its insert is pending', (
    tester,
  ) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    final pending = Completer<int>();
    final writes = <SessionLog>[];
    await openRegressionTimer(tester, stopwatch, (log) {
      writes.add(log);
      return pending.future;
    });
    final finish = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Finish'))
        .onPressed!;
    stopwatch.advance(const Duration(seconds: 90));
    await tester.pump(const Duration(milliseconds: 250));
    finish();
    await tester.pump(const Duration(seconds: 5));
    expect(writes, hasLength(1));
    expect(writes.single.completedSeconds, 60);
    expect(writes.single.plannedSecondsSnapshot, 60);
    expect(writes.single.moodTagSnapshot, 'Focused');
    expect(stopwatch.isRunning, isFalse);
    pending.complete(101);
    await tester.pumpAndSettle();
    expect(find.text('Saved entry #101'), findsOneWidget);
    expect(find.text('Completed: 1 min'), findsOneWidget);
  });

  testWidgets('Finish accepts zero and floors fractional active seconds', (
    tester,
  ) async {
    tallView(tester);
    const cases = {0: 0, 1999: 1};
    for (final entry in cases.entries) {
      final stopwatch = FakeStopwatch();
      final writes = <SessionLog>[];
      await openRegressionTimer(tester, stopwatch, (log) async {
        writes.add(log);
        return 102;
      });
      stopwatch.advance(Duration(milliseconds: entry.key));
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single.completedSeconds, entry.value);
      expect(find.text('Session saved'), findsOneWidget);
    }
  });

  testWidgets('Reset and Back at the cap never open a dialog over saving', (
    tester,
  ) async {
    tallView(tester);
    for (final actionName in ['Reset', 'Back']) {
      final stopwatch = FakeStopwatch();
      final pending = Completer<int>();
      var writes = 0;
      await openRegressionTimer(tester, stopwatch, (_) {
        writes++;
        return pending.future;
      });
      final action = actionName == 'Reset'
          ? tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Reset'),
                )
                .onPressed!
          : tester
                .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.arrow_back),
                )
                .onPressed!;
      stopwatch.advance(const Duration(seconds: 60));
      action();
      await tester.pump();
      expect(writes, 1, reason: actionName);
      expect(find.byType(AlertDialog), findsNothing, reason: actionName);
      expect(find.byType(FocusSessionScreen), findsOneWidget);
      pending.complete(103);
      await tester.pumpAndSettle();
      expect(find.text('Saved entry #103'), findsOneWidget);
    }
  });

  testWidgets('Disposal during a pending insert ignores its late UI result', (
    tester,
  ) async {
    tallView(tester);
    final stopwatch = FakeStopwatch();
    final pending = Completer<int>();
    var writes = 0;
    await openRegressionTimer(tester, stopwatch, (_) {
      writes++;
      return pending.future;
    });
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(104);
    await tester.pump();
    expect(writes, 1);
    expect(stopwatch.isRunning, isFalse);
    expect(tester.takeException(), isNull);
  });
}
