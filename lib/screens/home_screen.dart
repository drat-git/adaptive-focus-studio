import 'package:flutter/material.dart';

import 'focus_session_screen.dart';
import 'history_screen.dart';
import 'preset_editor_screen.dart';
import 'presets_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _openPresetEditor() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const PresetEditorScreen()),
    );
  }

  void _openFocusSession() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const FocusSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Presets', 'History', 'Settings'];
    final pages = [
      PresetsScreen(
        onAddPreset: _openPresetEditor,
        onOpenSession: _openFocusSession,
      ),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmarks_outlined),
            label: 'Presets',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
