import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/settings_store.dart';
import '../models/focus_preset.dart';
import '../widgets/display_widgets.dart';

class PresetEditorScreen extends StatefulWidget {
  const PresetEditorScreen({
    super.key,
    this.preset,
    this.loadDefaultDuration,
    this.savePreset,
  });

  final FocusPreset? preset;
  final Future<int> Function()? loadDefaultDuration;
  final Future<int> Function(FocusPreset)? savePreset;

  @override
  State<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends State<PresetEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  String _mood = 'Calm';
  int _seconds = 1500;
  int _initialSeconds = 1500;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _missing = false;
  bool _confirmingDiscard = false;
  String? _error;

  bool get _hasChanges {
    return _label.text != (widget.preset?.label ?? '') ||
        _mood != (widget.preset?.moodTag ?? 'Calm') ||
        _seconds != _initialSeconds;
  }

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _label = TextEditingController(text: preset?.label ?? '');
    if (preset == null) {
      _loadDefault();
    } else {
      _mood = preset.moodTag;
      _seconds = preset.plannedSeconds;
      _initialSeconds = _seconds;
      _loading = false;
    }
  }

  Future<void> _loadDefault() async {
    try {
      final loader =
          widget.loadDefaultDuration ??
          SettingsStore().getDefaultDurationSeconds;
      final seconds = await loader();
      if (FocusPreset.validatePlannedSeconds(seconds) != null) {
        throw const FormatException('Invalid default duration.');
      }
      if (!mounted) return;
      setState(() {
        _seconds = seconds;
        _initialSeconds = seconds;
        _loading = false;
        _loadFailed = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = 'Could not load the default duration. Try again.';
      });
    }
  }

  Future<void> _requestClose() async {
    if (_saving || _confirmingDiscard) return;
    if (_hasChanges) {
      _confirmingDiscard = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard these changes?'),
          content: const Text('Your preset changes have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      _confirmingDiscard = false;
      if (!mounted || discard != true) return;
    }
    if (mounted) Navigator.pop(context, _missing);
  }

  Future<void> _save() async {
    if (_saving || _loading || _loadFailed || _missing) return;
    if (!_formKey.currentState!.validate()) return;
    final preset = FocusPreset(
      id: widget.preset?.id,
      label: _label.text,
      moodTag: _mood,
      plannedSeconds: _seconds,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saver =
          widget.savePreset ??
          (preset.id == null
              ? DatabaseHelper.instance.insertPreset
              : DatabaseHelper.instance.updatePreset);
      final result = await saver(preset);
      if (!mounted) return;
      if (preset.id != null && result == 0) {
        setState(() {
          _saving = false;
          _missing = true;
          _error =
              'This preset no longer exists. Return to Presets to refresh.';
        });
        return;
      }
      if (result <= 0 || (preset.id != null && result != 1)) {
        throw StateError('The preset was not saved.');
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this preset. Your changes are still here. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_saving && !_hasChanges && !_missing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.preset == null ? 'New preset' : 'Edit preset'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : _requestClose,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SectionHeading(
              title: 'Preset details',
              description:
                  'A label, mood, and duration describe a study block.',
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loadFailed)
              TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadFailed = false;
                    _error = null;
                  });
                  _loadDefault();
                },
                child: const Text('Try again'),
              ),
            if (!_loading && !_loadFailed)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _label,
                      enabled: !_saving && !_missing,
                      decoration: const InputDecoration(
                        labelText: 'Label',
                        helperText: 'Use 1 to 40 characters.',
                      ),
                      validator: (value) =>
                          FocusPreset.validateLabel(value ?? ''),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _mood,
                      decoration: const InputDecoration(labelText: 'Mood'),
                      items: FocusPreset.moodTags
                          .map(
                            (mood) => DropdownMenuItem(
                              value: mood,
                              child: Text(mood),
                            ),
                          )
                          .toList(),
                      onChanged: _saving || _missing
                          ? null
                          : (mood) {
                              if (mood != null) setState(() => _mood = mood);
                            },
                      validator: (value) =>
                          FocusPreset.validateMoodTag(value ?? ''),
                    ),
                    const SizedBox(height: 24),
                    const Text('Duration for this preset'),
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
                      onChanged: _saving || _missing
                          ? null
                          : (value) => setState(() => _seconds = value.round()),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('1 min'), Text('120 min')],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving || _missing ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save preset'),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: _saving ? null : _requestClose,
              child: Text(_missing ? 'Return to presets' : 'Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
