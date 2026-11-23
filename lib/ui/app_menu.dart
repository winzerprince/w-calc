import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'graph/graph_page.dart';
import 'haptics.dart';
import 'pages/about_page.dart';
import 'pages/manual_page.dart';
import 'pages/model_page.dart';
import 'pages/settings_page.dart';
import 'pages/theme_page.dart';

/// One entry of the W-Calc menu. Entries that are not [ready] are shown but
/// marked "Soon" (visible constraint) and explain themselves when tapped.
class MenuEntry {
  const MenuEntry(this.icon, this.title, this.subtitle, {this.page});

  final IconData icon;
  final String title;
  final String subtitle;

  /// Builds the page opened by this entry (gets the reset action).
  final Widget Function(VoidCallback onReset)? page;

  bool get ready => page != null;
}

final menuEntries = [
  MenuEntry(
    Icons.show_chart,
    'Graph',
    'Plot functions, trace points, find roots',
    page: (_) => const GraphPage(),
  ),
  MenuEntry(
    Icons.tune,
    'Settings',
    'Vibration, sound, model, theme, reset',
    page: (onReset) => SettingsPage(onResetCalculator: onReset),
  ),
  MenuEntry(
    Icons.calculate_outlined,
    'Calculator model',
    'Two-line or textbook display, five bodies',
    page: (_) => const ModelPage(),
  ),
  MenuEntry(
    Icons.palette_outlined,
    'Theme',
    'Classic, Midnight, High contrast, Ivory',
    page: (_) => const ThemePage(),
  ),
  MenuEntry(
    Icons.menu_book_outlined,
    'Manual',
    'Searchable how-to for every mode of your model',
    page: (_) => const ManualPage(),
  ),
  MenuEntry(
    Icons.info_outline,
    'About W-Calc',
    'Version, licence and credits',
    page: (_) => const AboutPage(),
  ),
];

/// Opens the full-screen menu over the calculator.
Future<void> showAppMenu(BuildContext context, {VoidCallback? onReset}) {
  keyVibration();
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Close menu',
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => AppMenu(onReset: onReset ?? () {}),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Semi-transparent black menu: white text, calculator faintly visible behind.
class AppMenu extends StatefulWidget {
  const AppMenu({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  State<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends State<AppMenu> {
  String? _notice;

  void _close() {
    keyVibration();
    Navigator.of(context).pop();
  }

  void _open(MenuEntry entry) {
    keyVibration();
    final page = entry.page;
    if (!entry.ready || page == null) {
      setState(() => _notice = '${entry.title} is coming in a later update.');
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page(widget.onReset)));
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Material(
          key: const Key('app-menu'),
          color: Colors.black.withValues(alpha: 0.86),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'W-Calc',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('app-menu-close'),
                            onPressed: _close,
                            tooltip: 'Close menu',
                            iconSize: 28,
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              side: const BorderSide(color: Colors.white38),
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (final entry in menuEntries)
                            _MenuTile(entry: entry, onTap: () => _open(entry)),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _notice == null
                          ? const SizedBox(height: 56)
                          : Container(
                              key: ValueKey(_notice),
                              height: 56,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _notice!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry, required this.onTap});

  final MenuEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dim = entry.ready ? 1.0 : 0.7;
    return Semantics(
      button: true,
      label: '${entry.title}${entry.ready ? '' : ', coming soon'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                entry.icon,
                color: Colors.white.withValues(alpha: dim),
                size: 26,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: dim),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!entry.ready)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
