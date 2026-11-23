import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../haptics.dart';
import 'page_scaffold.dart';
import 'theme_page.dart';

/// Feedback, appearance and reset.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onResetCalculator});

  /// Clears memories, data, setup and history (like CLR All).
  final VoidCallback onResetCalculator;

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset calculator?'),
        content: const Text(
          'This clears all memories, variables, statistics data, matrices and '
          'vectors, and returns every setup option to its default. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-reset'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB4505A),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      onResetCalculator();
      keyVibration();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculator reset to factory settings.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return MenuPageScaffold(
      title: 'Settings',
      children: [
        const PageSection('Key feedback'),
        SwitchListTile(
          key: const Key('setting-vibration'),
          secondary: const Icon(Icons.vibration),
          title: const Text('Vibrate on key press'),
          subtitle: const Text(
            'A short buzz like a real key. On Android it also needs system touch feedback.',
          ),
          value: settings.vibration,
          onChanged: (v) {
            settings.update(vibration: v);
            if (v) keyVibration();
          },
        ),
        SwitchListTile(
          key: const Key('setting-sound'),
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('Click sound'),
          subtitle: const Text('Plays the system click (Android).'),
          value: settings.keySound,
          onChanged: (v) => settings.update(keySound: v),
        ),
        const PageSection('Appearance'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          subtitle: Text(themeName(settings.skinId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ThemePage()),
          ),
        ),
        const PageSection('Calculator'),
        ListTile(
          key: const Key('setting-reset'),
          leading: const Icon(Icons.restart_alt, color: Color(0xFFFF8A8A)),
          title: const Text(
            'Reset calculator',
            style: TextStyle(color: Color(0xFFFF8A8A)),
          ),
          subtitle: const Text('Clear all memories, data and setup'),
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }
}
