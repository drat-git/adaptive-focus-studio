import 'dart:async';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/history_screen.dart';
import 'package:adaptive_focus_studio/screens/session_log_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_entry_test.dart' show enterCompletedTime, openEntry, presets;

SessionLog savedLog({
  String source = 'timer',
  int? startedAt,
  int completedSeconds = 1200,
}) {
  return SessionLog(
    id: 6,
    presetId: 9,
    startedAt:
        startedAt ??
        DateTime(2026, 10, 30, 12, 34, 56, 789).millisecondsSinceEpoch,
    plannedSecondsSnapshot: 1500,
    completedSeconds: completedSeconds,
    moodTagSnapshot: 'Calm',
    status: 'finished',
    source: source,
    note: 'Original note',
  );
}

class EditingDatabase extends DatabaseHelper {
  List<SessionLog> logs = [savedLog(source: 'manual')];
  late Future<int> Function(int) onDelete;

  @override
  Future<List<FocusPreset>> getPresets() async => presets;

  @override
  Future<List<SessionLog>> getSessionLogs({String? moodTag}) async => logs;

  @override
  Future<Map<String, Object?>> getSessionSummary({String? moodTag}) async => {
    'count': logs.isEmpty ? 0 : 1,
    'averageSeconds': logs.isEmpty ? null : 1200.0,
  };

  @override
  Future<int> deleteSessionLog(int id) => onDelete(id);
}

Future<void> openHistory(WidgetTester tester, EditingDatabase database) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: HistoryScreen(databaseHelper: database)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Exact prefill and equivalent formatting keep an unchanged timer',
    (tester) async {
      var writes = 0;
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          log: savedLog(completedSeconds: 3661),
          saveLog: (_) async {
            writes++;
            return 1;
          },
        ),
        (value) => closed = value,
      );
      for (final unit in ['hours', 'minutes', 'seconds']) {
        expect(
          tester
              .widget<TextFormField>(find.byKey(Key('completed-$unit')))
              .controller!
              .text,
          '1',
        );
      }
      // The same numeric sum with an invalid component must still be rejected.
      await enterCompletedTime(tester, minutes: '61', seconds: '1');
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Use 0 to 59 minutes.'), findsOneWidget);
      expect(closed, isNull);
      expect(writes, 0);
      await enterCompletedTime(
        tester,
        hours: '01',
        minutes: '01',
        seconds: '01',
      );
      await tester.pump();
      expect(find.text('Source: Measured timer'), findsOneWidget);
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(writes, 0);
    },
  );

  testWidgets(
    'Unchanged date/time picker confirmation keeps a measured timer',
    (tester) async {
      var writes = 0;
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          log: savedLog(),
          now: () => DateTime(2026, 10, 31, 15),
          saveLog: (_) async {
            writes++;
            return 1;
          },
        ),
        (value) => closed = value,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.text('Preset: Reading (#9)'), findsOneWidget);
      expect(find.text('Planned snapshot: 25 min'), findsOneWidget);
      await tester.tap(find.byKey(const Key('session-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-time')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      expect(find.text('Source: Measured timer'), findsOneWidget);
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(writes, 0);
    },
  );

  testWidgets(
    'A correction keeps identity, snapshots and an unchanged timestamp',
    (tester) async {
      final timestamp = DateTime(
        2030,
        10,
        30,
        12,
        34,
        56,
        789,
      ).millisecondsSinceEpoch;
      final pending = Completer<int>();
      final writes = <SessionLog>[];
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          log: savedLog(startedAt: timestamp),
          now: () => DateTime(2026, 10, 31),
          saveLog: (log) {
            writes.add(log);
            return pending.future;
          },
        ),
        (value) => closed = value,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Corrected note');
      await tester.pump();
      expect(find.text('Source after save: Corrected timer'), findsOneWidget);
      await tester.tap(find.text('Save entry'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, isNull);
      expect(writes, hasLength(1));
      expect(writes.single.id, 6);
      expect(writes.single.presetId, 9);
      expect(writes.single.plannedSecondsSnapshot, 1500);
      expect(writes.single.startedAt, timestamp);
      expect(writes.single.source, 'edited_timer');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      pending.complete(1);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );

  testWidgets(
    'Failed manual correction retains its draft and missing update refreshes',
    (tester) async {
      final writes = <SessionLog>[];
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          log: savedLog(source: 'manual'),
          saveLog: (log) async {
            writes.add(log);
            if (writes.length == 1) throw StateError('Write unavailable');
            return 0;
          },
        ),
        (value) => closed = value,
      );
      await enterCompletedTime(tester, minutes: '15');
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save this entry. Your changes are still here. Try again.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('completed-minutes')))
            .controller!
            .text,
        '15',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(
        find.text('This entry no longer exists. Return to History to refresh.'),
        findsOneWidget,
      );
      expect(writes.map((log) => log.id), [6, 6]);
      expect(writes.every((log) => log.source == 'manual'), isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save entry'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Return to History'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );

  testWidgets(
    'Delete Cancel preserves data and one pending delete refreshes history',
    (tester) async {
      final database = EditingDatabase();
      final pending = Completer<int>();
      final deletedIds = <int>[];
      database.onDelete = (id) {
        deletedIds.add(id);
        return pending.future;
      };
      await openHistory(tester, database);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete entry #6?'), findsOneWidget);
      expect(
        find.text(
          'This permanently removes the session entry. The preset will be kept.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletedIds, isEmpty);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Delete entry #6?'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(deletedIds, [6]);
      database.logs = [];
      pending.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('Entry deleted.'), findsOneWidget);
      expect(find.text('0 finished entries'), findsOneWidget);
      expect(
        find.text('No session history yet. Finish a session to see it here.'),
        findsOneWidget,
      );
      expect(presets, hasLength(2));
    },
  );

  testWidgets(
    'Delete failure remains retryable and missing is not reported as deleted',
    (tester) async {
      final database = EditingDatabase();
      var calls = 0;
      database.onDelete = (_) async {
        calls++;
        if (calls == 1) throw StateError('Write unavailable');
        database.logs = [];
        return 0;
      };
      await openHistory(tester, database);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not delete this entry. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      expect(
        find.text('This entry no longer exists. Reloading history.'),
        findsOneWidget,
      );
      expect(find.text('Entry deleted.'), findsNothing);
      expect(calls, 2);
    },
  );
}
