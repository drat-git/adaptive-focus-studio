import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/settings_store.dart';
import '../helpers/session_scout.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/display_widgets.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({
    super.key,
    this.preset,
    this.stopwatch,
    this.saveLog,
    this.loadLogs,
    this.loadReduceMotion,
  });

  final FocusPreset? preset;
  final Stopwatch? stopwatch;
  final Future<int> Function(SessionLog)? saveLog;
  final Future<List<SessionLog>> Function()? loadLogs;
  final Future<bool> Function()? loadReduceMotion;

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen>
    with WidgetsBindingObserver {
  late final Stopwatch _stopwatch;
  Timer? _displayTimer;
  late int _selectedSeconds;
  int _plannedSeconds = 1500;
  int _completedSeconds = 0;
  int? _startedAt;
  int? _presetIdSnapshot;
  String? _moodSnapshot;
  bool _running = false;
  bool _complete = false;
  bool _saving = false;
  bool _confirmingDiscard = false;
  SessionLog? _receipt;
  int? _savedLogId;
  String? _saveError;
  SessionScoutResult? _scout;
  bool _scoutLoading = false;
  bool _scoutDismissed = false;
  String? _scoutError;
  String? _scoutMessage;
  int _scoutReadNumber = 0;
  bool _reduceMotion = true;

  bool get _started => _startedAt != null;
  bool get _hasSavedPreset => widget.preset?.id != null;

  String get _status {
    if (_saving) return 'Saving session…';
    if (_savedLogId != null) return 'Session saved';
    if (_saveError != null) return 'Save failed';
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
    WidgetsBinding.instance.addObserver(this);
    _loadScout();
    _loadMotion();
  }

  Future<void> _loadMotion() async {
    try {
      final loader = widget.loadReduceMotion ?? SettingsStore().getReduceMotion;
      final reduceMotion = await loader();
      if (mounted) setState(() => _reduceMotion = reduceMotion);
    } catch (_) {
      // Keep the status still if the preference cannot be read.
    }
  }

  @override
  void didUpdateWidget(covariant FocusSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_started) return;
    final changedPreset = oldWidget.preset?.id != widget.preset?.id;
    if (changedPreset ||
        oldWidget.preset?.plannedSeconds != widget.preset?.plannedSeconds) {
      _selectedSeconds = widget.preset?.plannedSeconds ?? 1500;
    }
    if (changedPreset ||
        oldWidget.preset?.moodTag != widget.preset?.moodTag ||
        oldWidget.loadLogs != widget.loadLogs) {
      _loadScout();
    }
  }

  Future<void> _loadScout() async {
    if (_started) return;
    final readNumber = ++_scoutReadNumber;
    final mood = widget.preset?.moodTag ?? '';
    setState(() {
      _scoutLoading = true;
      _scoutError = null;
      _scoutMessage = null;
      _scoutDismissed = false;
    });
    try {
      final loader = widget.loadLogs ?? DatabaseHelper.instance.getSessionLogs;
      final logs = _hasSavedPreset ? await loader() : <SessionLog>[];
      final result = calculateSessionScout(logs: logs, moodTag: mood);
      if (!mounted || readNumber != _scoutReadNumber || _started) return;
      setState(() {
        _scout = result;
        _scoutLoading = false;
      });
    } catch (_) {
      if (!mounted || readNumber != _scoutReadNumber || _started) return;
      setState(() {
        _scoutLoading = false;
        _scoutError = 'Could not load Session Scout history. You can still choose a duration and start.';
      });
    }
  }

  void _applyScout() {
    final scout = _scout;
    if (_started ||
        !_hasSavedPreset ||
        _scoutLoading ||
        _scoutDismissed ||
        scout?.state != SessionScoutState.ready) {
      return;
    }
    final seconds = scout!.suggestedSeconds!;
    setState(() {
      _selectedSeconds = seconds;
      _scoutMessage =
          'Duration set to ${formatDuration(seconds)}. Start when ready.';
    });
  }

  Widget _scoutCard() {
    final scout = _scout;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Scout', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_scoutLoading)
            const Text('Loading recent history…')
          else if (_scoutError != null) ...[
            Text(_scoutError!),
            TextButton(onPressed: _loadScout, child: const Text('Try again')),
          ] else if (scout != null) ...[
            if (!_hasSavedPreset)
              const Text(
                'Choose a saved preset with a valid mood to use Session Scout.',
              )
            else ...[
              if (scout.state == SessionScoutState.ready)
                Text(
                  'Suggested duration: ${formatDuration(scout.suggestedSeconds!)}',
                ),
              Text(scout.explanation),
              if (scout.warning != null) Text(scout.warning!),
            ],
            Text('Fixed baseline: ${formatDuration(scout.baselineSeconds)}'),
            if (_scoutMessage != null) Text(_scoutMessage!),
          ],
          Wrap(
            spacing: 8,
            children: [
              if (!_scoutLoading &&
                  _scoutError == null &&
                  scout?.state == SessionScoutState.ready &&
                  _hasSavedPreset)
                OutlinedButton(
                  onPressed: _applyScout,
                  child: const Text('Apply'),
                ),
              TextButton(
                onPressed: () {
                  if (!_started) setState(() => _scoutDismissed = true);
                },
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
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
        _finish();
      } else if (seconds != _completedSeconds) {
        setState(() => _completedSeconds = seconds);
      }
    });
  }

  void _start() {
    if (!_hasSavedPreset || _started || _saving || _confirmingDiscard) return;
    _scoutReadNumber++;
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _plannedSeconds = _selectedSeconds;
      _startedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      _presetIdSnapshot = widget.preset!.id;
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
    if (_complete) _finish();
  }

  void _resume() {
    if (!_started ||
        _running ||
        _complete ||
        _receipt != null ||
        _saving ||
        _confirmingDiscard) {
      return;
    }
    _stopwatch.start();
    setState(() => _running = true);
    _startDisplayTimer();
  }

  Future<void> _finish() async {
    if (!_started || _saving || _savedLogId != null || _confirmingDiscard) {
      return;
    }
    _stopwatch.stop();
    _displayTimer?.cancel();
    _displayTimer = null;
    final receipt =
        _receipt ??
        SessionLog(
          presetId: _presetIdSnapshot!,
          startedAt: _startedAt!,
          plannedSecondsSnapshot: _plannedSeconds,
          completedSeconds: _elapsedSeconds(),
          moodTagSnapshot: _moodSnapshot!,
          status: 'finished',
          source: 'timer',
        );
    setState(() {
      _receipt = receipt;
      _completedSeconds = receipt.completedSeconds;
      _running = false;
      _complete = true;
      _saving = true;
      _saveError = null;
    });
    try {
      final saver = widget.saveLog ?? DatabaseHelper.instance.insertSessionLog;
      final id = await saver(receipt);
      if (id <= 0) throw StateError('The session was not saved.');
      if (!mounted) return;
      setState(() {
        _savedLogId = id;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save this session. Your receipt is still here. Retry save or discard it.';
      });
    }
  }

  Future<bool> _confirmDiscard({required bool resetting}) async {
    setState(() => _confirmingDiscard = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          resetting ? 'Reset this session?' : 'Discard this session?',
        ),
        content: const Text(
          'Unsaved progress will be discarded. Saved history stays unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(resetting ? 'Reset' : 'Discard'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    setState(() => _confirmingDiscard = false);
    return confirmed == true;
  }

  Future<void> _requestReset() async {
    if (!_started || _saving || _savedLogId != null || _confirmingDiscard) {
      return;
    }
    _pause();
    if (_saving || _savedLogId != null) return;
    final reset = await _confirmDiscard(resetting: true);
    if (!mounted || !reset) return;
    _stopwatch.reset();
    setState(() {
      _completedSeconds = 0;
      _startedAt = null;
      _presetIdSnapshot = null;
      _moodSnapshot = null;
      _running = false;
      _complete = false;
      _receipt = null;
      _savedLogId = null;
      _saveError = null;
    });
    _loadScout();
  }

  Future<void> _requestClose() async {
    if (_saving || _confirmingDiscard) return;
    if (_started && _savedLogId == null) {
      _pause();
      if (_saving) return;
      if (_savedLogId == null) {
        final discard = await _confirmDiscard(resetting: false);
        if (!mounted || !discard) return;
      }
    }
    if (mounted) Navigator.pop(context, _savedLogId != null);
  }

  Widget _controls() {
    if (!_started) {
      return FilledButton(
        onPressed: _hasSavedPreset ? _start : null,
        child: const Text('Start session'),
      );
    }
    if (_savedLogId != null) {
      return FilledButton(
        onPressed: _requestClose,
        child: const Text('Return to presets'),
      );
    }
    if (_saving) {
      return const Wrap(
        spacing: 8,
        children: [
          FilledButton(onPressed: null, child: Text('Saving…')),
          OutlinedButton(onPressed: null, child: Text('Reset')),
        ],
      );
    }
    if (_receipt != null) {
      return Wrap(
        spacing: 8,
        children: [
          FilledButton(onPressed: _finish, child: const Text('Retry save')),
          OutlinedButton(
            onPressed: _requestReset,
            child: const Text('Discard'),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: _confirmingDiscard ? null : (_running ? _pause : _resume),
          child: Text(_running ? 'Pause' : 'Resume'),
        ),
        OutlinedButton(
          onPressed: _confirmingDiscard ? null : _finish,
          child: const Text('Finish'),
        ),
        OutlinedButton(
          onPressed: _confirmingDiscard ? null : _requestReset,
          child: const Text('Reset'),
        ),
      ],
    );
  }

  String _clock(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayTimer?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final still = _reduceMotion || MediaQuery.disableAnimationsOf(context);
    final planned = _started ? _plannedSeconds : _selectedSeconds;
    final remaining = planned - _completedSeconds;
    final labels = MaterialLocalizations.of(context);
    final startedAt = _startedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            _startedAt!,
            isUtc: true,
          ).toLocal();
    return PopScope<bool>(
      canPop: !_saving && !_started,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Focus session'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving || _confirmingDiscard ? null : _requestClose,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionHeading(
              title: 'Plan a study block',
              description: !_hasSavedPreset
                  ? 'Choose a saved preset before starting a session.'
                  : 'Use this preset for your next study block.',
            ),
            Text(
              widget.preset?.label ?? 'No preset selected.',
              style: theme.textTheme.headlineSmall,
            ),
            if (widget.preset != null)
              Text('Mood: ${_moodSnapshot ?? widget.preset!.moodTag}'),
            if (_hasSavedPreset && _receipt == null) ...[
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
                    setState(() {
                      _selectedSeconds = value.round();
                      _scoutMessage = null;
                    });
                  },
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('1 min'), Text('120 min')],
                ),
              ],
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Session', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      liveRegion: true,
                      child: AnimatedContainer(
                        key: const Key('session-status'),
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _running ? colors.primary : colors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _status,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _running ? colors.onPrimary : colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hasSavedPreset && _receipt == null) ...[
                    const SizedBox(height: 20),
                    const Text('Remaining time'),
                    Semantics(
                      label: 'Remaining time: ${formatDuration(remaining)}',
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _clock(remaining),
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -2,
                          ),
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
                  const SizedBox(height: 20),
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _saveError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  _controls(),
                ],
              ),
            ),
            if (!_started && !_scoutDismissed) ...[
              const SizedBox(height: 16),
              _scoutCard(),
            ],
            if (_receipt != null) ...[
              const SizedBox(height: 24),
              const SectionHeading(title: 'Session receipt'),
              Text(
                _savedLogId == null
                    ? 'Not saved yet.'
                    : 'Saved entry #$_savedLogId',
              ),
              Text(
                'Planned: ${formatDuration(_receipt!.plannedSecondsSnapshot)}',
              ),
              Text('Completed: ${formatDuration(_receipt!.completedSeconds)}'),
              Text('Mood: ${_receipt!.moodTagSnapshot}'),
              const Text('Source: Measured timer'),
              const Text('Finished'),
            ] else if (_started) ...[
              const SizedBox(height: 16),
              const Text('This session has not been saved.'),
            ],
          ],
        ),
      ),
    );
  }
}
