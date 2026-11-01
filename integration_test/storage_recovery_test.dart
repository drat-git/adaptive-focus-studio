import 'dart:async';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/data/settings_store.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/focus_session_screen.dart';
import 'package:adaptive_focus_studio/screens/presets_screen.dart';
import 'package:adaptive_focus_studio/screens/session_log_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../test/focus_timer_test.dart' show FakeStopwatch;

FocusPreset fixturePreset({
  int? id,
  String label = 'Native fixture',
  String mood = 'Calm',
  int seconds = 1500,
}) {
  return FocusPreset(
    id: id,
    label: label,
    moodTag: mood,
    plannedSeconds: seconds,
  );
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition,
  String label,
) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for $label.');
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  double scroll = 180,
}) async {
  await tester.scrollUntilVisible(
    find.text(text),
    scroll,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const filename = 'storage_recovery_test.db';
  const prefix = 'storage_recovery_test.';
  final helper = DatabaseHelper(databaseName: filename);
  late String testPath;
  late SharedPreferencesAsync preferences;

  setUp(() async {
    testPath = join(await getDatabasesPath(), filename);
    await helper.close();
    await deleteDatabase(testPath);
    preferences = SharedPreferencesAsync();
    await preferences.remove('${prefix}defaultDurationSeconds');
    await preferences.remove('${prefix}reduceMotion');
  });

  tearDown(() async {
    await helper.close();
    await deleteDatabase(testPath);
    await preferences.remove('${prefix}defaultDurationSeconds');
    await preferences.remove('${prefix}reduceMotion');
  });

  testWidgets(
    'SQLite reopen and fresh preference reader retain saved values and snapshots',
    (tester) async {
      final settings = SettingsStore(keyPrefix: prefix);
      await settings.saveDefaultDurationSeconds(1801);
      await settings.saveReduceMotion(true);
      final parentId = await helper.insertPreset(fixturePreset(seconds: 1801));
      final logId = await helper.insertSessionLog(
        SessionLog(
          presetId: parentId,
          startedAt: 1000,
          plannedSecondsSnapshot: 1801,
          completedSeconds: 1201,
          moodTagSnapshot: 'Calm',
          status: 'finished',
          source: 'manual',
          note: 'Disposable persistence fixture',
        ),
      );
      await helper.updatePreset(
        fixturePreset(
          id: parentId,
          label: 'Renamed fixture',
          mood: 'Focused',
          seconds: 3600,
        ),
      );
      await helper.close();

      final parent = (await helper.getPreset(parentId))!;
      final log = (await helper.getSessionLog(logId))!;
      final freshSettings = SettingsStore(keyPrefix: prefix);
      expect(parent.label, 'Renamed fixture');
      expect(parent.moodTag, 'Focused');
      expect(parent.plannedSeconds, 3600);
      expect(log.presetId, parentId);
      expect(log.plannedSecondsSnapshot, 1801);
      expect(log.completedSeconds, 1201);
      expect(log.moodTagSnapshot, 'Calm');
      expect(log.note, 'Disposable persistence fixture');
      expect(await freshSettings.getDefaultDurationSeconds(), 1801);
      expect(await freshSettings.getReduceMotion(), isTrue);
    },
  );

  testWidgets(
    'Real history Apply and finish survive a failed catalog read without a second insert',
    (tester) async {
      final parentId = await helper.insertPreset(fixturePreset(seconds: 120));
      for (var index = 0; index < 3; index++) {
        await helper.insertSessionLog(
          SessionLog(
            presetId: parentId,
            startedAt: (index + 1) * 1000,
            plannedSecondsSnapshot: 120,
            completedSeconds: [1200, 1500, 1800][index],
            moodTagSnapshot: 'Calm',
            status: 'finished',
            source: 'manual',
          ),
        );
      }
      final stopwatch = FakeStopwatch();
      var failNextRead = false;
      var insertCalls = 0;
      int? savedId;
      late Zone catalogZone;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              catalogZone = Zone.current;
              return Scaffold(
                body: PresetsScreen(
                  loadPresets: () async {
                    if (failNextRead) {
                      failNextRead = false;
                      throw StateError(
                        'Controlled read failure after saved receipt',
                      );
                    }
                    return helper.getPresets();
                  },
                  loadSummary: (mood) =>
                      helper.getSessionSummary(moodTag: mood),
                  onAddPreset: () async => false,
                  onEditPreset: (_) async => false,
                  onOpenSession: (preset) async =>
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => FocusSessionScreen(
                            preset: preset,
                            stopwatch: stopwatch,
                            loadLogs: () => helper.getSessionLogs(),
                            saveLog: (log) async {
                              insertCalls++;
                              final id = await helper.insertSessionLog(log);
                              savedId = id;
                              failNextRead = true;
                              return id;
                            },
                          ),
                        ),
                      ) ??
                      false,
                ),
              );
            },
          ),
        ),
      );
      await waitFor(
        tester,
        () => find.text('3 finished entries').evaluate().isNotEmpty,
        'initial catalog',
      );
      // Live frames and synthetic taps must share the catalog's error zone.
      await catalogZone.run<Future<void>>(
        () => tapText(tester, 'Open session'),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Session Scout'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await waitFor(
        tester,
        () => find.text('Suggested duration: 25 min').evaluate().isNotEmpty,
        'ready Scout suggestion',
      );
      await tapText(tester, 'Apply');
      expect(stopwatch.isRunning, isFalse);
      expect(insertCalls, 0);
      expect(await helper.getSessionLogs(), hasLength(3));
      expect((await helper.getPreset(parentId))!.plannedSeconds, 120);
      await tapText(tester, 'Start session', scroll: -180);
      stopwatch.advance(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 250));
      await tapText(tester, 'Finish');
      await waitFor(
        tester,
        () => find.text('Session saved').evaluate().isNotEmpty,
        'saved receipt',
      );
      expect(savedId, isNotNull);
      final receipt = (await helper.getSessionLog(savedId!))!;
      expect(receipt.plannedSecondsSnapshot, 1500);
      expect(receipt.completedSeconds, 7);
      expect(receipt.source, 'timer');
      await tapText(tester, 'Return to presets');
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.text('Could not load presets.').evaluate().isNotEmpty,
        'controlled refresh error',
      );
      expect(await helper.getSessionLogs(), hasLength(4));
      await tapText(tester, 'Try again');
      await waitFor(
        tester,
        () => find.text('4 finished entries').evaluate().isNotEmpty,
        'read-only retry',
      );
      expect(insertCalls, 1);
      expect(await helper.getSessionLogs(), hasLength(4));
      expect((await helper.getPreset(parentId))!.plannedSeconds, 120);
    },
  );

  testWidgets(
    'Stale parent FK failure retains a manual draft and another parent recovers it',
    (tester) async {
      final staleId = await helper.insertPreset(
        fixturePreset(label: 'Stale fixture'),
      );
      final validId = await helper.insertPreset(
        fixturePreset(label: 'Valid fixture', mood: 'Focused', seconds: 1800),
      );
      final choices = await helper.getPresets();
      expect(await helper.deletePreset(staleId), 1);
      bool? closed;
      DatabaseException? failure;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  closed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => SessionLogEditor(
                      presets: choices,
                      saveLog: (log) async {
                        attempts++;
                        try {
                          return await helper.insertSessionLog(log);
                        } on DatabaseException catch (error) {
                          failure = error;
                          rethrow;
                        }
                      },
                    ),
                  );
                },
                child: const Text('Open entry'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open entry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '600');
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(
        find.byType(TextFormField).last,
        'Keep this draft',
      );
      await tester.tap(find.text('Save entry'));
      await waitFor(
        tester,
        () => find
            .text(
              'Could not save this entry. Your changes are still here. Try again.',
            )
            .evaluate()
            .isNotEmpty,
        'FK save failure',
      );
      expect(failure, isA<DatabaseException>());
      expect(closed, isNull);
      expect(await helper.getSessionLogs(), isEmpty);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '600',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'Keep this draft',
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valid fixture (#$validId)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await waitFor(tester, () => closed == true, 'recovered manual insert');
      final saved = (await helper.getSessionLogs()).single;
      expect(attempts, 2);
      expect(saved.presetId, validId);
      expect(saved.plannedSecondsSnapshot, 1800);
      expect(saved.moodTagSnapshot, 'Focused');
      expect(saved.completedSeconds, 600);
      expect(saved.note, 'Keep this draft');
      expect(saved.source, 'manual');
      expect(await helper.getPreset(staleId), isNull);
    },
  );
}
