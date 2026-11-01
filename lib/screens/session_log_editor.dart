import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/display_widgets.dart';

class SessionLogEditor extends StatefulWidget {
  const SessionLogEditor({
    super.key,
    required this.presets,
    this.saveLog,
    this.onOpenPresets,
    this.now,
  });

  final List<FocusPreset> presets;
  final Future<int> Function(SessionLog)? saveLog;
  final VoidCallback? onOpenPresets;
  final DateTime Function()? now;

  @override
  State<SessionLogEditor> createState() => _SessionLogEditorState();
}

class _SessionLogEditorState extends State<SessionLogEditor> {
  final _formKey = GlobalKey<FormState>();
  final _completed = TextEditingController();
  final _note = TextEditingController();
  int? _presetId;
  int? _initialPresetId;
  String _mood = 'Calm';
  String _initialMood = 'Calm';
  String _status = 'finished';
  late DateTime _dateTime;
  late final DateTime _initialDateTime;
  bool _saving = false;
  bool _confirmingDiscard = false;
  String? _dateError;
  String? _error;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  FocusPreset? get _preset {
    for (final preset in widget.presets) {
      if (preset.id == _presetId) return preset;
    }
    return null;
  }

  bool get _hasChanges {
    return _presetId != _initialPresetId ||
        _mood != _initialMood ||
        _status != 'finished' ||
        _dateTime != _initialDateTime ||
        _completed.text.isNotEmpty ||
        _note.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.presets.isNotEmpty) {
      _presetId = widget.presets.first.id;
      _initialPresetId = _presetId;
      _mood = widget.presets.first.moodTag;
      _initialMood = _mood;
    }
    final now = _now().toLocal();
    _dateTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _initialDateTime = _dateTime;
  }

  Future<void> _chooseDate() async {
    if (_saving) return;
    final now = _now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _dateTime.isAfter(today) ? today : _dateTime,
      firstDate: DateTime(1970),
      lastDate: today,
      currentDate: now,
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _dateTime = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        _dateTime.hour,
        _dateTime.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _chooseTime() async {
    if (_saving) return;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        chosen.hour,
        chosen.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _requestClose() async {
    if (_saving || _confirmingDiscard) return;
    if (_hasChanges) {
      _confirmingDiscard = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this entry?'),
          content: const Text('Your session entry has not been saved.'),
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
    if (mounted) Navigator.pop(context, false);
  }

  String? _validateCompleted(String? value) {
    final seconds = int.tryParse((value ?? '').trim());
    if (seconds == null) return 'Enter a whole number of seconds.';
    return SessionLog.validateCompletedSeconds(seconds);
  }

  Future<void> _save() async {
    if (_saving || widget.presets.isEmpty) return;
    final valid = _formKey.currentState!.validate();
    final dateError = SessionLog.validateManualStartedAt(
      _dateTime.toUtc().millisecondsSinceEpoch,
      now: _now().toUtc().millisecondsSinceEpoch,
    );
    setState(() => _dateError = dateError);
    if (!valid || dateError != null) return;
    final preset = _preset!;
    final log = SessionLog(
      presetId: preset.id!,
      startedAt: _dateTime.toUtc().millisecondsSinceEpoch,
      plannedSecondsSnapshot: preset.plannedSeconds,
      completedSeconds: int.parse(_completed.text.trim()),
      moodTagSnapshot: _mood,
      status: _status,
      source: 'manual',
      note: _note.text,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saver = widget.saveLog ?? DatabaseHelper.instance.insertSessionLog;
      final id = await saver(log);
      if (id <= 0) throw StateError('The entry was not saved.');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this entry. Your changes are still here. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _completed.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context);
    return PopScope<bool>(
      canPop: !_saving && !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _requestClose();
      },
      child: AlertDialog(
        title: const Text('Manual session entry'),
        content: SizedBox(
          width: 440,
          child: widget.presets.isEmpty
              ? const Text(
                  'Create a preset in Presets, then return to add a session entry.',
                )
              : SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<int>(
                          initialValue: _presetId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Preset',
                          ),
                          items: widget.presets
                              .map(
                                (preset) => DropdownMenuItem(
                                  value: preset.id,
                                  child: Text(
                                    '${preset.label} (#${preset.id})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (id) {
                                  setState(() {
                                    _presetId = id;
                                    _mood = _preset?.moodTag ?? 'Calm';
                                  });
                                },
                          validator: (_) =>
                              _preset == null ? 'Choose a saved preset.' : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Planned snapshot: ${formatDuration(_preset?.plannedSeconds ?? 1500)}',
                        ),
                        const SizedBox(height: 16),
                        const Text('Local date and time'),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('session-date'),
                              onPressed: _saving ? null : _chooseDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(labels.formatMediumDate(_dateTime)),
                            ),
                            OutlinedButton.icon(
                              key: const Key('session-time'),
                              onPressed: _saving ? null : _chooseTime,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                labels.formatTimeOfDay(
                                  TimeOfDay.fromDateTime(_dateTime),
                                  alwaysUse24HourFormat:
                                      MediaQuery.alwaysUse24HourFormatOf(
                                        context,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_dateError != null)
                          Text(
                            _dateError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _completed,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Completed seconds',
                            helperText: 'Enter 0 to 7200 seconds.',
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateCompleted,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_presetId),
                          initialValue: _mood,
                          decoration: const InputDecoration(
                            labelText: 'Mood at session',
                          ),
                          items: FocusPreset.moodTags
                              .map(
                                (mood) => DropdownMenuItem(
                                  value: mood,
                                  child: Text(mood),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (mood) {
                                  if (mood != null) {
                                    setState(() => _mood = mood);
                                  }
                                },
                          validator: (mood) =>
                              FocusPreset.validateMoodTag(mood ?? ''),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: SessionLog.statuses
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status == 'finished'
                                        ? 'Finished'
                                        : 'Cancelled',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (status) {
                                  if (status != null) {
                                    setState(() => _status = status);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _note,
                          enabled: !_saving,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Optional note',
                            helperText: 'Use no more than 240 characters.',
                          ),
                          validator: (value) =>
                              SessionLog.validateNote(value ?? ''),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        const Text('Source: Manual entry'),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _requestClose,
            child: Text(widget.presets.isEmpty ? 'Close' : 'Cancel'),
          ),
          if (widget.presets.isEmpty && widget.onOpenPresets != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context, false);
                widget.onOpenPresets!();
              },
              child: const Text('Open Presets'),
            ),
          if (widget.presets.isNotEmpty)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save entry'),
            ),
        ],
      ),
    );
  }
}
