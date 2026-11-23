import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../haptics.dart';
import '../skin.dart';
import 'page_scaffold.dart';

String themeName(String id) => CalcSkin.byId(id).name;

/// Pick a skin; each row previews its body, keys and LCD colours.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return MenuPageScaffold(
      title: 'Theme',
      children: [
        const PageText(
          'Changes apply immediately. Layout and behaviour stay the same.',
        ),
        RadioGroup<String>(
          groupValue: settings.skinId,
          onChanged: (id) {
            if (id == null) return;
            keyVibration();
            settings.update(skinId: id);
          },
          child: Column(
            children: [
              for (final skin in CalcSkin.all)
                RadioListTile<String>(
                  key: Key('theme-${skin.id}'),
                  value: skin.id,
                  title: Text(
                    skin.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(skin.description),
                  secondary: _SkinPreview(skin: skin),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkinPreview extends StatelessWidget {
  const _SkinPreview({required this.skin});

  final CalcSkin skin;

  @override
  Widget build(BuildContext context) {
    Widget key(Color c) => Container(
      width: 9,
      height: 7,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: skin.body,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: skin.lcd.glass,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                '0.',
                style: TextStyle(color: skin.lcd.ink, fontSize: 9, height: 1),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                key(skin.functionKey),
                key(skin.functionKey),
                key(skin.functionKey),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                key(skin.digitKey),
                key(skin.digitKey),
                key(skin.clearKey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
