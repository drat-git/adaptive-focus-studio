import 'focus_preset.dart';

class SessionLog {
  static const statuses = ['finished', 'cancelled'];
  static const sources = ['timer', 'manual', 'edited_timer'];

  final int? id;
  final int presetId;
  final int startedAt;
  final int plannedSecondsSnapshot;
  final int completedSeconds;
  final String moodTagSnapshot;
  final String status;
  final String source;
  final String note;

  SessionLog({
    this.id,
    required this.presetId,
    required this.startedAt,
    required this.plannedSecondsSnapshot,
    required this.completedSeconds,
    required this.moodTagSnapshot,
    required this.status,
    required this.source,
    String note = '',
  }) : note = note.trim() {
    if (id != null && id! <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    if (presetId <= 0) {
      throw ArgumentError.value(presetId, 'presetId', 'Choose a saved preset.');
    }
    if (startedAt < 0) {
      throw ArgumentError.value(
        startedAt,
        'startedAt',
        'Use a valid timestamp.',
      );
    }
    final durationError = FocusPreset.validatePlannedSeconds(
      plannedSecondsSnapshot,
    );
    if (durationError != null) {
      throw ArgumentError.value(
        plannedSecondsSnapshot,
        'plannedSecondsSnapshot',
        durationError,
      );
    }
    final completedError = validateCompletedSeconds(completedSeconds);
    if (completedError != null) {
      throw ArgumentError.value(
        completedSeconds,
        'completedSeconds',
        completedError,
      );
    }
    final moodError = FocusPreset.validateMoodTag(moodTagSnapshot);
    if (moodError != null) {
      throw ArgumentError.value(moodTagSnapshot, 'moodTagSnapshot', moodError);
    }
    if (!statuses.contains(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'Choose finished or cancelled.',
      );
    }
    if (!sources.contains(source)) {
      throw ArgumentError.value(
        source,
        'source',
        'Use a valid session source.',
      );
    }
    final noteError = validateNote(this.note);
    if (noteError != null) {
      throw ArgumentError.value(note, 'note', noteError);
    }
  }

  static String? validateCompletedSeconds(int value) {
    if (value < 0 || value > 7200) {
      return 'Enter completed time from 0 to 7200 seconds.';
    }
    return null;
  }

  static String? validateNote(String value) {
    if (value.trim().runes.length > 240) {
      return 'Use no more than 240 characters for the note.';
    }
    return null;
  }

  // Check the clock at manual input time, not when reading saved history.
  static String? validateManualStartedAt(int value, {required int now}) {
    if (value < 0) {
      return 'Choose a valid session date.';
    }
    if (value > now) {
      return 'Session date cannot be in the future.';
    }
    return null;
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'preset_id': presetId,
      'started_at_ms': startedAt,
      'planned_seconds_snapshot': plannedSecondsSnapshot,
      'completed_seconds': completedSeconds,
      'mood_tag_snapshot': moodTagSnapshot,
      'status': status,
      'source': source,
      'note': note,
    };
  }

  factory SessionLog.fromMap(Map<String, Object?> map) {
    final note = map['note'] as String;
    if (note != note.trim()) {
      throw const FormatException('Saved session note is not trimmed.');
    }
    return SessionLog(
      id: map['id'] as int,
      presetId: map['preset_id'] as int,
      startedAt: map['started_at_ms'] as int,
      plannedSecondsSnapshot: map['planned_seconds_snapshot'] as int,
      completedSeconds: map['completed_seconds'] as int,
      moodTagSnapshot: map['mood_tag_snapshot'] as String,
      status: map['status'] as String,
      source: map['source'] as String,
      note: note,
    );
  }
}
