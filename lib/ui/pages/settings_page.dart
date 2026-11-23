import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../haptics.dart';
import 'page_scaffold.dart';
import '../tour/tours.dart';
import 'manual_page.dart';
import 'model_page.dart';
import 'theme_page.dart';
import '../soft_route.dart';

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
            'A short buzz like a real key. Works even when system touch feedback is off.',
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
        const PageSection('App appearance'),
        const PageText(
          'Menus and pages only. The calculator keeps its own theme '
          '(Calculator look below).',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<String>(
            key: const Key('setting-appearance'),
            segments: const [
              ButtonSegment(
                value: 'system',
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('System'),
              ),
              ButtonSegment(
                value: 'light',
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: 'dark',
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {settings.appearance},
            onSelectionChanged: (s) {
              keyVibration();
              settings.update(appearance: s.first);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: const Text('Text size'),
          subtitle: Slider(
            key: const Key('setting-text-size'),
            min: 0.85,
            max: 1.5,
            divisions: 13,
            value: settings.textScale,
            label: '${(settings.textScale * 100).round()} %',
            onChanged: (v) => settings.update(textScale: v),
          ),
          trailing: Text('${(settings.textScale * 100).round()} %'),
        ),
        const PageSection('Calculator look'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          subtitle: Text(themeName(settings.skinId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            SoftRoute<void>(builder: (_) => const ThemePage()),
          ),
        ),
        const PageSection('Help'),
        ListTile(
          key: const Key('tour-calculator'),
          leading: const Icon(Icons.gesture),
          title: const Text('Calculator tour'),
          subtitle: const Text('What the display and main keys do'),
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            calculatorTourRequest.value++;
          },
        ),
        ListTile(
          key: const Key('tour-models'),
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('Models tour'),
          onTap: () => Navigator.push(
            context,
            SoftRoute<void>(builder: (_) => const ModelPage(startTour: true)),
          ),
        ),
        ListTile(
          key: const Key('tour-theme'),
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme tour'),
          onTap: () => Navigator.push(
            context,
            SoftRoute<void>(builder: (_) => const ThemePage(startTour: true)),
          ),
        ),
        ListTile(
          key: const Key('tour-manual'),
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('Manual tour'),
          onTap: () => Navigator.push(
            context,
            SoftRoute<void>(builder: (_) => const ManualPage(startTour: true)),
          ),
        ),
        const PageSection('Calculator'),
        ListTile(
          key: const Key('setting-model'),
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('Calculator model'),
          subtitle: Text(modelName(settings.modelId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            SoftRoute<void>(builder: (_) => const ModelPage()),
          ),
        ),
        ListTile(
          key: const Key('setting-reset'),
          leading: Icon(
            Icons.restart_alt,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Reset calculator',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: const Text('Clear all memories, data and setup'),
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }
}
