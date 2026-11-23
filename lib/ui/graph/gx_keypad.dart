import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../haptics.dart';
import 'gx_view.dart';

/// A change to the focused expression.
typedef GxEdit = void Function(GxEditor e);

/// One key: its label (plain text or typeset maths) and what it does.
class _K {
  const _K(
    this.label, {
    this.math,
    this.edit,
    this.action,
    this.flex = 1,
    this.tone = _Tone.plain,
    this.id,
  });

  final String label;

  /// Label as maths (saved text form), when it reads better typeset.
  final String? math;
  final GxEdit? edit;
  final String? action;
  final double flex;
  final _Tone tone;
  final String? id;
}

enum _Tone { plain, number, dark, accent }

_K _t(String s, {String? label, _Tone tone = _Tone.plain, String? math}) =>
    _K(label ?? s, math: math, edit: (e) => e.type(s), tone: tone, id: s);

_K _n(String s) => _t(s, tone: _Tone.number);

/// The graph keypad: maths keys, digits, a letters page and a functions
/// panel. Calls [onEdit] for edits and [onEnter] for ↵.
class GxKeypad extends StatefulWidget {
  const GxKeypad({
    super.key,
    required this.onEdit,
    required this.onEnter,
    this.onKey,
  });

  /// Every key's id after it is handled (first-use hints).
  final ValueChanged<String>? onKey;

  final ValueChanged<GxEdit> onEdit;
  final VoidCallback onEnter;

  @override
  State<GxKeypad> createState() => _GxKeypadState();
}

class _GxKeypadState extends State<GxKeypad> {
  bool _letters = false;
  bool _shift = false;
  bool _funcs = false;

  static final _main = [
    [
      _t('x', math: 'x'),
      _t('y', math: 'y'),
      _K(
        'a²',
        math: 'a^{2}',
        id: 'square',
        edit: (e) => e
          ..box(GxKind.pow)
          ..type('2')
          ..right(),
      ),
      _K('aᵇ', math: 'a^{b}', id: 'pow', edit: (e) => e.box(GxKind.pow)),
      null,
      _n('7'),
      _n('8'),
      _n('9'),
      _K(
        '÷',
        id: 'divide',
        edit: (e) => e.box(GxKind.frac),
        tone: _Tone.number,
      ),
      null,
      const _K('funcs', action: 'funcs', tone: _Tone.dark, flex: 1.6),
    ],
    [
      _t('('),
      _t(')'),
      _t('<'),
      _t('>'),
      null,
      _n('4'),
      _n('5'),
      _n('6'),
      _K('×', id: 'times', edit: (e) => e.type('×'), tone: _Tone.number),
      null,
      _K('←', id: 'left', edit: (e) => e.left(), tone: _Tone.dark, flex: 0.8),
      _K('→', id: 'right', edit: (e) => e.right(), tone: _Tone.dark, flex: 0.8),
    ],
    [
      _K('|a|', math: r'\abs{a}', id: 'abs', edit: (e) => e.box(GxKind.abs)),
      _t(','),
      _t('≤'),
      _t('≥'),
      null,
      _n('1'),
      _n('2'),
      _n('3'),
      _K('−', id: 'minus', edit: (e) => e.type('-'), tone: _Tone.number),
      null,
      _K(
        '⌫',
        id: 'back',
        edit: (e) => e.backspace(),
        tone: _Tone.dark,
        flex: 1.6,
      ),
    ],
    [
      const _K('ABC', action: 'abc', tone: _Tone.dark),
      _K('√', math: r'\sqrt{}', id: 'sqrt', edit: (e) => e.box(GxKind.sqrt)),
      _t('π', math: r'\pi '),
      _t('e', math: 'e'),
      null,
      _n('0'),
      _n('.'),
      _t('=', tone: _Tone.number),
      _K('+', id: 'plus', edit: (e) => e.type('+'), tone: _Tone.number),
      null,
      const _K('↵', action: 'enter', tone: _Tone.accent, flex: 1.6),
    ],
  ];

  List<List<_K?>> _alpha() {
    _K l(String c) {
      final s = _shift ? c.toUpperCase() : c;
      return _K(
        s,
        math: s,
        id: 'letter-$c',
        edit: (e) {
          e.type(s);
          if (_shift) setState(() => _shift = false);
        },
      );
    }

    return [
      [for (final c in 'qwertyuiop'.split('')) l(c)],
      [for (final c in 'asdfghjkl'.split('')) l(c), _t('θ', math: r'\theta ')],
      [
        _K('⇧', action: 'shift', tone: _shift ? _Tone.accent : _Tone.dark),
        for (final c in 'zxcvbnm'.split('')) l(c),
        _K(
          '⌫',
          id: 'back',
          edit: (e) => e.backspace(),
          tone: _Tone.dark,
          flex: 2,
        ),
      ],
      [
        const _K('123', action: 'abc', tone: _Tone.dark, flex: 1.6),
        _K('aₙ', math: 'a_{n}', id: 'sub', edit: (e) => e.box(GxKind.sub)),
        _t('!'),
        _t(','),
        _t('('),
        _t(')'),
        _K('←', id: 'left', edit: (e) => e.left(), tone: _Tone.dark),
        _K('→', id: 'right', edit: (e) => e.right(), tone: _Tone.dark),
        const _K('↵', action: 'enter', tone: _Tone.accent, flex: 1.6),
      ],
    ];
  }

  static _K _w(String w, {String? label}) => _K(
    label ?? w,
    math: label == null ? '\\$w ' : null,
    id: 'fn-$w',
    edit: (e) => e.word(w),
  );

