import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import '../widgets/display_widgets.dart';

class FocusSessionScreen extends StatelessWidget {
  const FocusSessionScreen({super.key, this.preset});

  final FocusPreset? preset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus session')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionHeading(
            title: 'Plan a study block',
            description: preset == null
                ? 'Choose a saved preset before starting a session.'
                : 'Use this preset for your next study block.',
          ),
          Text(preset?.label ?? 'No preset selected.'),
          if (preset != null) Text('Mood: ${preset!.moodTag}'),
          if (preset != null)
            Text('Planned time: ${formatDuration(preset!.plannedSeconds)}'),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Session'),
          const Text('No session is running.'),
          const SizedBox(height: 16),
          const FilledButton(onPressed: null, child: Text('Start session')),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Session receipt'),
          const Text('A saved session shows its planned and completed time.'),
        ],
      ),
    );
  }
}
