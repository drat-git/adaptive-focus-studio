import 'package:flutter/material.dart';

import '../widgets/display_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SectionHeading(
          title: 'Session history',
          description: 'Review planned and completed study time.',
        ),
        Text('Session records will appear here.'),
      ],
    );
  }
}
