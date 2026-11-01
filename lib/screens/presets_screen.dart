import 'package:flutter/material.dart';

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
  });

  final Future<bool> Function() onAddPreset;
  final Future<bool> Function(FocusPreset) onEditPreset;
  final void Function(FocusPreset) onOpenSession;
  final Future<List<FocusPreset>> Function()? loadPresets;

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  late Future<List<FocusPreset>> _presets;
  String _mood = 'All moods';

  @override
  void initState() {
    super.initState();
    _presets = _loadPresets();
  }

  Future<List<FocusPreset>> _loadPresets() {
    final loader = widget.loadPresets ?? DatabaseHelper.instance.getPresets;
    return loader();
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
            if (allPresets.isEmpty) {
              return const Text(
                'Add your first preset to set up a study block.',
              );
            }
            final visible = allPresets.where((preset) {
              return _mood == 'All moods' || preset.moodTag == _mood;
            }).toList();
            if (visible.isEmpty) {
              return const Text('No presets match this mood.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: visible.map((preset) {
                return PresetCard(
                  preset: preset,
                  onOpen: () => widget.onOpenSession(preset),
                  onEdit: () => _editPreset(preset),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
