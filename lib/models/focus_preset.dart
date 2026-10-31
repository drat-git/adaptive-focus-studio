class FocusPreset {
  static const moodTags = ['Calm', 'Focused', 'Low energy'];

  final int? id;
  final String label;
  final String moodTag;
  final int plannedSeconds;

  FocusPreset({
    this.id,
    required String label,
    required this.moodTag,
    required this.plannedSeconds,
  }) : label = label.trim() {
    if (id != null && id! <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final labelError = validateLabel(this.label);
    if (labelError != null) {
      throw ArgumentError.value(label, 'label', labelError);
    }
    final moodError = validateMoodTag(moodTag);
    if (moodError != null) {
      throw ArgumentError.value(moodTag, 'moodTag', moodError);
    }
    final durationError = validatePlannedSeconds(plannedSeconds);
    if (durationError != null) {
      throw ArgumentError.value(
        plannedSeconds,
        'plannedSeconds',
        durationError,
      );
    }
  }

  static String? validateLabel(String value) {
    final label = value.trim();
    // Count Unicode code points, matching SQLite's length check.
    if (label.isEmpty || label.runes.length > 40) {
      return 'Use 1 to 40 characters for the label.';
    }
    return null;
  }

  static String? validateMoodTag(String value) {
    if (!moodTags.contains(value)) {
      return 'Choose Calm, Focused, or Low energy.';
    }
    return null;
  }

  static String? validatePlannedSeconds(int value) {
    if (value < 60 || value > 7200) {
      return 'Choose a duration from 60 to 7200 seconds.';
    }
    return null;
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'mood_tag': moodTag,
      'planned_seconds': plannedSeconds,
    };
  }

  factory FocusPreset.fromMap(Map<String, Object?> map) {
    final label = map['label'] as String;
    if (label != label.trim()) {
      throw const FormatException('Saved preset label is not trimmed.');
    }
    return FocusPreset(
      id: map['id'] as int,
      label: label,
      moodTag: map['mood_tag'] as String,
      plannedSeconds: map['planned_seconds'] as int,
    );
  }
}
