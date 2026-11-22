/// What a token is, for the evaluator.
enum TokKind {
  digit,
  point,
  exp,
  binary,
  prefix,
  postfix,
  openParen,
  closeParen,
  operand,
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
  negative('-', TokKind.prefix),
  openParen('(', TokKind.openParen),
  closeParen(')', TokKind.closeParen),
  ans('Ans', TokKind.operand);

  const Tok(this.text, this.kind);

  /// Characters shown on the LCD.
  final String text;
  final TokKind kind;

  static const digits = [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9];

  /// Digit value, or null.
  int? get digit => kind == TokKind.digit ? index - d0.index : null;
}
