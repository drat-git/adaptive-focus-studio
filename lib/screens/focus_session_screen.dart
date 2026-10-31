import 'package:flutter/material.dart';

import '../widgets/display_widgets.dart';

class FocusSessionScreen extends StatelessWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus session')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SectionHeading(
            title: 'Plan a study block',
            description: 'Choose a saved preset before starting a session.',
          ),
          Text('No preset selected.'),
          SizedBox(height: 24),
          SectionHeading(title: 'Session'),
          Text('No session is running.'),
          SizedBox(height: 16),
          FilledButton(onPressed: null, child: Text('Start session')),
          SizedBox(height: 24),
          SectionHeading(title: 'Session receipt'),
          Text('A saved session shows its planned and completed time.'),
        ],
      ),
    );
  }
}
