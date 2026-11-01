import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'package:adaptive_focus_studio/screens/session_log_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final presets = [
  FocusPreset(id: 4, label: 'Reading', moodTag: 'Calm', plannedSeconds: 1500),
  FocusPreset(
    id: 9,
    label: 'Reading',
    moodTag: 'Focused',
    plannedSeconds: 1800,
  ),
];

Future<void> openEntry(
  WidgetTester tester,
  SessionLogEditor editor,
  void Function(bool?) onClosed,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onClosed(
                await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => editor,
                ),
              );
            },
            child: const Text('Open entry'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open entry'));
  await tester.pumpAndSettle();
}

Future<void> enterCompletedTime(
  WidgetTester tester, {
  String hours = '0',
  String minutes = '0',
  String seconds = '0',
}) async {
  for (final entry in {
    'hours': hours,
    'minutes': minutes,
    'seconds': seconds,
  }.entries) {
    final field = find.byKey(Key('completed-${entry.key}'));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
  }
}

void main() {
  testWidgets(
    'Validates time components and saves one manual snapshot while pending',
    (tester) async {
      final pending = Completer<int>();
      final writes = <SessionLog>[];
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          saveLog: (log) {
            writes.add(log);
            return pending.future;
          },
        ),
        (value) => closed = value,
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Enter whole seconds.'), findsOneWidget);
      await enterCompletedTime(tester, hours: '2', seconds: '1');
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Use no more than 2 hours total.'), findsOneWidget);
      expect(writes, isEmpty);
      await enterCompletedTime(
        tester,
        hours: '3',
        minutes: '60',
        seconds: '1.5',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Use 0 to 2 hours.'), findsOneWidget);
      expect(find.text('Use 0 to 59 minutes.'), findsOneWidget);
      expect(find.text('Enter whole seconds.'), findsOneWidget);
      expect(writes, isEmpty);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reading (#9)').last);
      await tester.pumpAndSettle();
      expect(find.text('Planned snapshot: 30 min'), findsOneWidget);
      await enterCompletedTime(tester);
      await tester.enterText(find.byType(TextFormField).last, '  My notes  ');
      await tester.tap(find.text('Save entry'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, isNull);
      expect(writes, hasLength(1));
      expect(writes.single.presetId, 9);
      expect(writes.single.plannedSecondsSnapshot, 1800);
      expect(writes.single.completedSeconds, 0);
      expect(writes.single.moodTagSnapshot, 'Focused');
      expect(writes.single.source, 'manual');
      expect(writes.single.note, 'My notes');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      pending.complete(17);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.text('Manual session entry'), findsNothing);
    },
  );

  testWidgets('A failed save retains the draft and retry keeps its values', (
    tester,
  ) async {
    final writes = <SessionLog>[];
    bool? closed;
    await openEntry(
      tester,
      SessionLogEditor(
        presets: presets,
        saveLog: (log) async {
          writes.add(log);
          if (writes.length == 1) throw StateError('Write unavailable');
          return 18;
        },
      ),
      (value) => closed = value,
    );
    await enterCompletedTime(tester, hours: '2');
    await tester.enterText(find.byType(TextFormField).last, 'x' * 241);
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use no more than 240 characters for the note.'),
      findsOneWidget,
    );
    expect(writes, isEmpty);
    await tester.enterText(find.byType(TextFormField).last, 'Kept note');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not save this entry. Your changes are still here. Try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('completed-hours')))
          .controller!
          .text,
      '2',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      'Kept note',
    );
    expect(closed, isNull);
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(writes, hasLength(2));
    expect(writes[0].toMap(), writes[1].toMap());
  });

  testWidgets(
    'Future local time is rejected and changed drafts confirm discard',
    (tester) async {
      var now = DateTime(2026, 10, 31, 15, 30);
      var writes = 0;
      bool? closed;
      await openEntry(
        tester,
        SessionLogEditor(
          presets: presets,
          now: () => now,
          saveLog: (_) async {
            writes++;
            return 1;
          },
        ),
        (value) => closed = value,
      );
      expect(find.byKey(const Key('session-date')), findsOneWidget);
      expect(find.byKey(const Key('session-time')), findsOneWidget);
      await enterCompletedTime(tester, minutes: '1');
      now = now.subtract(const Duration(hours: 1));
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Session date cannot be in the future.'),
        findsOneWidget,
      );
      expect(writes, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(closed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(writes, 0);
    },
  );

  testWidgets('Hours minutes and seconds save as one exact duration', (
    tester,
  ) async {
    SessionLog? saved;
    await openEntry(
      tester,
      SessionLogEditor(
        presets: presets,
        saveLog: (log) async {
          saved = log;
          return 19;
        },
      ),
      (_) {},
    );
    await enterCompletedTime(tester, hours: '1', minutes: '2', seconds: '3');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(saved!.completedSeconds, 3723);
    expect(saved!.source, 'manual');
  });

  testWidgets('No presets offers a destination without allowing a save', (
    tester,
  ) async {
    var openedPresets = false;
    bool? closed;
    await openEntry(
      tester,
      SessionLogEditor(
        presets: const [],
        onOpenPresets: () => openedPresets = true,
      ),
      (value) => closed = value,
    );
    expect(
      find.text(
        'Create a preset in Presets, then return to add a session entry.',
      ),
      findsOneWidget,
    );
    expect(find.text('Save entry'), findsNothing);
    await tester.tap(find.text('Open Presets'));
    await tester.pumpAndSettle();
    expect(openedPresets, isTrue);
    expect(closed, isFalse);
  });
}
