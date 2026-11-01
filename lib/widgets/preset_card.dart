import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import 'display_widgets.dart';

class PresetCard extends StatelessWidget {
  const PresetCard({super.key, required this.preset, required this.onOpen});

  final FocusPreset preset;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preset.label, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text('Mood: ${preset.moodTag}'),
            Text('Planned time: ${formatDuration(preset.plannedSeconds)}'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpen,
              child: const Text('Open session'),
            ),
          ],
        ),
      ),
    );
  }
}
