import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/display_widgets.dart';
import 'session_log_editor.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.databaseHelper, this.onOpenPresets});

  final DatabaseHelper? databaseHelper;
  final VoidCallback? onOpenPresets;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final DatabaseHelper _database;
  List<SessionLog> _logs = [];
  Map<int, String> _presetNames = {};
  List<FocusPreset> _presets = [];
  String _mood = 'All moods';
  int _finishedCount = 0;
  double? _averageSeconds;
  bool _loading = false;
  String? _error;
  bool _editingEntry = false;
  bool _confirmingDelete = false;

  @override
  void initState() {
    super.initState();
    _database = widget.databaseHelper ?? DatabaseHelper.instance;
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final presets = await _database.getPresets();
      final logs = await _database.getSessionLogs();
      final summary = await _database.getSessionSummary(
        moodTag: _mood == 'All moods' ? null : _mood,
      );
      if (!mounted) return;
      setState(() {
        _presets = presets;
        _presetNames = {for (final preset in presets) preset.id!: preset.label};
        _logs = logs;
        _finishedCount = summary['count'] as int;
        _averageSeconds = summary['averageSeconds'] as double?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load session history. Try again.';
      });
    }
  }

  Future<void> _openEditor([SessionLog? log]) async {
    if (_editingEntry || _loading || _error != null) return;
    _editingEntry = true;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionLogEditor(
        presets: _presets,
        log: log,
        saveLog: log == null
            ? _database.insertSessionLog
            : _database.updateSessionLog,
        onOpenPresets: widget.onOpenPresets,
      ),
    );
    _editingEntry = false;
    if (mounted && saved == true) _load();
  }

  Future<void> _deleteEntry(SessionLog log) async {
    if (_confirmingDelete) return;
    _confirmingDelete = true;
    final count = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteSessionDialog(
        log: log,
        description:
            '${_presetNames[log.presetId] ?? 'Preset #${log.presetId}'} · ${_localDateTime(log.startedAt)}',
        deleteLog: _database.deleteSessionLog,
      ),
    );
    _confirmingDelete = false;
    if (!mounted || count == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Entry deleted.'
              : 'This entry no longer exists. Reloading history.',
        ),
      ),
    );
    _load();
  }

  String _localDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    ).toLocal();
    final labels = MaterialLocalizations.of(context);
    final time = labels.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '${labels.formatMediumDate(date)} · $time';
  }

  Widget _sessionCard(SessionLog log) {
    const sources = {
      'timer': 'Measured timer',
      'manual': 'Manual entry',
      'edited_timer': 'Corrected timer',
    };
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(log.id),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _presetNames[log.presetId] ?? 'Preset #${log.presetId} unavailable',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Entry #${log.id} · ${_localDateTime(log.startedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Completed: ${formatDuration(log.completedSeconds)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text('Planned: ${formatDuration(log.plannedSecondsSnapshot)}'),
          const SizedBox(height: 8),
          Text('Mood at session: ${log.moodTagSnapshot}'),
          Text(log.status == 'finished' ? 'Finished' : 'Cancelled'),
          Text('Source: ${sources[log.source]}'),
          if (log.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Note: ${log.note}'),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _openEditor(log),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _deleteEntry(log),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionSummary() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finished session average',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          if (_finishedCount == 0 || _averageSeconds == null)
            Text(
              _mood == 'All moods'
                  ? 'No finished sessions yet.'
                  : 'No finished sessions for this mood.',
            )
          else ...[
            Text(
              formatDuration(_averageSeconds!.round()),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text('Average completed time, rounded to seconds.'),
          ],
          Text(
            '$_finishedCount finished ${_finishedCount == 1 ? 'entry' : 'entries'}',
          ),
          const SizedBox(height: 6),
          Text(
            'Cancelled sessions are excluded. Manual and corrected entries are included.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _logs.where((log) {
      return _mood == 'All moods' || log.moodTagSnapshot == _mood;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionHeading(
          title: 'Session history',
          description: 'Review planned and completed study time.',
        ),
        FilledButton.icon(
          onPressed: _loading || _error != null ? null : () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Add manual entry'),
        ),
        const SizedBox(height: 16),
        const Text('Mood at session'),
        DropdownButton<String>(
          value: _mood,
          isExpanded: true,
          items: ['All moods', ...FocusPreset.moodTags].map((mood) {
            return DropdownMenuItem(value: mood, child: Text(mood));
          }).toList(),
          onChanged: _loading
              ? null
              : (mood) {
                  if (mood != null) {
                    setState(() => _mood = mood);
                    _load();
                  }
                },
        ),
        TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh history'),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ] else ...[
          const SizedBox(height: 12),
          _sessionSummary(),
          const SizedBox(height: 24),
          if (_logs.isEmpty)
            const Text(
              'No session history yet. Finish a session to see it here.',
            )
          else if (visible.isEmpty)
            const Text('No sessions match this mood.')
          else
            ...visible.map(_sessionCard),
        ],
      ],
    );
  }
}

class _DeleteSessionDialog extends StatefulWidget {
  const _DeleteSessionDialog({
    required this.log,
    required this.description,
    required this.deleteLog,
  });

  final SessionLog log;
  final String description;
  final Future<int> Function(int) deleteLog;

  @override
  State<_DeleteSessionDialog> createState() => _DeleteSessionDialogState();
}

class _DeleteSessionDialogState extends State<_DeleteSessionDialog> {
  bool _pending = false;
  String? _error;

  Future<void> _delete() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final count = await widget.deleteLog(widget.log.id!);
      if (count != 0 && count != 1) {
        throw StateError('Unexpected delete result.');
      }
      if (mounted) Navigator.pop(context, count);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = 'Could not delete this entry. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: !_pending,
      child: AlertDialog(
        title: Text('Delete entry #${widget.log.id}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description),
              const SizedBox(height: 12),
              const Text(
                'This permanently removes the session entry. The preset will be kept.',
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _pending ? null : _delete,
            child: Text(_pending ? 'Deleting…' : 'Delete entry'),
          ),
        ],
      ),
    );
  }
}