  static final _sections = <(String, List<_K>)>[
    (
      'TRIG FUNCTIONS',
      [
        for (final w in ['sin', 'cos', 'tan', 'csc', 'sec', 'cot']) _w(w),
      ],
    ),
    (
      'INVERSE TRIG FUNCTIONS',
      [
        for (final w in ['sin', 'cos', 'tan', 'csc', 'sec', 'cot'])
          _K(
            '$w⁻¹',
            math: '\\arc$w ',
            id: 'fn-arc$w',
            edit: (e) => e.word('arc$w'),
          ),
      ],
    ),
    (
      'CALCULUS',
      [
        _K(
          'd/dx',
          math: r'\deriv{}',
          id: 'deriv',
          edit: (e) => e.box(GxKind.deriv),
        ),
        _K(
          '∫',
          math: r'\integral{}{}{}{x}',
          id: 'integral',
          edit: (e) => e.box(GxKind.integral),
        ),
        _K('Σ', math: r'\sum{}{}{}', id: 'sum', edit: (e) => e.box(GxKind.sum)),
        _K(
          'Π',
          math: r'\prod{}{}{}',
          id: 'prod',
          edit: (e) => e.box(GxKind.prod),
        ),
      ],
    ),
    (
      'HYPERBOLIC TRIG FUNCTIONS',
      [
        for (final w in ['sinh', 'cosh', 'tanh', 'csch', 'sech', 'coth']) _w(w),
      ],
    ),
    (
      'LOGS, POWERS AND ROOTS',
      [
        _w('ln'),
        _w('log'),
        _K(
          'logₐ',
          math: r'\log _{a}',
          id: 'logbase',
          edit: (e) => e
            ..type('l')
            ..type('o')
            ..type('g')
            ..box(GxKind.sub),
        ),
        _K(
          'eˣ',
          math: 'e^{x}',
          id: 'epow',
          edit: (e) => e
            ..type('e')
            ..box(GxKind.pow),
        ),
        _K(
          'ⁿ√',
          math: r'\root{n}{}',
          id: 'root',
          edit: (e) => e.box(GxKind.root),
        ),
        _w('exp'),
      ],
    ),
    (
      'NUMBERS',
      [
        _t('!', label: 'n!'),
        _w('floor'),
        _w('ceil'),
        _w('round'),
        _w('sign'),
        _w('mod'),
        _w('min'),
        _w('max'),
      ],
    ),
  ];

  /// Taps outside the functions panel (and its key) close it.
  static const _funcsGroup = 'gx-funcs';

  void _press(_K k) {
    keyVibration();
    widget.onKey?.call(k.id ?? k.action ?? k.label);
    switch (k.action) {
      case 'funcs':
        return setState(() => _funcs = !_funcs);
      case 'abc':
        return setState(() {
          _letters = !_letters;
          _shift = false;
          _funcs = false;
        });
      case 'shift':
        return setState(() => _shift = !_shift);
      case 'enter':
        setState(() => _funcs = false);
        return widget.onEnter();
    }
    if (k.edit case final edit?) {
      widget.onEdit(edit);
      if (_funcs) setState(() => _funcs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _letters ? _alpha() : _main;
    return Material(
      key: const Key('gx-keypad'),
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in rows)
                    SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          for (final k in r)
                            if (k == null)
                              const SizedBox(width: 8)
                            else
                              Expanded(
                                flex: (k.flex * 10).round(),
                                child: k.action == 'funcs'
                                    ? TapRegion(
                                        groupId: _funcsGroup,
                                        child: _KeyCap(
                                          k: k,
                                          onTap: () => _press(k),
                                        ),
                                      )
                                    : _KeyCap(k: k, onTap: () => _press(k)),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_funcs)
                Positioned.fill(
                  child: TapRegion(
                    groupId: _funcsGroup,
                    onTapOutside: (_) => setState(() => _funcs = false),
                    child: _FuncsPanel(
                      sections: _sections,
                      onTap: _press,
                      onClose: () => setState(() => _funcs = false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.k, required this.onTap});

  final _K k;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (k.tone) {
      _Tone.plain => (scheme.surfaceContainerLowest, scheme.onSurface),
      _Tone.number => (scheme.surfaceContainerLowest, scheme.onSurface),
      _Tone.dark => (scheme.surfaceContainerHighest, scheme.onSurface),
      _Tone.accent => (scheme.primary, scheme.onPrimary),
    };
    final label = k.math != null
        ? GxMathView(row: GxRow.parse(k.math!), size: 17, color: fg)
        : Text(
            k.label,
            maxLines: 1,
            style: TextStyle(
              color: fg,
              fontSize: k.label.length > 3 ? 14 : 19,
              fontFamily: 'serif',
              fontFamilyFallback: const ['WCalcSymbols'],
            ),
          );
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Semantics(
        button: true,
        label: k.label,
        child: Material(
          color: bg,
          elevation: 0.6,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            key: Key('gx-key-${k.id ?? k.action ?? k.label}'),
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FuncsPanel extends StatelessWidget {
  const _FuncsPanel({
    required this.sections,
    required this.onTap,
    required this.onClose,
  });

  final List<(String, List<_K>)> sections;
  final ValueChanged<_K> onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('gx-funcs'),
      color: scheme.surfaceContainerLow,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          _list(scheme),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton(
              key: const Key('gx-funcs-close'),
              tooltip: 'Close functions',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      children: [
        for (final (title, keys) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
            children: [
              for (final k in keys) _KeyCap(k: k, onTap: () => onTap(k)),
            ],
          ),
        ],
      ],
    );
  }
}
