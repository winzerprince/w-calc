import 'package:flutter/material.dart';

import 'page_scaffold.dart';

/// Physical keyboard shortcuts (see keyboard_shortcuts.dart).
const keyboardShortcuts = [
  ('0 – 9  .  ,', 'Digits and decimal point'),
  ('+  −  *  /', 'Add, subtract, multiply, divide'),
  ('( )', 'Parentheses'),
  ('^', 'Power'),
  ('Enter  or  =', '='),
  ('Backspace', 'DEL'),
  ('Esc  or  Delete', 'AC'),
  ('← → ↑ ↓', 'Cursor and REPLAY'),
  ('s', 'SHIFT'),
  ('a', 'ALPHA'),
  ('h', 'hyp'),
  ('m', 'MODE'),
  ('n', '(−) negative sign'),
  ('e', 'EXP'),
];

class ShortcutsPage extends StatelessWidget {
  const ShortcutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Keyboard shortcuts',
      children: [
        const PageText(
          'When using W-Calc in a browser or with a keyboard attached:',
        ),
        for (final (keys, action) in keyboardShortcuts)
          ListTile(
            dense: true,
            leading: Container(
              constraints: const BoxConstraints(minWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white38),
              ),
              child: Text(
                keys,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(action),
          ),
      ],
    );
  }
}
