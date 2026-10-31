import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('New preset trims input and leaves ID assignment to storage', () {
    final preset = makePreset(label: '  Reading block  ');

    expect(preset.toMap(), {
      'label': 'Reading block',
      'mood_tag': 'Calm',
      'planned_seconds': 1500,
    });
  });

  test('Saved preset round trip retains identity and exact values', () {
    final row = <String, Object?>{
      'id': 12,
      'label': 'Lab preparation',
      'mood_tag': 'Focused',
      'planned_seconds': 2400,
    };

    expect(FocusPreset.fromMap(row).toMap(), row);
    expect(makePreset(id: 1).id, isNot(makePreset(id: 2).id));
  });

  test('Preset validation rejects invalid labels, mood, duration and IDs', () {
    final invalid = [
      () => makePreset(label: '   '),
      () => makePreset(label: List.filled(41, 'a').join()),
      () => makePreset(moodTag: 'calm'),
      () => makePreset(plannedSeconds: 59),
      () => makePreset(plannedSeconds: 7201),
      () => makePreset(id: 0),
      () => makePreset(id: -1),
    ];
    for (final create in invalid) {
      expect(create, throwsArgumentError);
    }
    expect(() => makePreset(plannedSeconds: 60), returnsNormally);
    expect(() => makePreset(plannedSeconds: 7200), returnsNormally);
  });

  test('Label character limit uses Unicode code points', () {
    final label = List.filled(40, '🙂').join();
    expect(() => makePreset(label: label), returnsNormally);
    expect(() => makePreset(label: '$label🙂'), throwsArgumentError);
  });

  test('Saved rows are rejected rather than repaired or coerced', () {
    final row = makePreset(id: 4).toMap();
    final padded = Map<String, Object?>.from(row);
    padded['label'] = ' Reading block ';
    expect(() => FocusPreset.fromMap(padded), throwsFormatException);

    final wrongType = Map<String, Object?>.from(row);
    wrongType['planned_seconds'] = '1500';
    expect(() => FocusPreset.fromMap(wrongType), throwsA(isA<TypeError>()));

    final missingId = Map<String, Object?>.from(row);
    missingId.remove('id');
    expect(() => FocusPreset.fromMap(missingId), throwsA(isA<TypeError>()));
  });
}
