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

/// Cursor key cluster: one round disc, or four separate arrow keys.
enum PadStyle { disc, cross }

/// Arrangement of a calculator's keys. Every layout drives the same engine;
/// only the physical look differs.
class KeypadLayout {
  /// Two-line reference look: modifier keys beside a round cursor disc.
  const KeypadLayout.disc({
    required this.id,
    required this.topLeft,
    required this.topRight,
    required this.functionRows,
    required this.numberRows,
    this.pad = PadStyle.disc,
  }) : topRows = const [],
       hasDisc = true;

  /// Grid look: separate arrow keys, every key the same size.
  const KeypadLayout.grid({
    required this.id,
    required this.topRows,
    required this.functionRows,
    required this.numberRows,
  }) : topLeft = const [],
       topRight = const [],
       hasDisc = false,
       pad = PadStyle.disc;

  final String id;
  final bool hasDisc;

  /// Shape of the cursor keys between the top-left and top-right keys.
  final PadStyle pad;

  /// Disc layouts: rows left and right of the disc.
  final List<List<KeySpec>> topLeft;
  final List<List<KeySpec>> topRight;

  /// Grid layouts: rows above the function block.
  final List<List<KeySpec>> topRows;

  final List<List<KeySpec>> functionRows;
  final List<List<KeySpec>> numberRows;

  /// Every key spec of this layout (tests, accessibility).
  Iterable<KeySpec> get allKeys => [
    ...topLeft,
    ...topRight,
    ...topRows,
    ...functionRows,
    ...numberRows,
  ].expand((r) => r);
}

/// Two-line reference look.
const twoLineLayout = KeypadLayout.disc(
  id: 'two-line',
  topLeft: [row0Left, row1Left],
  topRight: [row0Right, row1Right],
  functionRows: functionRows,
  numberRows: numberRows,
);

/// Classic grid: "2nd" modifier, arrow keys in the top rows.
const gridLayout = KeypadLayout.grid(
  id: 'grid',
  topRows: [
    [
      KeySpec(
        CalcKey.shift,
        '2nd',
        above: [KeyLabel('2nd', _s, slot: _m)],
        style: KeyStyle.modifier,
      ),
      KeySpec(
        CalcKey.alpha,
        'ALPHA',
        above: [KeyLabel('ALPHA', _a, slot: _m)],
        style: KeyStyle.modifier,
      ),
      KeySpec(CalcKey.up, '↑', style: KeyStyle.modifier),
      KeySpec(CalcKey.down, '↓', style: KeyStyle.modifier),
      KeySpec(
        CalcKey.mode,
        'MODE',
        above: [KeyLabel('CLR', _s, slot: _m)],
        style: KeyStyle.modifier,
      ),
      KeySpec(CalcKey.on, 'ON', style: KeyStyle.modifier),
    ],
    [
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
      KeySpec(CalcKey.left, '←', style: KeyStyle.modifier),
      KeySpec(CalcKey.right, '→', style: KeyStyle.modifier),
      KeySpec(
        CalcKey.reciprocal,
        'x^{-1}',
        above: [
          KeyLabel('x!', _s),
          KeyLabel('LOGIC', _b, slot: _r),
        ],
      ),
      KeySpec(
        CalcKey.constant,
        'CONST',
        above: [KeyLabel('CONV', _s, slot: _m)],
      ),
    ],
  ],
  functionRows: functionRows,
  numberRows: numberRows,
);

// ---------------------------------------------------------------------------
// Textbook-display models (silver / black units). Same keys, different body.

const _tbTopLeft = [
  [
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
  ],
  [
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
      '∫□',
      above: [
        KeyLabel('d/dx', _s),
        KeyLabel(':', _a, slot: _r),
      ],
    ),
  ],
];

const _tbTopRight = [
  [
    KeySpec(
      CalcKey.mode,
      'MODE',
      above: [
        KeyLabel('MODE', _p),
        KeyLabel('SETUP', _s, slot: _r),
      ],
      style: KeyStyle.modifier,
    ),
    KeySpec(
      CalcKey.on,
      'ON',
      above: [KeyLabel('ON', _p, slot: _m)],
      style: KeyStyle.modifier,
    ),
  ],
  [
    KeySpec(
      CalcKey.reciprocal,
      'x^{-1}',
      above: [KeyLabel('x!', _s, slot: _m)],
    ),
    KeySpec(CalcKey.logBase, 'log□', above: [KeyLabel('Σ□', _s, slot: _m)]),
  ],
];

