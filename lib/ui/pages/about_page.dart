import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import 'page_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'About W-Calc',
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Text(
            'W-Calc',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        const PageText('Two-line scientific calculator for students.'),
        PageText('Version $appVersion'),
        const PageSection('Independence'),
        const PageText(
          'W-Calc is keystroke-compatible with classic two-line scientific calculators. '
          'It is an independent project and is not affiliated with or endorsed by any '
          'calculator manufacturer. All calculation code is original.',
        ),
        const PageSection('Accuracy'),
        const PageText(
          'Calculations use 15 significant digits internally (24 during functions) and show '
          '10, like the calculators it follows. Results are checked against a high-precision '
          'reference library.',
        ),
        const PageSection('Exams'),
        const PageText(
          'Phones are not allowed in most exams. Use W-Calc to learn and practise; take your '
          'own approved calculator into the exam room.',
        ),
        const PageSection('Licence'),
        const PageText(
          '© 2026 winzerprince. All rights reserved. '
          'Fonts: Barlow (SIL Open Font License 1.1) and a subset of Noto Sans Math (SIL OFL 1.1); '
          'Flutter and Dart packages under their own licences.',
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Third-party licences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'W-Calc',
            applicationVersion: appVersion,
            applicationLegalese: '© 2026 winzerprince. All rights reserved.',
          ),
        ),
      ],
    );
  }
}
