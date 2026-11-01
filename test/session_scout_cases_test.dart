import 'dart:convert';
import 'dart:io';

import 'package:adaptive_focus_studio/helpers/session_scout.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:flutter_test/flutter_test.dart';

SessionLog sampleLog(
  int id,
  int timestamp,
  int seconds, {
  String mood = 'Calm',
  String source = 'timer',
  String status = 'finished',
}) {
  return SessionLog(
    id: id,
    presetId: 1,
    startedAt: timestamp,
    plannedSecondsSnapshot: 1500,
    completedSeconds: seconds,
    moodTagSnapshot: mood,
    status: status,
    source: source,
  );
}

// Deliberately malformed test input, never inserted into the app database.
class InvalidDurationLog extends SessionLog {
  int _storedSeconds = 0;

  InvalidDurationLog()
    : super(
        id: 10,
        presetId: 1,
        startedAt: 10000,
        plannedSecondsSnapshot: 1500,
        completedSeconds: 0,
        moodTagSnapshot: 'Calm',
        status: 'finished',
        source: 'timer',
      ) {
    _storedSeconds = -1;
  }

  @override
  int get completedSeconds => _storedSeconds;
}

class ScoutCase {
  ScoutCase({
    required this.id,
    required this.type,
    required this.logs,
    required this.state,
    required this.usedIds,
    this.mood = 'Calm',
    this.seconds,
    this.referenceSeconds,
    this.warning = false,
  });

  final String id;
  final String type;
  final List<SessionLog> logs;
  final SessionScoutState state;
  final List<int> usedIds;
  final String mood;
  final int? seconds;
  final int? referenceSeconds;
  final bool warning;
}

