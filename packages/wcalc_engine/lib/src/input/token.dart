/// What a token is, for the evaluator.
enum TokKind {
  digit,
  point,
  exp,
  binary,

  /// Type B function: key first, then value (sin, √, log, (−) …).
  prefix,

  /// Type A function: value first, then key (x², x⁻¹, x!, °/ʳ/ᵍ …).
  postfix,
  openParen,
  closeParen,

  /// Ans, Ran#: a value read from memory / generated.
  operand,

  /// π, e: constants (implied multiplication like memory names).
  constant,
}

/// One input step on the upper line. Each key press inserts one token, so
/// DEL/INS/cursor work on whole tokens ("sin " is one step), like the device.
enum Tok {
  d0('0', TokKind.digit),
  d1('1', TokKind.digit),
  d2('2', TokKind.digit),
  d3('3', TokKind.digit),
  d4('4', TokKind.digit),
  d5('5', TokKind.digit),
  d6('6', TokKind.digit),
  d7('7', TokKind.digit),
  d8('8', TokKind.digit),
  d9('9', TokKind.digit),
  point('.', TokKind.point),
  exp('E', TokKind.exp),

  add('+', TokKind.binary),
  subtract('-', TokKind.binary),
  multiply('×', TokKind.binary),
  divide('÷', TokKind.binary),
  power('^', TokKind.binary),
  xRoot('ˣ√', TokKind.binary),
  nPr('P', TokKind.binary),
  nCr('C', TokKind.binary),

  negative('-', TokKind.prefix),
  sin('sin ', TokKind.prefix),
  cos('cos ', TokKind.prefix),
  tan('tan ', TokKind.prefix),
  asin('sin⁻¹ ', TokKind.prefix),
  acos('cos⁻¹ ', TokKind.prefix),
  atan('tan⁻¹ ', TokKind.prefix),
  sinh('sinh ', TokKind.prefix),
  cosh('cosh ', TokKind.prefix),
  tanh('tanh ', TokKind.prefix),
  asinh('sinh⁻¹ ', TokKind.prefix),
  acosh('cosh⁻¹ ', TokKind.prefix),
  atanh('tanh⁻¹ ', TokKind.prefix),
  log('log ', TokKind.prefix),
  ln('ln ', TokKind.prefix),
  tenPow('10^', TokKind.prefix),
  ePow('e^', TokKind.prefix),
  sqrt('√', TokKind.prefix),
  cbrt('³√', TokKind.prefix),
  rnd('Rnd ', TokKind.prefix),

  square('²', TokKind.postfix),
  cube('³', TokKind.postfix),
  reciprocal('⁻¹', TokKind.postfix),
  factorial('!', TokKind.postfix),
  degMark('°', TokKind.postfix),
  radMark('ʳ', TokKind.postfix),
  graMark('ᵍ', TokKind.postfix),

  openParen('(', TokKind.openParen),
  closeParen(')', TokKind.closeParen),
  ans('Ans', TokKind.operand),
  ran('Ran#', TokKind.operand),
  pi('π', TokKind.constant),
  e('e', TokKind.constant);

  const Tok(this.text, this.kind);

  /// Characters shown on the LCD.
  final String text;
  final TokKind kind;

  static const digits = [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9];

  /// Digit value, or null.
  int? get digit => kind == TokKind.digit ? index - d0.index : null;
}
