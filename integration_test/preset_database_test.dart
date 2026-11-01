import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

FocusPreset makePreset({
  int? id,
  String label = 'Reading block',
  String moodTag = 'Calm',
  int plannedSeconds = 1500,
}) {
  return FocusPreset(
    id: id,
    label: label,
    moodTag: moodTag,
    plannedSeconds: plannedSeconds,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const filename = 'preset_database_test.db';
  final helper = DatabaseHelper(databaseName: filename);
  late String testPath;

  setUp(() async {
    testPath = join(await getDatabasesPath(), filename);
    await helper.close();
    await deleteDatabase(testPath);
  });

  tearDown(() async {
    await helper.close();
    await deleteDatabase(testPath);
  });

  testWidgets('Creates, reads, updates and deletes presets by saved ID', (
    tester,
  ) async {
    expect(await helper.getPresets(), isEmpty);
    expect(await helper.getPreset(99999), isNull);
    final id = await helper.insertPreset(
      makePreset(label: "  Study's focus  "),
    );
    final otherId = await helper.insertPreset(
      makePreset(label: "Study's focus", moodTag: 'Focused'),
    );
    expect(id, greaterThan(0));
    expect(otherId, isNot(id));
    final presets = await helper.getPresets();
    expect(presets.map((preset) => preset.id).toList(), [id, otherId]);
    expect((await helper.getPreset(id))!.label, "Study's focus");
    expect((await helper.getPreset(otherId))!.moodTag, 'Focused');

    const literalText = "x'); DROP TABLE focus_presets;--";
    final changed = makePreset(
      id: id,
      label: literalText,
      moodTag: 'Low energy',
      plannedSeconds: 600,
    );
    expect(await helper.updatePreset(changed), 1);
    expect((await helper.getPreset(id))!.toMap(), changed.toMap());
    expect((await helper.getPreset(otherId))!.label, "Study's focus");
    expect(await helper.getPresets(), hasLength(2));

    await helper.close();
    expect((await helper.getPreset(id))!.toMap(), changed.toMap());
    expect(await helper.deletePreset(id), 1);
    expect(await helper.getPreset(id), isNull);
    expect((await helper.getPresets()).single.id, otherId);
    expect(await helper.deletePreset(id), 0);
    expect(await helper.updatePreset(changed), 0);
  });

  testWidgets('Rejects invalid operation identities without changing rows', (
    tester,
  ) async {
    final id = await helper.insertPreset(makePreset());
    await expectLater(
      helper.insertPreset(makePreset(id: id)),
      throwsArgumentError,
    );
    await expectLater(helper.updatePreset(makePreset()), throwsArgumentError);
    await expectLater(helper.getPreset(0), throwsArgumentError);
    await expectLater(helper.getPreset(-1), throwsArgumentError);
    await expectLater(helper.deletePreset(0), throwsArgumentError);
    await expectLater(helper.deletePreset(-1), throwsArgumentError);
    expect(await helper.getPresets(), hasLength(1));
    expect((await helper.getPreset(id))!.label, 'Reading block');
    expect(await helper.deletePreset(99999), 0);
    expect(await helper.updatePreset(makePreset(id: 99999)), 0);
  });

  testWidgets('Keeps protected history and exposes the foreign-key failure', (
    tester,
  ) async {
    final id = await helper.insertPreset(makePreset());
    final db = await helper.database;
    final fixture = SessionLog(
      presetId: id,
      startedAt: 1793448000000,
      plannedSecondsSnapshot: 1500,
      completedSeconds: 1200,
      moodTagSnapshot: 'Calm',
      status: 'finished',
      source: 'timer',
    );
    final logId = await db.insert('session_logs', fixture.toMap());
    await expectLater(
      helper.deletePreset(id),
      throwsA(isA<DatabaseException>()),
    );
    expect(await helper.getPreset(id), isNotNull);
    expect(await db.query('session_logs'), hasLength(1));
    expect(
      await helper.updatePreset(
        makePreset(id: id, moodTag: 'Focused', plannedSeconds: 3600),
      ),
      1,
    );
    final rows = await db.query(
      'session_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    final savedLog = SessionLog.fromMap(rows.single);
    expect(savedLog.presetId, id);
    expect(savedLog.plannedSecondsSnapshot, 1500);
    expect(savedLog.moodTagSnapshot, 'Calm');
    expect(savedLog.completedSeconds, 1200);
    expect(savedLog.source, 'timer');
    expect(
      await db.delete('session_logs', where: 'id = ?', whereArgs: [logId]),
      1,
    );
    expect(await helper.deletePreset(id), 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