void main() {
  final normal = [
    sampleLog(1, 1000, 2400),
    sampleLog(2, 3000, 7200, source: 'edited_timer'),
    sampleLog(3, 3000, 1500),
    sampleLog(4, 4000, 1200, source: 'manual'),
    sampleLog(8, 8000, 3600, mood: 'Focused'),
    sampleLog(9, 9000, 600, status: 'cancelled'),
  ];
  final edited = normal.map((log) {
    return log.id == 3 ? sampleLog(3, 3000, 600, source: 'edited_timer') : log;
  }).toList();
  final cases = [
    ScoutCase(
      id: 'SC01',
      type: 'normal, historical mood, newest tie and outlier',
      logs: normal,
      state: SessionScoutState.ready,
      usedIds: [4, 3, 2],
      seconds: 1500,
      referenceSeconds: 1320,
    ),
    ScoutCase(
      id: 'SC02',
      type: 'empty history',
      logs: [],
      state: SessionScoutState.insufficientHistory,
      usedIds: [],
    ),
    ScoutCase(
      id: 'SC03',
      type: 'invalid selected mood',
      logs: normal,
      mood: 'Unknown',
      state: SessionScoutState.invalidInput,
      usedIds: [],
    ),
    ScoutCase(
      id: 'SC04',
      type: 'invalid duration excluded with correction feedback',
      logs: [normal[1], normal[2], InvalidDurationLog()],
      state: SessionScoutState.insufficientHistory,
      usedIds: [3, 2],
      warning: true,
    ),
    ScoutCase(
      id: 'SC05',
      type: 'lower clamp',
      logs: [
        sampleLog(1, 1000, 120),
        sampleLog(2, 2000, 300),
        sampleLog(3, 3000, 420),
      ],
      state: SessionScoutState.ready,
      usedIds: [3, 2, 1],
      seconds: 600,
      referenceSeconds: 480,
    ),
    ScoutCase(
      id: 'SC06',
      type: 'upper clamp with long outlier',
      logs: [
        sampleLog(1, 1000, 3600),
        sampleLog(2, 2000, 4200),
        sampleLog(3, 3000, 7200),
      ],
      state: SessionScoutState.ready,
      usedIds: [3, 2, 1],
      seconds: 3600,
      referenceSeconds: 3300,
    ),
    ScoutCase(
      id: 'SC07',
      type: 'counterexample: a hypothetical next session changes length',
      logs: [
        sampleLog(1, 1000, 600),
        sampleLog(2, 2000, 720),
        sampleLog(3, 3000, 900),
      ],
      state: SessionScoutState.ready,
      usedIds: [3, 2, 1],
      seconds: 720,
      referenceSeconds: 1500,
    ),
    ScoutCase(
      id: 'SC08',
      type: 'history correction changes median',
      logs: edited,
      state: SessionScoutState.ready,
      usedIds: [4, 3, 2],
      seconds: 1200,
      referenceSeconds: 1320,
    ),
    ScoutCase(
      id: 'SC09',
      type: 'history deletion includes the next older entry',
      logs: edited.where((log) => log.id != 4).toList(),
      state: SessionScoutState.ready,
      usedIds: [3, 2, 1],
      seconds: 2400,
      referenceSeconds: 1500,
    ),
  ];
  final results = <Map<String, Object?>>[];
  final helperErrors = <double>[];
  final baselineErrors = <double>[];

  for (final example in cases) {
    test('Synthetic ${example.id}: ${example.type}', () {
      final result = calculateSessionScout(
        logs: example.logs,
        moodTag: example.mood,
      );
      final usedIds = result.usedLogs.map((log) => log.id).toList();
      final pass =
          result.state == example.state &&
          result.suggestedSeconds == example.seconds &&
          usedIds.join(',') == example.usedIds.join(',') &&
          (result.warning != null) == example.warning;
      Map<String, Object?>? comparison;
      if (example.referenceSeconds != null && result.suggestedSeconds != null) {
        final helperError =
            (result.suggestedSeconds! - example.referenceSeconds!).abs() / 60;
        final baselineError =
            (result.baselineSeconds - example.referenceSeconds!).abs() / 60;
        helperErrors.add(helperError);
        baselineErrors.add(baselineError);
        comparison = {
          'hypotheticalReferenceSeconds': example.referenceSeconds,
          'helperSeconds': result.suggestedSeconds,
          'baselineSeconds': result.baselineSeconds,
          'helperAbsoluteErrorMinutes': helperError,
          'baselineAbsoluteErrorMinutes': baselineError,
        };
      }
      results.add({
        'caseId': example.id,
        'type': example.type,
        'syntheticInputs': example.logs.map((log) => log.toMap()).toList(),
        'selectedMood': example.mood,
        'expected': {
          'state': example.state.name,
          'suggestedSeconds': example.seconds,
          'usedIds': example.usedIds,
          'warning': example.warning,
        },
        'actual': {
          'state': result.state.name,
          'suggestedSeconds': result.suggestedSeconds,
          'usedIds': usedIds,
          'warning': result.warning,
          'explanation': result.explanation,
        },
        'comparison': comparison,
        'pass': pass,
      });
      expect(result.state, example.state);
      expect(result.suggestedSeconds, example.seconds);
      expect(usedIds, example.usedIds);
      expect(result.warning != null, example.warning);
    });
  }

  tearDownAll(() {
    final output = Platform.environment['SCOUT_EVALUATION_OUTPUT'];
    if (output == null) return;
    var helperTotal = 0.0;
    var baselineTotal = 0.0;
    for (final error in helperErrors) {
      helperTotal += error;
    }
    for (final error in baselineErrors) {
      baselineTotal += error;
    }
    final report = {
      'fixtureLabel': 'Synthetic demonstration. References are hypothetical later durations, not observed human outcomes.',
      'metric': 'Absolute error in minutes against the same hypothetical reference for helper and fixed 25-minute baseline.',
      'caseCount': results.length,
      'scoredSampleSize': helperErrors.length,
      'helperMeanAbsoluteErrorMinutes': helperErrors.isEmpty
          ? null
          : helperTotal / helperErrors.length,
      'baselineMeanAbsoluteErrorMinutes': baselineErrors.isEmpty
          ? null
          : baselineTotal / baselineErrors.length,
      'limitation': 'A small constructed sample demonstrates the rule; it does not establish general accuracy. Changed study needs can make the baseline better, as SC07 shows.',
      'decision': 'Retain the transparent median and clamps as a starting point. Keep Apply optional and allow duration changes.',
      'cases': results,
    };
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });
}
