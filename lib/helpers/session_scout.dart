import '../models/focus_preset.dart';
import '../models/session_log.dart';

enum SessionScoutState { ready, insufficientHistory, invalidInput }

class SessionScoutResult {
  SessionScoutResult._({
    required this.state,
    required this.explanation,
    this.suggestedSeconds,
    List<SessionLog> usedLogs = const [],
    this.warning,
  }) : usedLogs = List<SessionLog>.unmodifiable(usedLogs),
       selectedDurationsSeconds = List<int>.unmodifiable(
         usedLogs.map((log) => log.completedSeconds),
       );

  final SessionScoutState state;
  final int? suggestedSeconds;
  final int baselineSeconds = 1500;
  final List<SessionLog> usedLogs;
  final List<int> selectedDurationsSeconds;
  final String? warning;
  final String explanation;
}

SessionScoutResult calculateSessionScout({
  required List<SessionLog> logs,
  required String moodTag,
}) {
  if (FocusPreset.validateMoodTag(moodTag) != null) {
    return SessionScoutResult._(
      state: SessionScoutState.invalidInput,
      explanation: 'Choose Calm, Focused, or Low energy to get a suggestion.',
    );
  }

  final eligible = <SessionLog>[];
  var invalidCount = 0;
  for (final log in logs) {
    if (log.moodTagSnapshot != moodTag || log.status != 'finished') continue;
    if (log.completedSeconds < 0 ||
        log.completedSeconds > 7200 ||
        log.startedAt < 0 ||
        log.id == null ||
        log.id! <= 0 ||
        !SessionLog.sources.contains(log.source)) {
      invalidCount++;
      continue;
    }
    if (log.completedSeconds == 0) continue;
    eligible.add(log);
  }
  eligible.sort((first, second) {
    final timeOrder = second.startedAt.compareTo(first.startedAt);
    if (timeOrder != 0) return timeOrder;
    return second.id!.compareTo(first.id!);
  });
  final used = eligible.take(3).toList();
  final warning = invalidCount == 0
      ? null
      : 'Some matching entries have invalid data and were excluded. Correct them in History.';
  if (used.length < 3) {
    return SessionScoutResult._(
      state: SessionScoutState.insufficientHistory,
      usedLogs: used,
      warning: warning,
      explanation:
          'Not enough history. There are ${used.length} eligible finished $moodTag entries. Add at least three with positive completed time to get a suggestion.',
    );
  }

  final durations = used.map((log) => log.completedSeconds).toList()..sort();
  // The same median in seconds keeps partial minutes exact.
  var suggestion = durations[1];
  if (suggestion < 600) suggestion = 600;
  if (suggestion > 3600) suggestion = 3600;
  const sourceLabels = {
    'timer': 'Measured timer',
    'manual': 'Manual entry',
    'edited_timer': 'Corrected timer',
  };
  final inputs = used
      .map((log) {
        return '${log.completedSeconds} sec (${sourceLabels[log.source]})';
      })
      .join(', ');
  return SessionScoutResult._(
    state: SessionScoutState.ready,
    suggestedSeconds: suggestion,
    usedLogs: used,
    warning: warning,
    explanation:
        'Newest three finished $moodTag entries: $inputs. The suggestion uses their median, limited to 10–60 minutes. This rule-based estimate is a starting point, not an attention measure.',
  );
}
