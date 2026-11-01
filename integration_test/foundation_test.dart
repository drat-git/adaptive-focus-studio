import 'package:adaptive_focus_studio/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/widget_test.dart' as navigation_tests;
import 'database_schema_test.dart' as schema_tests;
import 'preset_database_test.dart' as preset_tests;

class UnavailablePreferences extends SharedPreferencesAsync {
  @override
  Future<int?> getInt(String key) async {
    throw StateError('Test preference read failure.');
  }

  @override
  Future<bool?> getBool(String key) async {
    throw StateError('Test preference read failure.');
  }

  @override
  Future<void> setInt(String key, int value) async {
    throw StateError('Test preference write failure.');
  }

  @override
  Future<void> setBool(String key, bool value) async {
    throw StateError('Test preference write failure.');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Foundation navigation', navigation_tests.main);
  group('Foundation schema', schema_tests.main);
  group('Foundation preset storage', preset_tests.main);

  testWidgets('Defaults and writes use only the selected preference keys', (
    tester,
  ) async {
    const prefix = 'foundation_test.';
    final preferences = SharedPreferencesAsync();
    try {
      await preferences.remove('${prefix}defaultDurationSeconds');
      await preferences.remove('${prefix}reduceMotion');
      await preferences.setString('${prefix}untouched', 'Keep this value');
      final settings = SettingsStore(keyPrefix: prefix);
      expect(await settings.getDefaultDurationSeconds(), 1500);
      expect(await settings.getReduceMotion(), isFalse);
      await settings.saveDefaultDurationSeconds(60);
      expect(await settings.getDefaultDurationSeconds(), 60);
      await settings.saveDefaultDurationSeconds(7200);
      expect(await settings.getDefaultDurationSeconds(), 7200);
      await settings.saveDefaultDurationSeconds(2100);
      await settings.saveReduceMotion(true);
      final freshReader = SettingsStore(keyPrefix: prefix);
      expect(await freshReader.getDefaultDurationSeconds(), 2100);
      expect(await freshReader.getReduceMotion(), isTrue);
      expect(
        await preferences.getString('${prefix}untouched'),
        'Keep this value',
      );
    } finally {
      await preferences.remove('${prefix}defaultDurationSeconds');
      await preferences.remove('${prefix}reduceMotion');
      await preferences.remove('${prefix}untouched');
    }
  });

  testWidgets('Invalid input and saved values do not become false defaults', (
    tester,
  ) async {
    const prefix = 'foundation_invalid_test.';
    final preferences = SharedPreferencesAsync();
    final settings = SettingsStore(keyPrefix: prefix);
    try {
      await settings.saveDefaultDurationSeconds(1500);
      await expectLater(
        settings.saveDefaultDurationSeconds(59),
        throwsArgumentError,
      );
      await expectLater(
        settings.saveDefaultDurationSeconds(7201),
        throwsArgumentError,
      );
      expect(await settings.getDefaultDurationSeconds(), 1500);
      await preferences.setInt('${prefix}defaultDurationSeconds', 0);
      await expectLater(
        settings.getDefaultDurationSeconds(),
        throwsFormatException,
      );
      await preferences.setString('${prefix}reduceMotion', 'yes');
      await expectLater(settings.getReduceMotion(), throwsA(isA<TypeError>()));
    } finally {
      await preferences.remove('${prefix}defaultDurationSeconds');
      await preferences.remove('${prefix}reduceMotion');
    }
  });

  testWidgets('Read and write failures reach the caller', (tester) async {
    final settings = SettingsStore(preferences: UnavailablePreferences());
    await expectLater(settings.getDefaultDurationSeconds(), throwsStateError);
    await expectLater(settings.getReduceMotion(), throwsStateError);
    await expectLater(
      settings.saveDefaultDurationSeconds(1800),
      throwsStateError,
    );
    await expectLater(settings.saveReduceMotion(true), throwsStateError);
  });
}
