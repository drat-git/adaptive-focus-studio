import 'package:flutter/material.dart';

import '../widgets/display_widgets.dart';

class PresetEditorScreen extends StatelessWidget {
  const PresetEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New preset')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionHeading(
            title: 'Preset details',
            description: 'A label, mood, and duration describe a study block.',
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Label'),
            subtitle: Text('A short name for the study block.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Mood'),
            subtitle: Text('Calm, Focused, or Low energy.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Planned duration'),
            subtitle: Text('The length of this study block.'),
          ),
          const SizedBox(height: 24),
          const FilledButton(onPressed: null, child: Text('Save preset')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
