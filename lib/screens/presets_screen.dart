import 'package:flutter/material.dart';

import '../widgets/display_widgets.dart';

class PresetsScreen extends StatelessWidget {
  const PresetsScreen({
    super.key,
    required this.onAddPreset,
    required this.onOpenSession,
  });

  final VoidCallback onAddPreset;
  final VoidCallback onOpenSession;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionHeading(
          title: 'Study presets',
          description: 'Choose a mood and duration for your next study block.',
        ),
        const Text('Your presets will appear here.'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAddPreset,
          icon: const Icon(Icons.add),
          label: const Text('Add preset'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onOpenSession,
          child: const Text('View focus session'),
        ),
      ],
    );
  }
}