const _tbFunctionRows = [
  [
    KeySpec(CalcKey.fraction, '□/□', above: [KeyLabel('□□/□', _s, slot: _m)]),
    KeySpec(CalcKey.sqrt, '√□', above: [KeyLabel('∛□', _s, slot: _m)]),
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
      'x^{□}',
      above: [
        KeyLabel('^{x}√□', _s),
        KeyLabel('HEX', _b, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.log,
      'log',
      above: [
        KeyLabel('10^{□}', _s),
        KeyLabel('BIN', _b, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.ln,
      'ln',
      above: [
        KeyLabel('e^{□}', _s),
        KeyLabel('OCT', _b, slot: _r),
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
    KeySpec(
      CalcKey.hyp,
      'hyp',
      above: [
        KeyLabel('Abs', _s),
        KeyLabel('C', _a, slot: _r),
      ],
    ),
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
    KeySpec(CalcKey.rcl, 'RCL', above: [KeyLabel('STO', _s, slot: _m)]),
    KeySpec(
      CalcKey.eng,
      'ENG',
      above: [
        KeyLabel('←', _s),
        KeyLabel('i', _a, slot: _r),
      ],
    ),
    KeySpec(CalcKey.openParen, '(', above: [KeyLabel('%', _s, slot: _m)]),
    KeySpec(
      CalcKey.closeParen,
      ')',
      above: [
        KeyLabel(',', _s),
        KeyLabel('X', _a, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.sd,
      'S⇔D',
      above: [
        KeyLabel('a^{b}/c⇔d/c', _s),
        KeyLabel('Y', _a, slot: _r),
      ],
    ),
    KeySpec(
      CalcKey.mPlus,
      'M+',
      above: [
        KeyLabel('M−', _s),
        KeyLabel('M', _a, slot: _r),
      ],
    ),
  ],
];

const _tbNumberRows = [
  [
    KeySpec(
      CalcKey.d7,
      '7',
      above: [KeyLabel('CONST', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d8,
      '8',
      above: [KeyLabel('CONV', _s, slot: _m)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d9,
      '9',
      above: [KeyLabel('CLR', _s, slot: _m)],
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
      above: [KeyLabel('MATRIX', _s, slot: _m, bracket: _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d5,
      '5',
      above: [KeyLabel('VECTOR', _s, slot: _m, bracket: _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(CalcKey.d6, '6', style: KeyStyle.digit),
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
      above: [KeyLabel('STAT', _s, slot: _m, bracket: _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d2,
      '2',
      above: [KeyLabel('CMPLX', _s, slot: _m, bracket: _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.d3,
      '3',
      above: [KeyLabel('BASE', _s, slot: _m, bracket: _s)],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.add,
      '+',
      above: [KeyLabel('Pol', _s, slot: _m)],
      style: KeyStyle.operator,
    ),
    KeySpec(
      CalcKey.subtract,
      '−',
      above: [KeyLabel('Rec', _s, slot: _m)],
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
      above: [
        KeyLabel('Ran#', _s),
        KeyLabel('RanInt', _a, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.exp,
      '×10^{x}',
      above: [
        KeyLabel('π', _s),
        KeyLabel('e', _a, slot: _r),
      ],
      style: KeyStyle.digit,
    ),
    KeySpec(
      CalcKey.ans,
      'Ans',
      above: [KeyLabel('DRG▸', _s, slot: _m)],
      style: KeyStyle.operator,
    ),
    KeySpec(CalcKey.equals, '=', style: KeyStyle.operator),
  ],
];

/// Silver body: round REPLAY disc.
const textbookDiscLayout = KeypadLayout.disc(
  id: 'textbook-disc',
  topLeft: _tbTopLeft,
  topRight: _tbTopRight,
  functionRows: _tbFunctionRows,
  numberRows: _tbNumberRows,
);

/// Black body: four separate arrow keys.
const textbookCrossLayout = KeypadLayout.disc(
  id: 'textbook-cross',
  topLeft: _tbTopLeft,
  topRight: _tbTopRight,
  functionRows: _tbFunctionRows,
  numberRows: _tbNumberRows,
  pad: PadStyle.cross,
);

// ---------------------------------------------------------------------------
// Four-line models.

KeySpec _k(
  CalcKey key,
  String main, {
  String? shift,
  String? alpha,
  KeyStyle style = KeyStyle.function,
}) => KeySpec(
  key,
  main,
  above: [
    if (shift != null)
      KeyLabel(shift, _s, slot: alpha == null ? _m : LabelSlot.left),
    if (alpha != null) KeyLabel(alpha, _a, slot: _r),
  ],
  style: style,
);

/// "Scientific View": five-column grid, 2nd key, ◄► answer toggle, enter.
final viewLayout = KeypadLayout.grid(
  id: 'view',
  topRows: [
    [
      _k(CalcKey.shift, '2nd', style: KeyStyle.modifier),
      _k(CalcKey.mode, 'mode', shift: 'setup', style: KeyStyle.modifier),
      _k(CalcKey.del, 'delete', shift: 'insert', style: KeyStyle.modifier),
      _k(CalcKey.left, '◀', style: KeyStyle.modifier),
      _k(CalcKey.right, '▶', style: KeyStyle.modifier),
    ],
    [
      _k(CalcKey.alpha, 'alpha', style: KeyStyle.modifier),
      _k(CalcKey.calc, 'calc', shift: 'solve', alpha: '='),
      _k(CalcKey.sd, '◄►', shift: 'U n/d', alpha: 'Y'),
      _k(CalcKey.up, '▲', style: KeyStyle.modifier),
      _k(CalcKey.down, '▼', style: KeyStyle.modifier),
    ],
  ],
  functionRows: [
    [
      _k(CalcKey.logBase, 'log□', shift: 'Σ'),
      _k(CalcKey.log, 'log', shift: '10^{□}'),
      _k(CalcKey.ln, 'ln', shift: 'e^{□}'),
      _k(CalcKey.power, 'x^{□}', shift: '^{x}√'),
      _k(CalcKey.sqrt, '√', shift: '∛'),
    ],
    [
      _k(CalcKey.reciprocal, 'x^{-1}', shift: 'x!'),
      _k(CalcKey.square, 'x^{2}', shift: 'x^{3}'),
      _k(CalcKey.sin, 'sin', shift: 'sin^{-1}', alpha: 'D'),
      _k(CalcKey.cos, 'cos', shift: 'cos^{-1}', alpha: 'E'),
      _k(CalcKey.tan, 'tan', shift: 'tan^{-1}', alpha: 'F'),
    ],
    [
      _k(CalcKey.fraction, 'n/d', shift: 'U n/d'),
      _k(CalcKey.degMinSec, '°′″', shift: '←', alpha: 'B'),
      _k(CalcKey.hyp, 'hyp', shift: 'abs', alpha: 'C'),
      _k(CalcKey.openParen, '(', shift: '%'),
      _k(CalcKey.closeParen, ')', shift: ',', alpha: 'X'),
    ],
    [
      _k(CalcKey.integrate, '∫', shift: 'd/dx', alpha: ':'),
      _k(CalcKey.rcl, 'recall', shift: 'sto→'),
      _k(CalcKey.eng, 'eng', shift: '←'),
      _k(CalcKey.mPlus, 'M+', shift: 'M−', alpha: 'M'),
      _k(CalcKey.divide, '÷', shift: 'nCr', style: KeyStyle.operator),
    ],
  ],
  numberRows: [
    [
      _k(CalcKey.negative, '(−)', shift: '∠', alpha: 'A'),
      _k(CalcKey.d7, '7', shift: 'const', style: KeyStyle.digit),
      _k(CalcKey.d8, '8', shift: 'conv', style: KeyStyle.digit),
      _k(CalcKey.d9, '9', shift: 'reset', style: KeyStyle.digit),
      _k(CalcKey.multiply, '×', shift: 'nPr', style: KeyStyle.operator),
    ],
    [
      _k(CalcKey.exp, '×10^{n}', shift: 'π', alpha: 'e'),
      _k(CalcKey.d4, '4', style: KeyStyle.digit),
      _k(CalcKey.d5, '5', style: KeyStyle.digit),
      _k(CalcKey.d6, '6', style: KeyStyle.digit),
      _k(CalcKey.subtract, '−', shift: 'Rec', style: KeyStyle.operator),
    ],
    [
      _k(CalcKey.ans, 'ans', shift: 'DRG▸'),
      _k(CalcKey.d1, '1', shift: 'stat', style: KeyStyle.digit),
      _k(CalcKey.d2, '2', style: KeyStyle.digit),
      _k(CalcKey.d3, '3', style: KeyStyle.digit),
      _k(CalcKey.add, '+', shift: 'Pol', style: KeyStyle.operator),
    ],
    [
      _k(CalcKey.ac, 'clear', shift: 'off', style: KeyStyle.clear),
      _k(CalcKey.d0, '0', shift: 'rnd', style: KeyStyle.digit),
      _k(
        CalcKey.dot,
        '.',
        shift: 'rand',
        alpha: 'randint',
        style: KeyStyle.digit,
      ),
      _k(CalcKey.on, 'on', style: KeyStyle.modifier),
      _k(CalcKey.equals, 'enter', style: KeyStyle.operator),
    ],
  ],
);

/// "Scientific Write": the textbook keys with a 2ndF modifier.
final writeLayout = KeypadLayout.disc(
  id: 'write',
  topLeft: [
    [
      _k(CalcKey.shift, '2ndF', style: KeyStyle.modifier),
      _k(CalcKey.alpha, 'ALPHA', style: KeyStyle.modifier),
    ],
    [
      _k(CalcKey.calc, 'CALC', shift: 'SOLVE', alpha: '='),
      _k(CalcKey.integrate, '∫□', shift: 'd/dx', alpha: ':'),
    ],
  ],
  topRight: _tbTopRight,
  functionRows: _tbFunctionRows,
  numberRows: _tbNumberRows,
);
