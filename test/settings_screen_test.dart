import 'dart:async';

import 'package:adaptive_focus_studio/data/settings_store.dart';
import 'package:adaptive_focus_studio/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSettingsStore implements SettingsStore {
  @override
  final keyPrefix = '';
  int seconds = 1500;
  bool reduceMotion = false;
  bool failRead = false;
  bool failDurationWrite = false;
  bool failMotionWrite = false;
  Completer<int>? pendingRead;
  Completer<void>? pendingWrite;
  final savedDurations = <int>[];

  @override
  Future<int> getDefaultDurationSeconds() async {
    if (failRead) throw StateError('Read unavailable');
    return pendingRead?.future ?? seconds;
  }

  @override
  Future<bool> getReduceMotion() async => reduceMotion;

  @override
  Future<void> saveDefaultDurationSeconds(int value) async {
    savedDurations.add(value);
    if (failDurationWrite) throw StateError('Write unavailable');
    if (pendingWrite != null) await pendingWrite!.future;
    seconds = value;
  }

  @override
  Future<void> saveReduceMotion(bool value) async {
    if (failMotionWrite) throw StateError('Write unavailable');
    reduceMotion = value;
  }
}

Future<void> showSettings(
  WidgetTester tester,
  TestSettingsStore store, {
  ValueChanged<bool>? onSavingChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsScreen(
          settingsStore: store,
          onSavingChanged: onSavingChanged,
        ),
      ),
    ),
  );
}

Future<void> changeDuration(WidgetTester tester, int seconds) async {
  tester.widget<Slider>(find.byType(Slider)).onChanged!(seconds.toDouble());
  await tester.pump();
  tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(seconds.toDouble());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Loads settings, drafts duration, and guards one pending write', (
    tester,
  ) async {
    final store = TestSettingsStore()
      ..pendingRead = Completer<int>()
      ..pendingWrite = Completer<void>();
    final pendingStates = <bool>[];
    await showSettings(tester, store, onSavingChanged: pendingStates.add);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    store.pendingRead!.complete(1800);
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(2100);
    await tester.pump();
    expect(find.text('35 min'), findsOneWidget);
    expect(store.savedDurations, isEmpty);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(2100);
    await tester.pump();
    expect(find.text('Saving settings…'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );
    expect(store.savedDurations, [2100]);
    expect(pendingStates, [true]);
    store.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(store.seconds, 2100);
    expect(find.text('Default duration saved.'), findsOneWidget);
    expect(pendingStates, [true, false]);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
  });

  testWidgets('Failed writes restore saved values and allow a later retry', (
    tester,
  ) async {
    final store = TestSettingsStore()..failDurationWrite = true;
    await showSettings(tester, store);
    await tester.pumpAndSettle();
    await changeDuration(tester, 1800);
    expect(find.text('25 min'), findsOneWidget);
    expect(
      find.text(
        'Could not save the duration. The saved value is restored. Try changing it again.',
      ),
      findsOneWidget,
    );
    expect(store.seconds, 1500);
    store.failDurationWrite = false;
    await changeDuration(tester, 1800);
    expect(find.text('30 min'), findsOneWidget);
    expect(store.seconds, 1800);

    store.failMotionWrite = true;
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(
      find.text(
        'Could not save the motion preference. The saved value is restored. Try again.',
      ),
      findsOneWidget,
    );
    store.failMotionWrite = false;
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(store.reduceMotion, isTrue);
    expect(find.text('Motion preference saved.'), findsOneWidget);
  });

  testWidgets('Read failure is visible and retry loads saved values', (
    tester,
  ) async {
    final store = TestSettingsStore()
      ..failRead = true
      ..seconds = 2700
      ..reduceMotion = true;
    await showSettings(tester, store);
    await tester.pumpAndSettle();
    expect(find.text('Could not load settings. Try again.'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    store.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('45 min'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(store.savedDurations, isEmpty);
  });
}
