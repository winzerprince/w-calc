import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Colour family of a legend, by meaning:
/// shift = SHIFT function, alpha = ALPHA variable/constant,
/// complex = CMPLX mode, stat = SD/REG mode, base = BASE mode,
/// plain = the key's own name printed on the body, neutral = other modes.
enum LabelKind { shift, alpha, complex, stat, base, plain, neutral }

/// Where a legend sits relative to its key.
enum LabelSlot { left, center, right }

/// A printed legend near a key. [bracket] draws corner brackets in that
/// colour family around the text (mode-specific functions).
class KeyLabel {
  const KeyLabel(
    this.text,
    this.kind, {
    this.slot = LabelSlot.left,
    this.bracket,
  });

  final String text;
  final LabelKind kind;
  final LabelSlot slot;
  final LabelKind? bracket;
}

/// Visual description of one key.
class KeySpec {
  const KeySpec(
    this.key,
    this.main, {
    this.above = const [],
    this.below = const [],
    this.style = KeyStyle.function,
  });

  final CalcKey key;

  /// Legend on the key cap.
  final String main;

  /// Legends printed above the key (`^{..}` marks superscripts).
  final List<KeyLabel> above;

  /// Legends printed below the key.
  final List<KeyLabel> below;

  final KeyStyle style;
}

enum KeyStyle { modifier, function, digit, operator, clear }

const _s = LabelKind.shift;
const _a = LabelKind.alpha;
const _c = LabelKind.complex;
const _t = LabelKind.stat;
const _b = LabelKind.base;
const _p = LabelKind.plain;
const _n = LabelKind.neutral;
const _m = LabelSlot.center;
const _r = LabelSlot.right;

// Top block (row 0 small keys + row 1 around the cursor disc).
const row0Left = [
  KeySpec(
    CalcKey.shift,
    'SHIFT',
    above: [KeyLabel('SHIFT', _s)],
    style: KeyStyle.modifier,
  ),
  KeySpec(
    CalcKey.alpha,
    'ALPHA',
    above: [KeyLabel('ALPHA', _a)],
    style: KeyStyle.modifier,
  ),
];
const row0Right = [
  KeySpec(
    CalcKey.mode,
    'MODE',
    above: [
      KeyLabel('MODE', _p),
      KeyLabel('CLR', _s, slot: _r),
    ],
    style: KeyStyle.modifier,
  ),
  KeySpec(
    CalcKey.on,
    'ON',
    above: [KeyLabel('ON', _p, slot: _m)],
    style: KeyStyle.modifier,
  ),
];
const row1Left = [
  KeySpec(
    CalcKey.calc,
    'CALC',
    above: [
      KeyLabel('SOLVE', _s),
      KeyLabel('=', _a, slot: _r),
    ],
  ),
  KeySpec(
    CalcKey.integrate,
    '∫dx',
    above: [
      KeyLabel('d/dx', _s),
      KeyLabel(':', _a, slot: _r),
    ],
  ),
];
const row1Right = [
  KeySpec(
    CalcKey.reciprocal,
    'x^{-1}',
    above: [
      KeyLabel('x!', _s),
      KeyLabel('LOGIC', _b, slot: _r),
    ],
  ),
  KeySpec(CalcKey.constant, 'CONST', above: [KeyLabel('CONV', _s, slot: _m)]),
];

