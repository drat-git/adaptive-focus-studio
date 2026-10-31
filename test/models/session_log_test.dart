import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';

SessionLog makeLog({
  int? id,
  int presetId = 2,
  int startedAt = 1793448000000,
  int plannedSecondsSnapshot = 1500,
  int completedSeconds = 1320,
  String moodTagSnapshot = 'Calm',
  String status = 'finished',
  String source = 'manual',
  String note = '',
}) {
  return SessionLog(
    id: id,
    presetId: presetId,
    startedAt: startedAt,
    plannedSecondsSnapshot: plannedSecondsSnapshot,
    completedSeconds: completedSeconds,
    moodTagSnapshot: moodTagSnapshot,
    status: status,
    source: source,
    note: note,
  );
}

void main() {
  test('New log maps integer seconds and UTC milliseconds without an ID', () {
    final log = makeLog(note: '  Review chapter 3  ');
    expect(log.toMap(), {
      'preset_id': 2,
      'started_at_ms': 1793448000000,
      'planned_seconds_snapshot': 1500,
      'completed_seconds': 1320,
      'mood_tag_snapshot': 'Calm',
      'status': 'finished',
      'source': 'manual',
      'note': 'Review chapter 3',
    });
  });

  test(
    'Saved log round trip preserves its historical snapshots and source',
    () {
      final row = makeLog(
        id: 7,
        plannedSecondsSnapshot: 600,
        completedSeconds: 900,
        moodTagSnapshot: 'Low energy',
        source: 'edited_timer',
      ).toMap();
      expect(SessionLog.fromMap(row).toMap(), row);
    },
  );

  test('Zero, upper bound and cancelled history remain valid records', () {
    expect(() => makeLog(completedSeconds: 0), returnsNormally);
    expect(() => makeLog(completedSeconds: 7200), returnsNormally);
    expect(
      () => makeLog(completedSeconds: 0, status: 'cancelled', source: 'timer'),
      returnsNormally,
    );
    expect(() => makeLog(note: List.filled(240, 'a').join()), returnsNormally);
  });

  test('Log validation rejects invalid identities, values and choices', () {
    final invalid = [
      () => makeLog(id: 0),
      () => makeLog(presetId: 0),
      () => makeLog(startedAt: -1),
      () => makeLog(plannedSecondsSnapshot: 59),
      () => makeLog(completedSeconds: -1),
      () => makeLog(completedSeconds: 7201),
      () => makeLog(moodTagSnapshot: 'Unknown'),
      () => makeLog(status: 'running'),
      () => makeLog(source: 'inferred'),
      () => makeLog(note: List.filled(241, 'a').join()),
    ];
    for (final create in invalid) {
      expect(create, throwsArgumentError);
    }
  });

  test(
    'Manual input rejects future dates while saved history stays readable',
    () {
      const now = 1793448000000;
      expect(SessionLog.validateManualStartedAt(now - 1, now: now), isNull);
      expect(SessionLog.validateManualStartedAt(now, now: now), isNull);
      expect(SessionLog.validateManualStartedAt(now + 1, now: now), isNotNull);
      expect(SessionLog.validateManualStartedAt(-1, now: now), isNotNull);

      final savedRow = makeLog(id: 9, startedAt: now + 60000).toMap();
      expect(SessionLog.fromMap(savedRow).toMap(), savedRow);
    },
  );

  test('Saved log rejects missing, wrongly typed and untrimmed data', () {
    final row = makeLog(id: 6).toMap();
    final missingNote = Map<String, Object?>.from(row);
    missingNote.remove('note');
    expect(() => SessionLog.fromMap(missingNote), throwsA(isA<TypeError>()));

    final wrongType = Map<String, Object?>.from(row);
    wrongType['completed_seconds'] = 1320.5;
    expect(() => SessionLog.fromMap(wrongType), throwsA(isA<TypeError>()));

    final padded = Map<String, Object?>.from(row);
    padded['note'] = ' Unreviewed text ';
    expect(() => SessionLog.fromMap(padded), throwsFormatException);
  });
}
