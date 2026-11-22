import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Colour family of a secondary label, by meaning (not a copy of any brand palette).
enum LabelKind { shift, alpha, complex, stat, base }

class KeyLabel {
  const KeyLabel(this.text, this.kind);
  final String text;
  final LabelKind kind;
}

/// Visual description of one key: main legend plus secondary legends printed above it.
class KeySpec {
  const KeySpec(
    this.key,
    this.main, {
    this.above = const [],
    this.style = KeyStyle.function,
  });

  final CalcKey key;
  final String main;
  final List<KeyLabel> above;
  final KeyStyle style;
}

enum KeyStyle { modifier, function, digit, operator, clear }

const _s = LabelKind.shift;
const _a = LabelKind.alpha;
const _c = LabelKind.complex;
const _t = LabelKind.stat;
const _b = LabelKind.base;

/// Function rows (row 1 has the cursor pad in its middle, handled by the screen).
const row0Left = [
  KeySpec(CalcKey.shift, 'SHIFT', style: KeyStyle.modifier),
  KeySpec(CalcKey.alpha, 'ALPHA', style: KeyStyle.modifier),
];
const row0Right = [
  KeySpec(
    CalcKey.mode,
    'MODE',
    above: [KeyLabel('CLR', _s)],
    style: KeyStyle.modifier,
  ),
  KeySpec(CalcKey.on, 'ON', style: KeyStyle.modifier),
];
const row1Left = [
  KeySpec(
    CalcKey.calc,
    'CALC',
    above: [KeyLabel('SOLVE', _s), KeyLabel('=', _a)],
  ),
  KeySpec(
    CalcKey.integrate,
    '∫dx',
    above: [KeyLabel('d/dx', _s), KeyLabel(':', _a)],
  ),
];
const row1Right = [
  KeySpec(
    CalcKey.reciprocal,
    'x^{-1}',
    above: [KeyLabel('x!', _s), KeyLabel('LOGIC', _b)],
  ),
  KeySpec(CalcKey.constant, 'CONST', above: [KeyLabel('CONV', _s)]),
];

const functionRows = [
  [
    KeySpec(CalcKey.fraction, 'a b/c', above: [KeyLabel('d/c', _s)]),
    KeySpec(CalcKey.sqrt, '√', above: [KeyLabel('^{3}√', _s)]),
    KeySpec(
      CalcKey.square,
      'x^{2}',
      above: [KeyLabel('x^{3}', _s), KeyLabel('DEC', _b)],
    ),
    KeySpec(
      CalcKey.power,
      '^',
      above: [KeyLabel('^{x}√', _s), KeyLabel('HEX', _b)],
    ),
    KeySpec(
      CalcKey.log,
      'log',
      above: [KeyLabel('10^{x}', _s), KeyLabel('BIN', _b)],
    ),
    KeySpec(
      CalcKey.ln,
      'ln',
      above: [KeyLabel('e^{x}', _s), KeyLabel('OCT', _b), KeyLabel('e', _a)],
    ),
  ],
  [
    KeySpec(
      CalcKey.negative,
      '(−)',
      above: [KeyLabel('∠', _s), KeyLabel('A', _a)],
    ),
    KeySpec(
      CalcKey.degMinSec,
      '°′″',
      above: [KeyLabel('←', _s), KeyLabel('B', _a)],
    ),
    KeySpec(CalcKey.hyp, 'hyp', above: [KeyLabel('C', _a)]),
    KeySpec(
      CalcKey.sin,
      'sin',
      above: [KeyLabel('sin^{-1}', _s), KeyLabel('D', _a)],
    ),
    KeySpec(
      CalcKey.cos,
      'cos',
      above: [KeyLabel('cos^{-1}', _s), KeyLabel('E', _a)],
    ),
    KeySpec(
      CalcKey.tan,
      'tan',
      above: [KeyLabel('tan^{-1}', _s), KeyLabel('F', _a)],
    ),
  ],
  [
    KeySpec(CalcKey.rcl, 'RCL', above: [KeyLabel('STO', _s)]),
    KeySpec(CalcKey.eng, 'ENG', above: [KeyLabel('←', _s), KeyLabel('i', _c)]),
    KeySpec(CalcKey.openParen, '(', above: [KeyLabel('arg', _c)]),
    KeySpec(
      CalcKey.closeParen,
      ')',
      above: [KeyLabel('Abs', _c), KeyLabel('X', _a)],
    ),
    KeySpec(
      CalcKey.comma,
      ',',
      above: [KeyLabel('Conjg', _c), KeyLabel(';', _s), KeyLabel('Y', _a)],
    ),
    KeySpec(
      CalcKey.mPlus,
      'M+',
      above: [KeyLabel('M−', _s), KeyLabel('M', _a), KeyLabel('DT CL', _t)],
    ),
  ],
];

const numberRows = [
  [
    KeySpec(CalcKey.d7, '7', above: [KeyLabel('M', _s)], style: KeyStyle.digit),
    KeySpec(CalcKey.d8, '8', above: [KeyLabel('G', _s)], style: KeyStyle.digit),
    KeySpec(CalcKey.d9, '9', above: [KeyLabel('T', _s)], style: KeyStyle.digit),
    KeySpec(
      CalcKey.del,
      'DEL',
      above: [KeyLabel('INS', _s)],
      style: KeyStyle.clear,
    ),
    KeySpec(
      CalcKey.ac,
      'AC',
      above: [KeyLabel('OFF', _s)],
      style: KeyStyle.clear,
    ),
  ],
  [
    KeySpec(
      CalcKey.d4,
      '4',
      above: [KeyLabel('MAT', _s), KeyLabel('μ', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d5,
      '5',
      above: [KeyLabel('VCT', _s), KeyLabel('m', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(CalcKey.d6, '6', above: [KeyLabel('k', _s)], style: KeyStyle.digit),
    KeySpec(
      CalcKey.multiply,
      '×',
      above: [KeyLabel('nPr', _s)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.divide,
      '÷',
      above: [KeyLabel('nCr', _s)],
      style: KeyStyle.operator,
    ),
  ],
  [
    KeySpec(
      CalcKey.d1,
      '1',
      above: [KeyLabel('S-SUM', _s), KeyLabel('f', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d2,
      '2',
      above: [KeyLabel('S-VAR', _s), KeyLabel('p', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d3,
      '3',
      above: [KeyLabel('DISTR', _s), KeyLabel('n', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.add,
      '+',
      above: [KeyLabel('Pol(', _s), KeyLabel('▸r∠θ', _c)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.subtract,
      '−',
      above: [KeyLabel('Rec(', _s), KeyLabel('▸a+bi', _c)],
      style: KeyStyle.operator,
    ),
  ],
  [
    KeySpec(
      CalcKey.d0,
      '0',
      above: [KeyLabel('Rnd', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.dot,
      '•',
      above: [KeyLabel('Ran#', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.exp,
      'EXP',
      above: [KeyLabel('π', _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.ans,
      'Ans',
      above: [KeyLabel('DRG▸', _s)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.equals,
      '=',
      above: [KeyLabel('%', _s), KeyLabel('Re↔Im', _c)],
      style: KeyStyle.operator,
    ),
  ],
];

/// W-Calc "Classic" palette: our own colours, same meaning per label family.
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
  };
}
