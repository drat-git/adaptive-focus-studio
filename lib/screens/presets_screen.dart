import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../widgets/display_widgets.dart';
import '../widgets/preset_card.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({
    super.key,
    required this.onAddPreset,
    required this.onEditPreset,
    required this.onOpenSession,
    this.loadPresets,
    this.loadSummary,
    this.deletePreset,
    this.presetHasLogs,
    this.onOpenHistory,
  });

  final Future<bool> Function() onAddPreset;
  final Future<bool> Function(FocusPreset) onEditPreset;
  final Future<bool> Function(FocusPreset) onOpenSession;
  final Future<List<FocusPreset>> Function()? loadPresets;
  final Future<Map<String, Object?>> Function(String? moodTag)? loadSummary;
  final Future<int> Function(int)? deletePreset;
  final Future<bool> Function(int)? presetHasLogs;
  final VoidCallback? onOpenHistory;

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  late Future<List<FocusPreset>> _presets;
  String _mood = 'All moods';
  Map<String, Object?>? _summary;
  int _readNumber = 0;
  bool _confirmingDelete = false;

  @override
  void initState() {
    super.initState();
    _presets = _loadPresets();
  }

  Future<List<FocusPreset>> _loadPresets() {
    final future = _readCatalog();
    // A fast refresh can fail before FutureBuilder reaches the next frame.
    future.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return future;
  }

  Future<List<FocusPreset>> _readCatalog() async {
    final readNumber = ++_readNumber;
    final moodTag = _mood == 'All moods' ? null : _mood;
    final loader = widget.loadPresets ?? DatabaseHelper.instance.getPresets;
    final presets = await loader();
    final summary = widget.loadSummary == null
        ? await DatabaseHelper.instance.getSessionSummary(moodTag: moodTag)
        : await widget.loadSummary!(moodTag);
    if (mounted && readNumber == _readNumber) _summary = summary;
    return presets;
  }

  Widget _sessionSummary() {
    final count = _summary!['count'] as int;
    final average = _summary!['averageSeconds'] as double?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Finished session average'),
        if (count == 0 || average == null)
          Text(
            _mood == 'All moods'
                ? 'No finished sessions yet.'
                : 'No finished sessions for this mood.',
          )
        else
          Text(
            formatDuration(average.round()),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        Text('$count finished ${count == 1 ? 'entry' : 'entries'}'),
        const Text(
          'Uses mood at each session. Cancelled entries are excluded; manual and corrected entries are included.',
        ),
      ],
    );
  }

  void _retry() {
    setState(() {
      _presets = _loadPresets();
    });
  }

  Future<void> _editPreset(FocusPreset? preset) async {
    final changed = preset == null
        ? await widget.onAddPreset()
        : await widget.onEditPreset(preset);
    if (changed && mounted) _retry();
  }

  Future<void> _openSession(FocusPreset preset) async {
    final changed = await widget.onOpenSession(preset);
    if (changed && mounted) _retry();
  }

  Future<void> _deletePreset(FocusPreset preset) async {
    if (_confirmingDelete) return;
    _confirmingDelete = true;
    final result = await showDialog<_PresetDeleteResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeletePresetDialog(
        preset: preset,
        deletePreset:
            widget.deletePreset ?? DatabaseHelper.instance.deletePreset,
        presetHasLogs:
            widget.presetHasLogs ?? DatabaseHelper.instance.presetHasLogs,
      ),
    );
    _confirmingDelete = false;
    if (!mounted || result == null) return;
    if (result == _PresetDeleteResult.history) {
      widget.onOpenHistory?.call();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == _PresetDeleteResult.deleted
              ? 'Preset deleted.'
              : 'This preset no longer exists. Reloading the list.',
        ),
      ),
    );
    _retry();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionHeading(
          title: 'Study presets',
          description: 'Choose a mood and duration for your next study block.',
        ),
        const Text('Mood'),
        DropdownButton<String>(
          value: _mood,
          isExpanded: true,
          items: ['All moods', ...FocusPreset.moodTags].map((mood) {
            return DropdownMenuItem(value: mood, child: Text(mood));
          }).toList(),
          onChanged: (mood) {
            if (mood != null) {
              setState(() {
                _mood = mood;
                _presets = _loadPresets();
              });
            }
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _editPreset(null),
          icon: const Icon(Icons.add),
          label: const Text('Add preset'),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<FocusPreset>>(
          future: _presets,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Could not load presets.'),
                  TextButton(onPressed: _retry, child: const Text('Try again')),
                ],
              );
            }
            final allPresets = snapshot.data!;
            final visible = allPresets.where((preset) {
              return _mood == 'All moods' || preset.moodTag == _mood;
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sessionSummary(),
                const SizedBox(height: 24),
                if (allPresets.isEmpty)
                  const Text('Add your first preset to set up a study block.')
                else if (visible.isEmpty)
                  const Text('No presets match this mood.')
                else
                  ...visible.map((preset) {
                    return PresetCard(
                      preset: preset,
                      onOpen: () => _openSession(preset),
                      onEdit: () => _editPreset(preset),
                      onDelete: () => _deletePreset(preset),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _PresetDeleteResult { deleted, missing, history }

class _DeletePresetDialog extends StatefulWidget {
  const _DeletePresetDialog({
    required this.preset,
    required this.deletePreset,
    required this.presetHasLogs,
  });

  final FocusPreset preset;
  final Future<int> Function(int) deletePreset;
  final Future<bool> Function(int) presetHasLogs;

  @override
  State<_DeletePresetDialog> createState() => _DeletePresetDialogState();
}

class _DeletePresetDialogState extends State<_DeletePresetDialog> {
  bool _pending = false;
  bool _protected = false;
  String? _error;

  Future<void> _delete() async {
    if (_pending || _protected) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final id = widget.preset.id!;
      if (await widget.presetHasLogs(id)) {
        if (!mounted) return;
        setState(() => _protected = true);
        return;
      }
      final count = await widget.deletePreset(id);
      if (count != 0 && count != 1) {
        throw StateError('Unexpected delete result.');
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        count == 1 ? _PresetDeleteResult.deleted : _PresetDeleteResult.missing,
      );
    } on DatabaseException {
      // A session could be added after the first relationship check.
      try {
        final hasLogs = await widget.presetHasLogs(widget.preset.id!);
        if (mounted) setState(() => _protected = hasLogs);
      } catch (_) {
        // Keep a read failure separate from a confirmed protected preset.
      }
      if (mounted && !_protected) {
        setState(() => _error = 'Could not delete this preset. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete this preset. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<_PresetDeleteResult>(
      canPop: !_pending,
      child: AlertDialog(
        title: Text(
          _protected ? 'Keep this preset' : 'Delete "${widget.preset.label}"?',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _protected
                    ? 'This preset has saved sessions. To delete it, first remove its logs from History. Your history has been kept.'
                    : 'This removes the preset. Presets with saved sessions cannot be deleted until their logs are removed from History.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.pop(context),
            child: Text(_protected ? 'Keep preset' : 'Cancel'),
          ),
          if (_protected)
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _PresetDeleteResult.history),
              child: const Text('Open History'),
            )
          else
            FilledButton(
              onPressed: _pending ? null : _delete,
              child: Text(_pending ? 'Deleting…' : 'Delete preset'),
            ),
        ],
      ),
    );
  }
}
