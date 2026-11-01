import 'dart:async';

import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/screens/presets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

final preset = FocusPreset(
  id: 7,
  label: 'Reading',
  moodTag: 'Calm',
  plannedSeconds: 1500,
);

Future<void> showPresets(
  WidgetTester tester, {
  required Future<int> Function(int) deletePreset,
  required Future<bool> Function(int) presetHasLogs,
  Future<List<FocusPreset>> Function()? loadPresets,
  VoidCallback? onOpenHistory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PresetsScreen(
          loadSummary: (_) async => {'count': 0, 'averageSeconds': null},
          loadPresets: loadPresets ?? () async => [preset],
          deletePreset: deletePreset,
          presetHasLogs: presetHasLogs,
          onAddPreset: () async => false,
          onEditPreset: (_) async => false,
          onOpenSession: (_) async => false,
          onOpenHistory: onOpenHistory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

class DeleteFailure extends DatabaseException {
  DeleteFailure() : super('Delete failed');

  @override
  int? getResultCode() => 19;

  @override
  Object? get result => null;
}

void main() {
  testWidgets('Cancel preserves a preset without a database operation', (
    tester,
  ) async {
    var checks = 0;
    var writes = 0;
    await showPresets(
      tester,
      presetHasLogs: (_) async {
        checks++;
        return false;
      },
      deletePreset: (_) async {
        writes++;
        return 1;
      },
    );
    expect(find.text('Delete "Reading"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsOneWidget);
    expect(checks, 0);
    expect(writes, 0);
  });

  testWidgets(
    'One pending delete blocks dismissal and refresh retries only read',
    (tester) async {
      final pending = Completer<int>();
      final deletedIds = <int>[];
      var reads = 0;
      await showPresets(
        tester,
        loadPresets: () async {
          reads++;
          if (reads == 1) return [preset];
          if (reads == 2) throw StateError('Refresh failed');
          return [];
        },
        presetHasLogs: (_) async => false,
        deletePreset: (id) {
          deletedIds.add(id);
          return pending.future;
        },
      );
      await tester.tap(find.text('Delete preset'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Delete "Reading"?'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Deleting…'),
            )
            .onPressed,
        isNull,
      );
      expect(deletedIds, [7]);
      pending.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('Preset deleted.'), findsOneWidget);
      expect(find.text('Could not load presets.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add your first preset to set up a study block.'),
        findsOneWidget,
      );
      expect(deletedIds, [7]);
    },
  );

  testWidgets('Protected history is retained and offers its destination', (
    tester,
  ) async {
    var writes = 0;
    var openedHistory = false;
    await showPresets(
      tester,
      presetHasLogs: (_) async => true,
      deletePreset: (_) async {
        writes++;
        return 1;
      },
      onOpenHistory: () => openedHistory = true,
    );
    await tester.tap(find.text('Delete preset'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this preset'), findsOneWidget);
    expect(find.text('Keep preset'), findsOneWidget);
    expect(writes, 0);
    await tester.tap(find.text('Open History'));
    await tester.pumpAndSettle();
    expect(openedHistory, isTrue);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets(
    'Failed delete stays retryable and missing is distinct from success',
    (tester) async {
      var writes = 0;
      await showPresets(
        tester,
        presetHasLogs: (_) async => false,
        deletePreset: (_) async {
          writes++;
          if (writes == 1) throw StateError('Write unavailable');
          return 0;
        },
      );
      await tester.tap(find.text('Delete preset'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not delete this preset. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Delete preset'));
      await tester.pumpAndSettle();
      expect(
        find.text('This preset no longer exists. Reloading the list.'),
        findsOneWidget,
      );
      expect(find.text('Preset deleted.'), findsNothing);
      expect(writes, 2);
    },
  );

  testWidgets('A relationship added during delete gets protected feedback', (
    tester,
  ) async {
    var checks = 0;
    await showPresets(
      tester,
      presetHasLogs: (_) async {
        checks++;
        return checks > 1;
      },
      deletePreset: (_) async => throw DeleteFailure(),
    );
    await tester.tap(find.text('Delete preset'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Keep this preset'), findsOneWidget);
    expect(find.text('Open History'), findsOneWidget);
    expect(find.text('Could not delete this preset. Try again.'), findsNothing);
  });
}
