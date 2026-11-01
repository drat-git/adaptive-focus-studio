import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/display_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.databaseHelper});

  final DatabaseHelper? databaseHelper;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final DatabaseHelper _database;
  List<SessionLog> _logs = [];
  Map<int, String> _presetNames = {};
  String _mood = 'All moods';
  int _finishedCount = 0;
  double? _averageSeconds;
  bool _loading = false;
  String? _error;

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
    return Card(
      key: ValueKey(log.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _presetNames[log.presetId] ??
                  'Preset #${log.presetId} unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Entry #${log.id} · ${_localDateTime(log.startedAt)}'),
            const Divider(),
            Text('Planned: ${formatDuration(log.plannedSecondsSnapshot)}'),
            Text('Completed: ${formatDuration(log.completedSeconds)}'),
            Text('Mood at session: ${log.moodTagSnapshot}'),
            Text(log.status == 'finished' ? 'Finished' : 'Cancelled'),
            Text('Source: ${sources[log.source]}'),
            if (log.note.isNotEmpty) Text('Note: ${log.note}'),
          ],
        ),
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
          const SectionHeading(title: 'Finished session average'),
          if (_finishedCount == 0 || _averageSeconds == null)
            Text(
              _mood == 'All moods'
                  ? 'No finished sessions yet.'
                  : 'No finished sessions for this mood.',
            )
          else ...[
            Text(
              formatDuration(_averageSeconds!.round()),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Average completed time, rounded to seconds.'),
          ],
          Text(
            '$_finishedCount finished ${_finishedCount == 1 ? 'entry' : 'entries'}',
          ),
          const Text(
            'Cancelled sessions are excluded. Manual and corrected entries are included.',
          ),
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
