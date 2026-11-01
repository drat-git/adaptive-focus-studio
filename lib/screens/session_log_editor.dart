import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/display_widgets.dart';

class SessionLogEditor extends StatefulWidget {
  const SessionLogEditor({
    super.key,
    required this.presets,
    this.log,
    this.saveLog,
    this.onOpenPresets,
    this.now,
  });

  final List<FocusPreset> presets;
  final SessionLog? log;
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
  bool _missing = false;
  bool _confirmingDiscard = false;
  String? _dateError;
  String? _error;

  DateTime _now() => widget.now?.call() ?? DateTime.now();
  bool get _editing => widget.log != null;
  bool get _enabled => !_saving && !_missing;
  bool get _noPresets => !_editing && widget.presets.isEmpty;

  FocusPreset? get _preset {
    for (final preset in widget.presets) {
      if (preset.id == _presetId) return preset;
    }
    return null;
  }

  bool get _hasChanges {
    return _presetId != _initialPresetId ||
        _mood != _initialMood ||
        _status != (widget.log?.status ?? 'finished') ||
        _dateTime != _initialDateTime ||
        _completed.text != (widget.log?.completedSeconds.toString() ?? '') ||
        _note.text != (widget.log?.note ?? '');
  }

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    if (log != null) {
      _presetId = log.presetId;
      _mood = log.moodTagSnapshot;
      _status = log.status;
      _completed.text = log.completedSeconds.toString();
      _note.text = log.note;
    } else if (widget.presets.isNotEmpty) {
      _presetId = widget.presets.first.id;
      _mood = widget.presets.first.moodTag;
    }
    _initialPresetId = _presetId;
    _initialMood = _mood;
    final now = _now().toLocal();
    _dateTime = log == null
        ? DateTime(now.year, now.month, now.day, now.hour, now.minute)
        : DateTime.fromMillisecondsSinceEpoch(
            log.startedAt,
            isUtc: true,
          ).toLocal();
    _initialDateTime = _dateTime;
  }

  Future<void> _chooseDate() async {
    if (!_enabled) return;
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
    if (chosen.year == _dateTime.year &&
        chosen.month == _dateTime.month &&
        chosen.day == _dateTime.day) {
      return;
    }
    setState(() {
      _dateTime = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        _dateTime.hour,
        _dateTime.minute,
        _dateTime.second,
        _dateTime.millisecond,
        _dateTime.microsecond,
      );
      _dateError = null;
    });
  }

  Future<void> _chooseTime() async {
    if (!_enabled) return;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted || chosen == null) return;
    if (chosen.hour == _dateTime.hour && chosen.minute == _dateTime.minute) {
      return;
    }
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        chosen.hour,
        chosen.minute,
        _dateTime.second,
        _dateTime.millisecond,
        _dateTime.microsecond,
      );
      _dateError = null;
    });
  }

  Future<void> _requestClose() async {
    if (_saving || _confirmingDiscard) return;
    if (_missing) {
      Navigator.pop(context, true);
      return;
    }
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
    if (!_enabled || _noPresets) return;
    if (_editing && !_hasChanges) {
      Navigator.pop(context, false);
      return;
    }
    final valid = _formKey.currentState!.validate();
    final timestamp = _dateTime.toUtc().millisecondsSinceEpoch;
    final dateError = widget.log?.startedAt == timestamp
        ? null
        : SessionLog.validateManualStartedAt(
            timestamp,
            now: _now().toUtc().millisecondsSinceEpoch,
          );
    setState(() => _dateError = dateError);
    if (!valid || dateError != null) return;
    final log = SessionLog(
      id: widget.log?.id,
      presetId: widget.log?.presetId ?? _preset!.id!,
      startedAt: timestamp,
      plannedSecondsSnapshot:
          widget.log?.plannedSecondsSnapshot ?? _preset!.plannedSeconds,
      completedSeconds: int.parse(_completed.text.trim()),
      moodTagSnapshot: _mood,
      status: _status,
      source: widget.log == null || widget.log!.source == 'manual'
          ? 'manual'
          : 'edited_timer',
      note: _note.text,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saver =
          widget.saveLog ??
          (_editing
              ? DatabaseHelper.instance.updateSessionLog
              : DatabaseHelper.instance.insertSessionLog);
      final result = await saver(log);
      if (!mounted) return;
      if (_editing && result == 0) {
        setState(() {
          _saving = false;
          _missing = true;
          _error = 'This entry no longer exists. Return to History to refresh.';
        });
        return;
      }
      if (result <= 0 || (_editing && result != 1)) {
        throw StateError('The entry was not saved.');
      }
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
      canPop: !_saving && !_hasChanges && !_missing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _requestClose();
      },
      child: AlertDialog(
        title: Text(_editing ? 'Edit session entry' : 'Manual session entry'),
        content: SizedBox(
          width: 440,
          child: _noPresets
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
                        if (_editing)
                          Text(
                            'Preset: ${_preset?.label ?? 'Unavailable preset'} (#$_presetId)',
                          )
                        else
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
                            onChanged: !_enabled
                                ? null
                                : (id) {
                                    setState(() {
                                      _presetId = id;
                                      _mood = _preset?.moodTag ?? 'Calm';
                                    });
                                  },
                            validator: (_) => _preset == null
                                ? 'Choose a saved preset.'
                                : null,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Planned snapshot: ${formatDuration(widget.log?.plannedSecondsSnapshot ?? _preset!.plannedSeconds)}',
                        ),
                        const SizedBox(height: 16),
                        const Text('Local date and time'),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('session-date'),
                              onPressed: _enabled ? _chooseDate : null,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(labels.formatMediumDate(_dateTime)),
                            ),
                            OutlinedButton.icon(
                              key: const Key('session-time'),
                              onPressed: _enabled ? _chooseTime : null,
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
                          enabled: _enabled,
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
                          onChanged: !_enabled
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
                          onChanged: !_enabled
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
                          enabled: _enabled,
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
                        Text(
                          widget.log == null || widget.log!.source == 'manual'
                              ? 'Source: Manual entry'
                              : widget.log!.source == 'edited_timer' ||
                                    _hasChanges
                              ? 'Source after save: Corrected timer'
                              : 'Source: Measured timer',
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _requestClose,
            child: Text(
              _missing
                  ? 'Return to History'
                  : _noPresets
                  ? 'Close'
                  : 'Cancel',
            ),
          ),
          if (_noPresets && widget.onOpenPresets != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context, false);
                widget.onOpenPresets!();
              },
              child: const Text('Open Presets'),
            ),
          if (!_noPresets)
            FilledButton(
              onPressed: _enabled ? _save : null,
              child: Text(_saving ? 'Saving…' : 'Save entry'),
            ),
        ],
      ),
    );
  }
}
