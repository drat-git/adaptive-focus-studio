import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:adaptive_focus_studio/screens/history_screen.dart';
import 'package:adaptive_focus_studio/screens/home_screen.dart';
import 'package:adaptive_focus_studio/screens/session_log_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final preset = FocusPreset(
  id: 3,
  label: 'Reading',
  moodTag: 'Calm',
  plannedSeconds: 1500,
);

class RecoveryDatabase extends DatabaseHelper {
  int inserts = 0;
  int reads = 0;
  SessionLog? saved;

  @override
  Future<List<FocusPreset>> getPresets() async => [preset];

  @override
  Future<int> insertSessionLog(SessionLog log) async {
    inserts++;
    saved = SessionLog.fromMap({...log.toMap(), 'id': 37});
    return 37;
  }

  @override
  Future<List<SessionLog>> getSessionLogs({String? moodTag}) async {
    reads++;
    if (reads == 2) throw StateError('Refresh unavailable');
    return saved == null ? [] : [saved!];
  }

  @override
  Future<Map<String, Object?>> getSessionSummary({String? moodTag}) async {
    return {
      'count': saved == null ? 0 : 1,
      'averageSeconds': saved?.completedSeconds.toDouble(),
    };
  }
}

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'Saved session return refreshes Presets and retries only its read',
    (tester) async {
      useTallView(tester);
      var reads = 0;
      var saved = false;
      final summaryMoods = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loadSummary: (mood) async {
              summaryMoods.add(mood);
              if (mood == 'Focused') {
                return {'count': 2, 'averageSeconds': 90.0};
              }
              return {
                'count': saved ? 1 : 0,
                'averageSeconds': saved ? 60.0 : null,
              };
            },
            loadPresets: () async {
              reads++;
              if (reads == 2) throw StateError('Refresh unavailable');
              return [preset];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open session'));
      await tester.pumpAndSettle();
      expect(find.byType(FocusSessionScreen), findsOneWidget);
      // The saved route result is independent from the later catalog read.
      saved = true;
      tester.state<NavigatorState>(find.byType(Navigator)).pop(true);
      await tester.pumpAndSettle();
      expect(find.text('Could not load presets.'), findsOneWidget);
      expect(reads, 2);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.byType(FocusSessionScreen), findsNothing);
      expect(find.text('1 finished entry'), findsOneWidget);
      expect(find.text('1 min'), findsWidgets);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Focused').last);
      await tester.pumpAndSettle();
      expect(summaryMoods.last, 'Focused');
      expect(find.text('No presets match this mood.'), findsOneWidget);
      expect(find.text('2 finished entries'), findsOneWidget);
      expect(find.text('1 min 30 sec'), findsOneWidget);
    },
  );

  testWidgets('A History refresh failure after insertion retries no insert', (
    tester,
  ) async {
    useTallView(tester);
    final database = RecoveryDatabase();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryScreen(databaseHelper: database)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manual entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('completed-minutes')), '1');
    await tester.enterText(find.byKey(const Key('completed-seconds')), '0');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(database.inserts, 1);
    expect(find.byType(SessionLogEditor), findsNothing);
    expect(
      find.text('Could not load session history. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(database.inserts, 1);
    expect(database.reads, 3);
    expect(find.text('1 finished entry'), findsOneWidget);
    expect(find.text('Source: Manual entry'), findsOneWidget);
  });
}
