import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../models/focus_preset.dart';
import '../widgets/display_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.settingsStore, this.onSavingChanged});

  final SettingsStore? settingsStore;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsStore? _store;
  int _seconds = 1500;
  int _savedSeconds = 1500;
  bool _reduceMotion = false;
  bool _savedReduceMotion = false;
  bool _loading = false;
  bool _loadFailed = false;
  bool _saving = false;
  String? _message;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _message = null;
      _hasError = false;
    });
    try {
      final store = _store ??= widget.settingsStore ?? SettingsStore();
      final seconds = await store.getDefaultDurationSeconds();
      final reduceMotion = await store.getReduceMotion();
      if (FocusPreset.validatePlannedSeconds(seconds) != null) {
        throw const FormatException('Invalid default duration.');
      }
      if (!mounted) return;
      setState(() {
        _seconds = seconds;
        _savedSeconds = seconds;
        _reduceMotion = reduceMotion;
        _savedReduceMotion = reduceMotion;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _hasError = true;
        _message = 'Could not load settings. Try again.';
      });
    }
  }

  Future<void> _saveDuration(double value) async {
    if (_saving || _loading || _loadFailed) return;
    final seconds = value.round();
    if (seconds == _savedSeconds) return;
    setState(() {
      _seconds = seconds;
      _saving = true;
      _message = null;
      _hasError = false;
    });
    widget.onSavingChanged?.call(true);
    try {
      await _store!.saveDefaultDurationSeconds(seconds);
      if (!mounted) return;
      setState(() {
        _savedSeconds = seconds;
        _message = 'Default duration saved.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seconds = _savedSeconds;
        _hasError = true;
        _message = 'Could not save the duration. The saved value is restored. Try changing it again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  Future<void> _saveMotion(bool? value) async {
    if (_saving || _loading || _loadFailed || value == null) return;
    if (value == _savedReduceMotion) return;
    setState(() {
      _reduceMotion = value;
      _saving = true;
      _message = null;
      _hasError = false;
    });
    widget.onSavingChanged?.call(true);
    try {
      await _store!.saveReduceMotion(value);
      if (!mounted) return;
      setState(() {
        _savedReduceMotion = value;
        _message = 'Motion preference saved.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reduceMotion = _savedReduceMotion;
        _hasError = true;
        _message = 'Could not save the motion preference. The saved value is restored. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_saving,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_saving) const Text('Saving settings…'),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _message!,
                style: _hasError
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ),
          if (_loadFailed)
            TextButton(onPressed: _load, child: const Text('Try again')),
          const SectionHeading(
            title: 'Default duration',
            description: 'Used when creating a new preset.',
          ),
          const Text(
            'Existing presets and active sessions keep their own duration.',
          ),
          if (!_loading && !_loadFailed) ...[
            const SizedBox(height: 12),
            Text(
              formatDuration(_seconds),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              value: _seconds.toDouble(),
              min: 60,
              max: 7200,
              divisions: 119,
              label: formatDuration(_seconds),
              semanticFormatterCallback: (value) =>
                  formatDuration(value.round()),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _seconds = value.round()),
              onChangeEnd: _saving ? null : _saveDuration,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('1 min'), Text('120 min')],
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Reduce motion',
            description: 'Use less movement when session status changes.',
          ),
          if (!_loading && !_loadFailed)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce session motion'),
              subtitle: const Text(
                'The device motion preference is also respected.',
              ),
              value: _reduceMotion,
              onChanged: _saving ? null : _saveMotion,
            ),
          const Text('The app works in silence.'),
        ],
      ),
    );
  }
}
