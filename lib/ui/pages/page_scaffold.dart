import 'package:flutter/material.dart';

/// Shared look for menu pages: the menu's black, white text, back arrow.
class MenuPageScaffold extends StatelessWidget {
  const MenuPageScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0D),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Barlow'),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0D),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading inside a menu page.
class PageSection extends StatelessWidget {
  const PageSection(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Paragraph text inside a menu page.
class PageText extends StatelessWidget {
  const PageText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
    ),
  );
}
