import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Map<String, Object?> presetRow() {
  return FocusPreset(
    label: 'Reading block',
    moodTag: 'Calm',
    plannedSeconds: 1500,
  ).toMap();
}

Map<String, Object?> logRow(int presetId) {
  return SessionLog(
    presetId: presetId,
    startedAt: 1793448000000,
    plannedSecondsSnapshot: 1500,
    completedSeconds: 1800,
    moodTagSnapshot: 'Calm',
    status: 'finished',
    source: 'manual',
  ).toMap();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const filename = 'database_schema_test.db';
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

  testWidgets('Creates two app tables and a nonunique parent index', (
    tester,
  ) async {
    final db = await helper.database;
    expect(await db.getVersion(), 1);
    expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')), 1);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY name",
    );
    expect(tables.map((row) => row['name']).toList(), [
      'focus_presets',
      'session_logs',
    ]);
    final columns = await db.rawQuery('PRAGMA table_info(session_logs)');
    expect(columns.map((row) => row['name']).toList(), [
      'id',
      'preset_id',
      'started_at_ms',
      'planned_seconds_snapshot',
      'completed_seconds',
      'mood_tag_snapshot',
      'status',
      'source',
      'note',
    ]);
    final foreignKeys = await db.rawQuery(
      'PRAGMA foreign_key_list(session_logs)',
    );
    expect(foreignKeys.single['table'], 'focus_presets');
    expect(foreignKeys.single['from'], 'preset_id');
    expect(foreignKeys.single['to'], 'id');
    expect(foreignKeys.single['on_delete'], 'RESTRICT');
    final indexes = await db.rawQuery('PRAGMA index_list(session_logs)');
    final parentIndex = indexes.singleWhere(
      (row) => row['name'] == 'session_logs_preset_id_idx',
    );
    expect(parentIndex['unique'], 0);
    final indexColumns = await db.rawQuery(
      'PRAGMA index_info(session_logs_preset_id_idx)',
    );
    expect(indexColumns.single['name'], 'preset_id');
  });

  testWidgets('Rejects invalid rows while accepting model boundaries', (
    tester,
  ) async {
    final db = await helper.database;
    final invalidPresets = <Map<String, Object?>>[
      {'id': -1},
      {'label': ''},
      {'label': ' Padded '},
      {'label': List.filled(41, 'a').join()},
      {'mood_tag': 'Other'},
      {'planned_seconds': 59},
      {'planned_seconds': 7201},
      {'planned_seconds': 60.5},
    ];
    for (final change in invalidPresets) {
      await expectLater(
        db.insert('focus_presets', {...presetRow(), ...change}),
        throwsA(isA<DatabaseException>()),
      );
    }
    final presetId = await db.insert('focus_presets', {
      ...presetRow(),
      'label': List.filled(40, '🙂').join(),
      'planned_seconds': 60,
    });
    await db.insert('focus_presets', {...presetRow(), 'planned_seconds': 7200});
    final invalidLogs = <Map<String, Object?>>[
      {'started_at_ms': -1},
      {'planned_seconds_snapshot': 7201},
      {'completed_seconds': -1},
      {'completed_seconds': 7201},
      {'completed_seconds': 1.5},
      {'mood_tag_snapshot': 'Other'},
      {'status': 'running'},
      {'source': 'inferred'},
      {'note': List.filled(241, 'a').join()},
      {'note': null},
    ];
    for (final change in invalidLogs) {
      await expectLater(
        db.insert('session_logs', {...logRow(presetId), ...change}),
        throwsA(isA<DatabaseException>()),
      );
    }
    final zeroLog = logRow(presetId);
    zeroLog.remove('note');
    final id = await db.insert('session_logs', {
      ...zeroLog,
      'completed_seconds': 0,
      'status': 'cancelled',
      'source': 'timer',
    });
    final rows = await db.query(
      'session_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(SessionLog.fromMap(rows.single).note, '');
    await db.insert('session_logs', {
      ...logRow(presetId),
      'completed_seconds': 7200,
      'note': List.filled(240, '🙂').join(),
    });
  });

  testWidgets('Protects parent history and retains independent snapshots', (
    tester,
  ) async {
    final db = await helper.database;
    final presetId = await db.insert('focus_presets', presetRow());
    final duplicateId = await db.insert('focus_presets', presetRow());
    expect(duplicateId, isNot(presetId));
    final logId = await db.insert('session_logs', logRow(presetId));
    await expectLater(
      db.insert('session_logs', logRow(99999)),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('focus_presets', where: 'id = ?', whereArgs: [presetId]),
      throwsA(isA<DatabaseException>()),
    );
    await db.update(
      'focus_presets',
      {'mood_tag': 'Focused', 'planned_seconds': 600},
      where: 'id = ?',
      whereArgs: [presetId],
    );
    final rows = await db.query(
      'session_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    final log = SessionLog.fromMap(rows.single);
    expect(log.presetId, presetId);
    expect(log.plannedSecondsSnapshot, 1500);
    expect(log.completedSeconds, 1800);
    expect(log.moodTagSnapshot, 'Calm');
    expect(log.source, 'manual');
    expect(
      await db.delete('session_logs', where: 'id = ?', whereArgs: [logId]),
      1,
    );
    expect(
      await db.delete('focus_presets', where: 'id = ?', whereArgs: [presetId]),
      1,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  testWidgets('Shares opens and waits for close before reopening saved rows', (
    tester,
  ) async {
    final opens = await Future.wait([helper.database, helper.database]);
    expect(identical(opens[0], opens[1]), isTrue);
    final id = await opens.first.insert('focus_presets', presetRow());
    final closing = helper.close();
    final repeatedClose = helper.close();
    final reopening = helper.database;
    await Future.wait([closing, repeatedClose]);
    final reopened = await reopening;
    expect(opens.first.isOpen, isFalse);
    expect(identical(opens.first, reopened), isFalse);
    final rows = await reopened.query(
      'focus_presets',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(FocusPreset.fromMap(rows.single).label, 'Reading block');
    expect(
      Sqflite.firstIntValue(await reopened.rawQuery('PRAGMA foreign_keys')),
      1,
    );
  });
}
