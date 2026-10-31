import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adaptive_focus_studio/main.dart';

void main() {
  testWidgets('Main destinations show their own content', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Study presets'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Session records will appear here.'), findsOneWidget);
    expect(find.text('Study presets'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Default duration'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Study presets'), findsOneWidget);
  });

  testWidgets('Editor and session return to Presets', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Add preset'));
    await tester.pumpAndSettle();
    expect(find.text('Preset details'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Study presets'), findsOneWidget);

    await tester.tap(find.text('View focus session'));
    await tester.pumpAndSettle();
    expect(find.text('No preset selected.'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start session'),
    );
    expect(start.onPressed, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Study presets'), findsOneWidget);
  });
}
