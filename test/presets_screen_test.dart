import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/screens/presets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shows loading then a truthful empty state', (tester) async {
    final pending = Completer<List<FocusPreset>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresetsScreen(
            loadSummary: (_) async => {'count': 0, 'averageSeconds': null},
            loadPresets: () => pending.future,
            onAddPreset: () async => false,
            onEditPreset: (preset) async => false,
            onOpenSession: (preset) async => false,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Add your first preset to set up a study block.'),
      findsOneWidget,
    );
  });

  testWidgets('Retry loads records after a read failure', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresetsScreen(
            loadSummary: (_) async => {'count': 0, 'averageSeconds': null},
            loadPresets: () async {
              calls++;
              if (calls == 1) throw StateError('Read failed');
              return [
                FocusPreset(
                  id: 3,
                  label: 'Lab notes',
                  moodTag: 'Focused',
                  plannedSeconds: 1200,
                ),
              ];
            },
            onAddPreset: () async => false,
            onEditPreset: (preset) async => false,
            onOpenSession: (preset) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load presets.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Lab notes'), findsOneWidget);
  });

  testWidgets('Filters current preset mood and opens the selected ID', (
    tester,
  ) async {
    FocusPreset? opened;
    final rows = [
      FocusPreset(
        id: 2,
        label: 'Reading',
        moodTag: 'Calm',
        plannedSeconds: 1500,
      ),
      FocusPreset(
        id: 4,
        label: 'Lab notes',
        moodTag: 'Focused',
        plannedSeconds: 1200,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresetsScreen(
            loadSummary: (_) async => {'count': 0, 'averageSeconds': null},
            loadPresets: () async => rows,
            onAddPreset: () async => false,
            onEditPreset: (preset) async => false,
            onOpenSession: (preset) async {
              opened = preset;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focused').last);
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsNothing);
    expect(find.text('Lab notes'), findsOneWidget);
    await tester.ensureVisible(find.text('Open session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open session'));
    expect(opened?.id, 4);
  });
}
