import 'dart:async';

import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import '../widgets/display_widgets.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key, this.preset, this.stopwatch});

  final FocusPreset? preset;
  final Stopwatch? stopwatch;

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  late final Stopwatch _stopwatch;
  Timer? _displayTimer;
  late int _selectedSeconds;
  int _plannedSeconds = 1500;
  int _completedSeconds = 0;
  int? _startedAt;
  String? _moodSnapshot;
  bool _running = false;
  bool _complete = false;

  bool get _started => _startedAt != null;
  bool get _hasSavedPreset => widget.preset?.id != null;

  String get _status {
    if (!_started) return 'Ready';
    if (_complete) return 'Session complete';
    if (_running) return 'Running';
    return 'Paused';
  }

  @override
  void initState() {
    super.initState();
    _stopwatch = widget.stopwatch ?? Stopwatch();
    _stopwatch.stop();
    _stopwatch.reset();
    _selectedSeconds = widget.preset?.plannedSeconds ?? 1500;
  }

  int _elapsedSeconds() {
    final seconds = _stopwatch.elapsed.inSeconds;
    if (seconds < 0) return 0;
    if (seconds > _plannedSeconds) return _plannedSeconds;
    return seconds;
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_running) return;
      final seconds = _elapsedSeconds();
      if (seconds >= _plannedSeconds) {
        _stopwatch.stop();
        _displayTimer?.cancel();
        _displayTimer = null;
        setState(() {
          _completedSeconds = _plannedSeconds;
          _running = false;
          _complete = true;
        });
      } else if (seconds != _completedSeconds) {
        setState(() => _completedSeconds = seconds);
      }
    });
  }

  void _start() {
    if (!_hasSavedPreset || _started) return;
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _plannedSeconds = _selectedSeconds;
      _startedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      _moodSnapshot = widget.preset!.moodTag;
      _completedSeconds = 0;
      _running = true;
      _complete = false;
    });
    _startDisplayTimer();
  }

  void _pause() {
    if (!_running) return;
    _stopwatch.stop();
    _displayTimer?.cancel();
    _displayTimer = null;
    final seconds = _elapsedSeconds();
    setState(() {
      _completedSeconds = seconds;
      _running = false;
      _complete = seconds >= _plannedSeconds;
    });
  }

  void _resume() {
    if (!_started || _running || _complete) return;
    _stopwatch.start();
    setState(() => _running = true);
    _startDisplayTimer();
  }

  String _clock(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planned = _started ? _plannedSeconds : _selectedSeconds;
    final remaining = planned - _completedSeconds;
    final labels = MaterialLocalizations.of(context);
    final startedAt = _startedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            _startedAt!,
            isUtc: true,
          ).toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('Focus session')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionHeading(
            title: 'Plan a study block',
            description: !_hasSavedPreset
                ? 'Choose a saved preset before starting a session.'
                : 'Use this preset for your next study block.',
          ),
          Text(widget.preset?.label ?? 'No preset selected.'),
          if (widget.preset != null)
            Text('Mood: ${_moodSnapshot ?? widget.preset!.moodTag}'),
          if (_hasSavedPreset) ...[
            Text('Planned time: ${formatDuration(planned)}'),
            if (!_started) ...[
              const SizedBox(height: 16),
              const Text('Duration for this session'),
              Slider(
                value: _selectedSeconds.toDouble(),
                min: 60,
                max: 7200,
                divisions: 119,
                label: formatDuration(_selectedSeconds),
                semanticFormatterCallback: (value) =>
                    formatDuration(value.round()),
                onChanged: (value) {
                  setState(() => _selectedSeconds = value.round());
                },
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('1 min'), Text('120 min')],
              ),
            ],
          ],
          const SizedBox(height: 24),
          const SectionHeading(title: 'Session'),
          Text(_status),
          if (_hasSavedPreset) ...[
            const SizedBox(height: 12),
            const Text('Remaining time'),
            Semantics(
              label: 'Remaining time: ${formatDuration(remaining)}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _clock(remaining),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
            ),
            Text('Completed: ${formatDuration(_completedSeconds)}'),
          ],
          if (startedAt != null)
            Text(
              'Started: ${labels.formatMediumDate(startedAt)} · '
              '${labels.formatTimeOfDay(TimeOfDay.fromDateTime(startedAt), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
            ),
          const SizedBox(height: 16),
          if (!_started)
            FilledButton(
              onPressed: _hasSavedPreset ? _start : null,
              child: const Text('Start session'),
            )
          else if (_running)
            FilledButton(onPressed: _pause, child: const Text('Pause'))
          else if (!_complete)
            FilledButton(onPressed: _resume, child: const Text('Resume')),
          if (_started) ...[
            const SizedBox(height: 16),
            const Text('This session has not been saved.'),
          ],
        ],
      ),
    );
  }
}
