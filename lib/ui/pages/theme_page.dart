import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../haptics.dart';
import '../finish.dart';
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
        const PageSection('Finish'),
        RadioGroup<String>(
          groupValue: settings.finishId,
          onChanged: (id) {
            if (id == null) return;
            keyVibration();
            settings.update(finishId: id);
          },
          child: Column(
            children: [
              for (final f in CalcFinish.values)
                RadioListTile<String>(
                  key: Key('finish-${f.name}'),
                  value: f.name,
                  title: Text(
                    f.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(f.description),
                  secondary: _FinishPreview(finish: f),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two sample keys in the current skin with [finish].
class _FinishPreview extends StatelessWidget {
  const _FinishPreview({required this.finish});

  final CalcFinish finish;

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    Widget key(Color c) => Container(
      width: 22,
      height: 16,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(finish.keyRadius(4)),
        gradient: finish.keyGradient(c, down: false),
        border: finish.keyBorder(c),
        boxShadow: finish.keyShadow(down: false),
      ),
      foregroundDecoration: finish.keySheen() == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(finish.keyRadius(4)),
              gradient: finish.keySheen(),
            ),
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: finish.bodyFace(skin, BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [key(skin.functionKey), key(skin.digitKey)],
        ),
      ),
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
