import 'package:flutter/material.dart';

import '../models/focus_preset.dart';
import 'focus_session_screen.dart';
import 'history_screen.dart';
import 'preset_editor_screen.dart';
import 'presets_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loadPresets, this.loadSummary});

  final Future<List<FocusPreset>> Function()? loadPresets;
  final Future<Map<String, Object?>> Function(String? moodTag)? loadSummary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _savingSettings = false;

  Future<bool> _openPresetEditor([FocusPreset? preset]) async {
    return await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (context) => PresetEditorScreen(preset: preset),
          ),
        ) ??
        false;
  }

  Future<bool> _openFocusSession(FocusPreset preset) async {
    return await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (context) => FocusSessionScreen(preset: preset),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Presets', 'History', 'Settings'];
    final pages = [
      PresetsScreen(
        loadPresets: widget.loadPresets,
        loadSummary: widget.loadSummary,
        onAddPreset: () => _openPresetEditor(),
        onEditPreset: _openPresetEditor,
        onOpenSession: _openFocusSession,
        onOpenHistory: () => setState(() => _selectedIndex = 1),
      ),
      HistoryScreen(onOpenPresets: () => setState(() => _selectedIndex = 0)),
      SettingsScreen(
        onSavingChanged: (saving) => setState(() => _savingSettings = saving),
      ),
    ];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.surface,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.onSurfaceVariant,
          onTap: _savingSettings
              ? null
              : (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
          elevation: 0,
          selectedFontSize: 13,
          unselectedFontSize: 13,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmarks_outlined),
              label: 'Presets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
