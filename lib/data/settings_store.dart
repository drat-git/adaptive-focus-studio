import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_preset.dart';

class SettingsStore {
  final SharedPreferencesAsync _preferences;
  final String keyPrefix;

  SettingsStore({SharedPreferencesAsync? preferences, this.keyPrefix = ''})
    : _preferences = preferences ?? SharedPreferencesAsync();

  Future<int> getDefaultDurationSeconds() async {
    final value = await _preferences.getInt(
      '${keyPrefix}defaultDurationSeconds',
    );
    if (value == null) {
      return 1500;
    }
    if (FocusPreset.validatePlannedSeconds(value) != null) {
      throw const FormatException('Saved default duration is invalid.');
    }
    return value;
  }

  Future<bool> getReduceMotion() async {
    return await _preferences.getBool('${keyPrefix}reduceMotion') ?? false;
  }

  Future<void> saveDefaultDurationSeconds(int value) async {
    final error = FocusPreset.validatePlannedSeconds(value);
    if (error != null) {
      throw ArgumentError.value(value, 'defaultDurationSeconds', error);
    }
    await _preferences.setInt('${keyPrefix}defaultDurationSeconds', value);
  }

  Future<void> saveReduceMotion(bool value) async {
    await _preferences.setBool('${keyPrefix}reduceMotion', value);
  }
}
