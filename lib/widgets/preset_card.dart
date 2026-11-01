import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import 'display_widgets.dart';

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final FocusPreset preset;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = preset.moodTag == 'Calm'
        ? theme.colorScheme.primary
        : preset.moodTag == 'Focused'
        ? const Color(0xFFA9443D)
        : const Color(0xFF8B3441);

    return GestureDetector(
      onLongPress: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            left: BorderSide(color: accent, width: 4),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preset.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Mood: ${preset.moodTag}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text(
              'Planned time: ${formatDuration(preset.plannedSeconds)}',
              style: theme.textTheme.titleLarge?.copyWith(color: accent),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  onPressed: onOpen,
                  child: const Text('Open session'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
