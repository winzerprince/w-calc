/// Every physical key on the keypad, top-left to bottom-right.
///
/// Secondary functions (SHIFT / ALPHA / mode-specific) are not separate keys:
/// the engine resolves them from the modifier state when the key is pressed.
enum CalcKey {
  // Row 0
  shift,
  alpha,
  up,
  down,
  left,
  right,
  mode,
  on,

  // Row 1
  calc,
  integrate,
  reciprocal,
  constant,

  // Row 2
  fraction,
  sqrt,
  square,
  power,
  log,
  ln,

  // Row 3
  negative,
  degMinSec,
  hyp,
  sin,
  cos,
  tan,

  // Row 4
  rcl,
  eng,
  openParen,
  closeParen,
  comma,
  mPlus,

  // Rows 5-8
  d7,
  d8,
  d9,
  del,
  ac,
  d4,
  d5,
  d6,
  multiply,
  divide,
  d1,
  d2,
  d3,
  add,
  subtract,
  d0,
  dot,
  exp,
  ans,
  equals,

  // Textbook-display models only.
  /// log_□ (Σ on SHIFT).
  logBase,

  /// S⇔D: exact ↔ decimal result (a b/c ⇔ d/c on SHIFT, Y on ALPHA).
  sd;

  /// Digit value for `d0`..`d9`, otherwise null.
  int? get digit => switch (this) {
    d0 => 0,
    d1 => 1,
    d2 => 2,
    d3 => 3,
    d4 => 4,
    d5 => 5,
    d6 => 6,
    d7 => 7,
    d8 => 8,
    d9 => 9,
    _ => null,
  };
}
