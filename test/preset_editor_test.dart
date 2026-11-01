import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/screens/preset_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openEditor(
  WidgetTester tester,
  PresetEditorScreen editor,
  void Function(bool?) onClosed,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onClosed(
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(builder: (context) => editor),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Validates a new draft and guards one pending save', (
    tester,
  ) async {
    final pending = Completer<int>();
    final writes = <FocusPreset>[];
    bool? closed;
    await openEditor(
      tester,
      PresetEditorScreen(
        loadDefaultDuration: () async => 1800,
        savePreset: (preset) {
          writes.add(preset);
          return pending.future;
        },
      ),
      (value) => closed = value,
    );
    await tester.ensureVisible(find.text('Save preset'));
    await tester.tap(find.text('Save preset'));
    await tester.pump();
    expect(find.text('Use 1 to 40 characters for the label.'), findsOneWidget);
    expect(writes, isEmpty);

    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '  Reading  ');
    await tester.ensureVisible(find.text('Save preset'));
    await tester.tap(find.text('Save preset'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(closed, isNull);
    expect(writes, hasLength(1));
    expect(writes.single.id, isNull);
    expect(writes.single.label, 'Reading');
    expect(writes.single.plannedSeconds, 1800);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    pending.complete(42);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Preset details'), findsNothing);
  });

  testWidgets('Failed edit keeps its draft and retries the same saved ID', (
    tester,
  ) async {
    final writes = <FocusPreset>[];
    bool? closed;
    await openEditor(
      tester,
      PresetEditorScreen(
        preset: FocusPreset(
          id: 7,
          label: 'Reading',
          moodTag: 'Low energy',
          plannedSeconds: 1250,
        ),
        savePreset: (preset) async {
          writes.add(preset);
          if (writes.length == 1) throw StateError('Write unavailable');
          return 1;
        },
      ),
      (value) => closed = value,
    );
    await tester.enterText(find.byType(TextFormField), 'Evening notes');
    await tester.ensureVisible(find.text('Save preset'));
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    expect(closed, isNull);
    expect(
      find.text(
        'Could not save this preset. Your changes are still here. Try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Evening notes',
    );
    await tester.ensureVisible(find.text('Save preset'));
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(writes.map((preset) => preset.id), [7, 7]);
    expect(writes.last.plannedSeconds, 1250);
    expect(writes.last.moodTag, 'Low energy');
  });

  testWidgets('Missing update offers a return that refreshes the catalog', (
    tester,
  ) async {
    bool? closed;
    await openEditor(
      tester,
      PresetEditorScreen(
        preset: FocusPreset(
          id: 7,
          label: 'Reading',
          moodTag: 'Calm',
          plannedSeconds: 1500,
        ),
        savePreset: (preset) async => 0,
      ),
      (value) => closed = value,
    );
    await tester.ensureVisible(find.text('Save preset'));
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    expect(closed, isNull);
    expect(
      find.text('This preset no longer exists. Return to Presets to refresh.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Return to presets'));
    await tester.tap(find.text('Return to presets'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