const functionRows = [
  [
    KeySpec(
      CalcKey.fraction,
      'a^{b}/c',
      above: [KeyLabel('d/c', _s, slot: _m)],
    ),
    KeySpec(CalcKey.sqrt, '√', above: [KeyLabel('^{3}√', _s, slot: _m)]),
    KeySpec(
      CalcKey.square,
      'x^{2}',
      above: [
        KeyLabel('x^{3}', _s),
        KeyLabel('DEC', _b, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.power,
      '^',
      above: [
        KeyLabel('^{x}√', _s),
        KeyLabel('HEX', _b, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.log,
      'log',
      above: [
        KeyLabel('10^{x}', _s),
        KeyLabel('BIN', _b, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.ln,
      'ln',
      above: [
        KeyLabel('e^{x}', _s),
        KeyLabel('OCT', _b),
        KeyLabel('e', _a, slot: _r),
      ],
    ),
  ],
  [
    KeySpec(
      CalcKey.negative,
      '(−)',
      above: [
        KeyLabel('∠', _s, bracket: _c),
        KeyLabel('A', _a, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.degMinSec,
      '°′″',
      above: [
        KeyLabel('←', _s),
        KeyLabel('B', _a, slot: _r),
      ],
    ),
    KeySpec(CalcKey.hyp, 'hyp', above: [KeyLabel('C', _a, slot: _r)]),
    KeySpec(
      CalcKey.sin,
      'sin',
      above: [
        KeyLabel('sin^{-1}', _s),
        KeyLabel('D', _a, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.cos,
      'cos',
      above: [
        KeyLabel('cos^{-1}', _s),
        KeyLabel('E', _a, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.tan,
      'tan',
      above: [
        KeyLabel('tan^{-1}', _s),
        KeyLabel('F', _a, slot: _r),
      ],
    ),
  ],
  [
    KeySpec(CalcKey.rcl, 'RCL', above: [KeyLabel('STO', _s)]),
    KeySpec(
      CalcKey.eng,
      'ENG',
      above: [
        KeyLabel('←', _s),
        KeyLabel('i', _c, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.openParen,
      '(',
      below: [KeyLabel('arg', _s, slot: _m, bracket: _c)],
    ),
    KeySpec(
      CalcKey.closeParen,
      ')',
      above: [KeyLabel('X', _a, slot: _r)],
      below: [KeyLabel('Abs', _s, slot: _m, bracket: _c)],
    ),
    KeySpec(
      CalcKey.comma,
      ',',
      above: [
        KeyLabel(';', _s, slot: _m),
        KeyLabel('Y', _a, slot: _r),
      ],
      below: [KeyLabel('Conjg', _s, slot: _m, bracket: _c)],
    ),
    KeySpec(
      CalcKey.mPlus,
      'M+',
      above: [
        KeyLabel('M−', _s),
        KeyLabel('M', _a, slot: _r),
      ],
      below: [
        KeyLabel('DT', _t),
        KeyLabel('CL', _s, slot: _r, bracket: _t),
      ],
    ),
  ],
];

const numberRows = [
  [
    KeySpec(
      CalcKey.d7,
      '7',
      above: [KeyLabel('M', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d8,
      '8',
      above: [KeyLabel('G', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d9,
      '9',
      above: [KeyLabel('T', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.del,
      'DEL',
      above: [KeyLabel('INS', _s, slot: _m)],
      style: KeyStyle.clear,
    ),
    KeySpec(
      CalcKey.ac,
      'AC',
      above: [KeyLabel('OFF', _s, slot: _m)],
      style: KeyStyle.clear,
    ),
  ],
  [
    KeySpec(
      CalcKey.d4,
      '4',
      above: [
        KeyLabel('MAT', _s, bracket: _n),
        KeyLabel('μ', _s, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d5,
      '5',
      above: [
        KeyLabel('VCT', _s, bracket: _n),
        KeyLabel('m', _s, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d6,
      '6',
      above: [KeyLabel('k', _s, slot: _r)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.multiply,
      '×',
      above: [KeyLabel('nPr', _s, slot: _m)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.divide,
      '÷',
      above: [KeyLabel('nCr', _s, slot: _m)],
      style: KeyStyle.operator,
    ),
  ],
  [
    KeySpec(
      CalcKey.d1,
      '1',
      above: [
        KeyLabel('S-SUM', _s, bracket: _t),
        KeyLabel('f', _s, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d2,
      '2',
      above: [
        KeyLabel('S-VAR', _s, bracket: _t),
        KeyLabel('p', _s, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d3,
      '3',
      above: [
        KeyLabel('DISTR', _s, bracket: _t),
        KeyLabel('n', _s, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.add,
      '+',
      above: [
        KeyLabel('▸r∠θ', _s, bracket: _c),
        KeyLabel('Pol(', _s, slot: _r),
      ],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.subtract,
      '−',
      above: [
        KeyLabel('▸a+bi', _s, bracket: _c),
        KeyLabel('Rec(', _s, slot: _r),
      ],
      style: KeyStyle.operator,
    ),
  ],
  [
    KeySpec(
      CalcKey.d0,
      '0',
      above: [KeyLabel('Rnd', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.dot,
      '•',
      above: [KeyLabel('Ran#', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.exp,
      'EXP',
      above: [KeyLabel('π', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.ans,
      'Ans',
      above: [KeyLabel('DRG▸', _s, slot: _m)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.equals,
      '=',
      above: [
        KeyLabel('Re↔Im', _s, bracket: _c),
        KeyLabel('%', _s, slot: _r),
      ],
      style: KeyStyle.operator,
    ),
  ],
];

/// W-Calc "Classic" palette: our own colours, same meaning per legend family.
class WCalcColors {
  static const background = Color(0xFF15171C);
  static const bodyTop = Color(0xFF353A4A);
  static const body = Color(0xFF262A36);
  static const bezel = Color(0xFF1B1E26);
  static const functionKey = Color(0xFF1A1C22);
  static const digitKey = Color(0xFF9DA2AA);
  static const operatorKey = Color(0xFF8E939C);
  static const clearKey = Color(0xFFB4505A);
  static const modifierKey = Color(0xFFD9D6CF);

  static Color label(LabelKind kind) => switch (kind) {
    LabelKind.shift => const Color(0xFFF2A33A),
    LabelKind.alpha => const Color(0xFFE5506A),
    LabelKind.complex => const Color(0xFFB98AE8),
    LabelKind.stat => const Color(0xFF6FA8F0),
    LabelKind.base => const Color(0xFF5CC77A),
    LabelKind.plain => const Color(0xFFB9BDC6),
    LabelKind.neutral => const Color(0xFF8D93A0),
  };
}
