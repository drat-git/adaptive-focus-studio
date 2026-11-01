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

void main() {
  testWidgets('Validates seconds and saves one manual snapshot while pending', (
    tester,
  ) async {
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
    expect(find.text('Enter a whole number of seconds.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7201');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter completed time from 0 to 7200 seconds.'),
      findsOneWidget,
    );
    expect(writes, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading (#9)').last);
    await tester.pumpAndSettle();
    expect(find.text('Planned snapshot: 30 min'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '0');
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
  });

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
    await tester.enterText(find.byType(TextFormField).first, '7200');
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
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '7200',
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
      await tester.enterText(find.byType(TextFormField).first, '60');
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
