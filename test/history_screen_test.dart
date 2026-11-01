import 'dart:async';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestHistoryDatabase extends DatabaseHelper {
  List<SessionLog> logs = [];
  Completer<List<SessionLog>>? pendingLogs;
  bool failRead = false;
  final requestedMoods = <String?>[];
  final summaries = <String?, Map<String, Object?>>{
    null: {'count': 0, 'averageSeconds': null},
  };

  @override
  Future<List<FocusPreset>> getPresets() async => [
    FocusPreset(
      id: 7,
      label: 'Renamed study block',
      moodTag: 'Focused',
      plannedSeconds: 3600,
    ),
  ];

  @override
  Future<List<SessionLog>> getSessionLogs({String? moodTag}) async {
    if (failRead) throw StateError('Read unavailable');
    return pendingLogs?.future ?? logs;
  }

  @override
  Future<Map<String, Object?>> getSessionSummary({String? moodTag}) async {
    requestedMoods.add(moodTag);
    return summaries[moodTag] ?? {'count': 0, 'averageSeconds': null};
  }
}

SessionLog historyLog({
  required int id,
  required String source,
  String mood = 'Calm',
  String status = 'finished',
  int completed = 600,
}) {
  return SessionLog(
    id: id,
    presetId: 7,
    startedAt: DateTime.utc(2026, 10, 31, 12, id).millisecondsSinceEpoch,
    plannedSecondsSnapshot: 1500,
    completedSeconds: completed,
    moodTagSnapshot: mood,
    status: status,
    source: source,
  );
}

Future<void> showHistory(
  WidgetTester tester,
  TestHistoryDatabase database,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: HistoryScreen(databaseHelper: database)),
    ),
  );
}

Future<void> chooseMood(WidgetTester tester, String mood) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mood).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Loading and empty history do not invent an average', (
    tester,
  ) async {
    final database = TestHistoryDatabase()
      ..pendingLogs = Completer<List<SessionLog>>();
    await showHistory(tester, database);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    database.pendingLogs!.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('No session history yet. Finish a session to see it here.'),
      findsOneWidget,
    );
    expect(find.text('No finished sessions yet.'), findsOneWidget);
    expect(find.text('0 finished entries'), findsOneWidget);
    expect(
      find.text('Average completed time, rounded to seconds.'),
      findsNothing,
    );
  });

  testWidgets(
    'History shows sources and filters saved mood instead of parent mood',
    (tester) async {
      final database = TestHistoryDatabase()
        ..logs = [
          historyLog(id: 3, source: 'edited_timer', completed: 1800),
          historyLog(
            id: 2,
            source: 'manual',
            mood: 'Focused',
            status: 'cancelled',
            completed: 900,
          ),
          historyLog(id: 1, source: 'timer'),
        ];
      database.summaries[null] = {'count': 2, 'averageSeconds': 1200.0};
      database.summaries['Calm'] = {'count': 2, 'averageSeconds': 1200.0};
      await showHistory(tester, database);
      await tester.pumpAndSettle();
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('2 finished entries'), findsOneWidget);
      expect(find.text('Renamed study block'), findsNWidgets(3));
      expect(find.text('Source: Measured timer'), findsOneWidget);
      expect(find.text('Source: Manual entry'), findsOneWidget);
      expect(find.text('Source: Corrected timer'), findsOneWidget);
      expect(find.text('Planned: 25 min'), findsNWidgets(3));
      expect(find.text('Completed: 30 min'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Entry #3 ·'), findsOneWidget);

      await chooseMood(tester, 'Calm');
      expect(find.text('Source: Manual entry'), findsNothing);
      expect(find.text('Renamed study block'), findsNWidgets(2));
      expect(find.text('Mood at session: Calm'), findsNWidgets(2));
      expect(find.text('2 finished entries'), findsOneWidget);
      expect(database.requestedMoods.last, 'Calm');

      await chooseMood(tester, 'Focused');
      expect(find.text('Source: Manual entry'), findsOneWidget);
      expect(find.text('No finished sessions for this mood.'), findsOneWidget);
      expect(find.text('0 finished entries'), findsOneWidget);
      await chooseMood(tester, 'Low energy');
      expect(find.text('No sessions match this mood.'), findsOneWidget);
      expect(
        find.text('No session history yet. Finish a session to see it here.'),
        findsNothing,
      );
    },
  );

  testWidgets('Failed read offers a read retry without a write', (
    tester,
  ) async {
    final database = TestHistoryDatabase()..failRead = true;
    await showHistory(tester, database);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load session history. Try again.'),
      findsOneWidget,
    );
    database.failRead = false;
    database.logs = [historyLog(id: 4, source: 'manual', completed: 0)];
    database.summaries[null] = {'count': 1, 'averageSeconds': 0.0};
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load session history. Try again.'),
      findsNothing,
    );
    expect(find.text('Source: Manual entry'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget);
    expect(find.text('1 finished entry'), findsOneWidget);
  });
}
