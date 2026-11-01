import 'package:adaptive_focus_studio/helpers/session_scout.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';

SessionLog scoutLog({
  required int id,
  required int startedAt,
  required int seconds,
  String mood = 'Calm',
  String source = 'timer',
  String status = 'finished',
}) {
  return SessionLog(
    id: id,
    presetId: 1,
    startedAt: startedAt,
    plannedSecondsSnapshot: 1500,
    completedSeconds: seconds,
    moodTagSnapshot: mood,
    status: status,
    source: source,
  );
}

void main() {
  test('Scout uses newest matching finished entries and preserves seconds', () {
    final logs = [
      scoutLog(id: 1, startedAt: 1000, seconds: 2400),
      scoutLog(id: 2, startedAt: 3000, seconds: 900),
      scoutLog(id: 3, startedAt: 3000, seconds: 1800, source: 'manual'),
      scoutLog(id: 4, startedAt: 4000, seconds: 1201, source: 'edited_timer'),
      scoutLog(id: 8, startedAt: 8000, seconds: 3600, mood: 'Focused'),
      scoutLog(id: 9, startedAt: 9000, seconds: 7200, status: 'cancelled'),
    ];
    final result = calculateSessionScout(logs: logs, moodTag: 'Calm');
    expect(result.state, SessionScoutState.ready);
    expect(result.suggestedSeconds, 1201);
    expect(result.baselineSeconds, 1500);
    expect(result.usedLogs.map((log) => log.id), [4, 3, 2]);
    expect(result.selectedDurationsSeconds, [1201, 1800, 900]);
    expect(result.explanation, contains('Manual entry'));
    expect(result.explanation, contains('Corrected timer'));
    expect(result.explanation, contains('Measured timer'));
    expect(logs.map((log) => log.id), [1, 2, 3, 4, 8, 9]);
  });

  test(
    'Empty or insufficient positive history returns no numeric suggestion',
    () {
      final empty = calculateSessionScout(logs: [], moodTag: 'Calm');
      expect(empty.state, SessionScoutState.insufficientHistory);
      expect(empty.suggestedSeconds, isNull);
      final result = calculateSessionScout(
        logs: [
          scoutLog(id: 1, startedAt: 1000, seconds: 600),
          scoutLog(id: 2, startedAt: 2000, seconds: 1200),
          scoutLog(id: 3, startedAt: 3000, seconds: 0),
        ],
        moodTag: 'Calm',
      );
      expect(result.state, SessionScoutState.insufficientHistory);
      expect(result.suggestedSeconds, isNull);
      expect(result.baselineSeconds, 1500);
      expect(result.usedLogs.map((log) => log.id), [2, 1]);
      expect(result.warning, isNull);
      expect(result.explanation, startsWith('Not enough history.'));
    },
  );

  test('Invalid selected mood gives actionable feedback without a number', () {
    final result = calculateSessionScout(logs: [], moodTag: 'Unknown');
    expect(result.state, SessionScoutState.invalidInput);
    expect(result.suggestedSeconds, isNull);
    expect(result.usedLogs, isEmpty);
    expect(result.explanation, contains('Choose Calm, Focused, or Low energy'));
  });
}
