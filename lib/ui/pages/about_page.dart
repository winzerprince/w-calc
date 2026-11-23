import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/links.dart';
import 'page_scaffold.dart';

/// Product information: version, purpose, independence and legal notices.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'About W-Calc',
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Text(
            'W-Calc',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        PageText('Scientific calculator · Version $appVersion'),
        const PageText(
          'Practise with the calculator you use in class: familiar keys, '
          'displays and results, on your phone.',
        ),
        const PageSection('Notice'),
        const PageText(
          'W-Calc is an independent product and is not affiliated with, '
          'endorsed by or sponsored by any calculator manufacturer. Most '
          'examinations do not allow phones; use an approved calculator there.',
        ),
        const PageSection('Privacy'),
        const PageText(
          'W-Calc collects no data. It works offline; settings, memories and '
          'graphs stay on this device.',
        ),
        const PageSection('Legal'),
        const PageText(
          '© 2026 winzerprince. Free and open source under the MIT licence.',
        ),
        ListTile(
          key: const Key('about-source'),
          leading: const Icon(Icons.code),
          title: const Text('Source code'),
          subtitle: const Text('github.com/winzerprince/w-calc'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openLink(sourceUrl),
        ),
        ListTile(
          key: const Key('about-kofi'),
          leading: const Icon(Icons.coffee_outlined),
          title: const Text('Buy me a coffee'),
          subtitle: const Text('Support W-Calc on Ko-fi'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openLink(kofiUrl),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Third-party licences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'W-Calc',
            applicationVersion: appVersion,
            applicationLegalese: '© 2026 winzerprince. MIT licence.',
          ),
        ),
      ],
    );
  }
}
