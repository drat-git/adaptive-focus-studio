import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

SessionLog makeLog({
  int? id,
  required int presetId,
  int startedAt = 1000,
  int plannedSeconds = 1500,
  int completedSeconds = 1200,
  String mood = 'Calm',
  String status = 'finished',
  String source = 'timer',
  String note = '',
}) {
  return SessionLog(
    id: id,
    presetId: presetId,
    startedAt: startedAt,
    plannedSecondsSnapshot: plannedSeconds,
    completedSeconds: completedSeconds,
    moodTagSnapshot: mood,
    status: status,
    source: source,
    note: note,
  );
}

FocusPreset makePreset({int? id, String mood = 'Calm', int seconds = 1500}) {
  return FocusPreset(
    id: id,
    label: 'Disposable study preset',
    moodTag: mood,
    plannedSeconds: seconds,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const filename = 'session_database_test.db';
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

  testWidgets('Session reads, corrections and summaries preserve history', (
    tester,
  ) async {
    expect(await helper.getSessionLogs(), isEmpty);
    expect(await helper.getSessionSummary(), {
      'count': 0,
      'averageSeconds': null,
    });
    final parentId = await helper.insertPreset(makePreset());
    final timerId = await helper.insertSessionLog(makeLog(presetId: parentId));
    final manualId = await helper.insertSessionLog(
      makeLog(presetId: parentId, completedSeconds: 0, source: 'manual'),
    );
    final cancelledId = await helper.insertSessionLog(
      makeLog(presetId: parentId, startedAt: 2000, status: 'cancelled'),
    );
    final focusedId = await helper.insertSessionLog(
      makeLog(
        presetId: parentId,
        startedAt: 500,
        completedSeconds: 600,
        mood: 'Focused',
      ),
    );
    expect(timerId, greaterThan(0));
    expect((await helper.getSessionLogs()).map((log) => log.id), [
      cancelledId,
      manualId,
      timerId,
      focusedId,
    ]);
    expect(
      (await helper.getSessionLogs(moodTag: 'Calm')).map((log) => log.id),
      [cancelledId, manualId, timerId],
    );
    expect(await helper.getSessionSummary(moodTag: 'Calm'), {
      'count': 2,
      'averageSeconds': 600.0,
    });
    expect(await helper.getSessionSummary(moodTag: 'Low energy'), {
      'count': 0,
      'averageSeconds': null,
    });

    const literalNote = "  x'); DROP TABLE session_logs;--  ";
    expect(
      await helper.updateSessionLog(
        makeLog(
          id: timerId,
          presetId: parentId,
          completedSeconds: 1800,
          mood: 'Focused',
          note: literalNote,
        ),
      ),
      1,
    );
    final corrected = (await helper.getSessionLog(timerId))!;
    expect(corrected.source, 'edited_timer');
    expect(corrected.note, literalNote.trim());
    expect(corrected.plannedSecondsSnapshot, 1500);
    expect(
      await helper.updateSessionLog(
        makeLog(
          id: manualId,
          presetId: parentId,
          completedSeconds: 0,
          source: 'timer',
        ),
      ),
      1,
    );
    expect((await helper.getSessionLog(manualId))!.source, 'manual');
    expect(await helper.getSessionSummary(moodTag: 'Calm'), {
      'count': 1,
      'averageSeconds': 0.0,
    });
    expect(await helper.getSessionSummary(moodTag: 'Focused'), {
      'count': 2,
      'averageSeconds': 1200.0,
    });
    expect(await helper.getSessionSummary(), {
      'count': 3,
      'averageSeconds': 800.0,
    });

    await helper.updatePreset(
      makePreset(id: parentId, mood: 'Low energy', seconds: 3600),
    );
    final unchanged = (await helper.getSessionLog(manualId))!;
    expect(unchanged.presetId, parentId);
    expect(unchanged.plannedSecondsSnapshot, 1500);
    expect(unchanged.moodTagSnapshot, 'Calm');
    expect(await helper.getSessionSummary(moodTag: 'Calm'), {
      'count': 1,
      'averageSeconds': 0.0,
    });
  });

  testWidgets('Invalid writes and missing IDs do not change saved sessions', (
    tester,
  ) async {
    final parentId = await helper.insertPreset(makePreset());
    final otherParentId = await helper.insertPreset(makePreset());
    final logId = await helper.insertSessionLog(makeLog(presetId: parentId));
    final original = (await helper.getSessionLog(logId))!.toMap();
    await expectLater(
      helper.insertSessionLog(makeLog(id: logId, presetId: parentId)),
      throwsArgumentError,
    );
    await expectLater(
      helper.updateSessionLog(makeLog(presetId: parentId)),
      throwsArgumentError,
    );
    await expectLater(helper.getSessionLog(0), throwsArgumentError);
    await expectLater(helper.deleteSessionLog(0), throwsArgumentError);
    await expectLater(
      helper.getSessionLogs(moodTag: 'Unknown'),
      throwsArgumentError,
    );
    await expectLater(
      helper.getSessionSummary(moodTag: 'Unknown'),
      throwsArgumentError,
    );
    expect(await helper.getSessionLog(99999), isNull);
    expect(await helper.deleteSessionLog(99999), 0);
    expect(
      await helper.updateSessionLog(makeLog(id: 99999, presetId: parentId)),
      0,
    );
    await expectLater(
      helper.insertSessionLog(makeLog(presetId: 99999)),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      helper.insertSessionLog(
        makeLog(presetId: parentId, source: 'edited_timer'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      helper.updateSessionLog(makeLog(id: logId, presetId: otherParentId)),
      throwsArgumentError,
    );
    await expectLater(
      helper.updateSessionLog(
        makeLog(id: logId, presetId: parentId, plannedSeconds: 1800),
      ),
      throwsArgumentError,
    );
    final future = DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    await expectLater(
      helper.insertSessionLog(
        makeLog(presetId: parentId, startedAt: future, source: 'manual'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      helper.updateSessionLog(
        makeLog(id: logId, presetId: parentId, startedAt: future),
      ),
      throwsArgumentError,
    );
    expect((await helper.getSessionLog(logId))!.toMap(), original);

    // This disposable row represents a saved timer after the device clock moved back.
    final clockRollbackId = await helper.insertSessionLog(
      makeLog(presetId: parentId, startedAt: future),
    );
    expect((await helper.getSessionLog(clockRollbackId))!.startedAt, future);
    expect(
      await helper.updateSessionLog(
        makeLog(
          id: clockRollbackId,
          presetId: parentId,
          startedAt: future,
          note: 'Corrected note',
        ),
      ),
      1,
    );
    expect(
      (await helper.getSessionLog(clockRollbackId))!.source,
      'edited_timer',
    );
    expect((await helper.getSessionLog(clockRollbackId))!.startedAt, future);
  });

  testWidgets('Deleting a session releases its protected preset only', (
    tester,
  ) async {
    final parentId = await helper.insertPreset(makePreset());
    final otherId = await helper.insertPreset(makePreset());
    final logId = await helper.insertSessionLog(
      makeLog(presetId: parentId, source: 'manual'),
    );
    expect(await helper.presetHasLogs(parentId), isTrue);
    await expectLater(
      helper.deletePreset(parentId),
      throwsA(isA<DatabaseException>()),
    );
    expect(await helper.deleteSessionLog(logId), 1);
    expect(await helper.getSessionLog(logId), isNull);
    expect(await helper.deleteSessionLog(logId), 0);
    expect(await helper.presetHasLogs(parentId), isFalse);
    expect(await helper.deletePreset(parentId), 1);
    expect((await helper.getPresets()).single.id, otherId);
    expect(await helper.getSessionSummary(), {
      'count': 0,
      'averageSeconds': null,
    });
    final db = await helper.database;
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
