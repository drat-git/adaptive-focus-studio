import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import 'display_widgets.dart';

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.onOpen,
    required this.onEdit,
  });

  final FocusPreset preset;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onEdit,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              Text('Mood: ${preset.moodTag}'),
              Text('Planned time: ${formatDuration(preset.plannedSeconds)}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Open session'),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
