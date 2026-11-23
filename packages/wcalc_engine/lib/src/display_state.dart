/// Status indicators shown in the top row of the LCD.
enum Indicator {
  shift,
  alpha,
  hyp,
  memory,
  sto,
  rcl,
  sd,
  reg,
  fix,
  sci,
  eng,
  deg,
  rad,
  gra,
  cmplx,
  mat,
  vct,
  reIm,
  scrollUp,
  scrollDown,

  /// MAT / VCT editors: more elements to the left / right.
  scrollLeft,
  scrollRight,
  disp,

  /// CMPLX: the shown part is the imaginary part (i) / the angle (∠).
  imaginary,
  angleMark,

  /// CMPLX results in polar format (r∠θ setting).
  polar,
}

/// Cursor shapes on the upper line.
enum CursorStyle {
  /// `_` overwrite cursor (default).
  underscore,

  /// Insert cursor (after SHIFT INS).
  insert,

  /// `■` shown from the 73rd input step: memory running low.
  block,
}

/// Immutable snapshot of what the two-line LCD shows.
class DisplayState {
  const DisplayState({
    required this.upper,
    required this.lower,
    this.exponent,
    this.engSymbol,
    this.decimalComma = false,
    this.indicators = const {},
    this.cursor,
    this.cursorStyle = CursorStyle.underscore,
    this.menuMarks,
    this.isOff = false,
    this.contrast = 0,
  });

  /// Visible part of the dot-matrix line (at most [upperColumns] characters).
  final String upper;

  /// Result line mantissa, e.g. `-25.5`, `36.`, `6.666666667`.
  final String lower;

  /// Two-digit exponent shown at the right of the result line (`19`, `-03`), or null.
  final String? exponent;

  /// EngON: engineering symbol shown in the exponent area (k, m, μ …).
  final String? engSymbol;

  /// Comma setting: show the decimal point as a comma (separators as periods).
  final bool decimalComma;

  final Set<Indicator> indicators;

  /// Cursor column within [upper] (0..[upperColumns]-1), or null when hidden.
  final int? cursor;

  final CursorStyle cursorStyle;

  /// Menu screens: digits shown on the result line, keyed by the upper-line
  /// column they sit under (e.g. `Deg Rad Gra` → {1: '1', 5: '2', 9: '3'}).
  final Map<int, String>? menuMarks;

  /// Switched off (SHIFT AC): the LCD shows nothing until ON.
  final bool isOff;

  /// LCD contrast setting, −5 (light) … +5 (dark).
  final int contrast;

  static const DisplayState off = DisplayState(
    upper: '',
    lower: '',
    isOff: true,
  );

  static const int upperColumns = 12;

  @override
  String toString() =>
      'DisplayState($upper | $lower${exponent == null ? '' : 'E$exponent'} | cursor $cursor | $indicators)';
}
