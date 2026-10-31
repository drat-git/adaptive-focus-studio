import 'package:flutter/material.dart';

import '../widgets/display_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SectionHeading(
          title: 'Default duration',
          description: 'Used when creating a new preset.',
        ),
        Text('Existing presets and active sessions keep their own duration.'),
        SizedBox(height: 24),
        SectionHeading(
          title: 'Reduce motion',
          description: 'Use less movement when session status changes.',
        ),
        Text('The app works in silence.'),
      ],
    );
  }
}
