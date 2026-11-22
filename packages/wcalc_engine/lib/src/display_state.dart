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
}

/// Immutable snapshot of what the two-line LCD shows.
class DisplayState {
  const DisplayState({
    required this.upper,
    required this.lower,
    this.indicators = const {},
  });

  /// Dot-matrix input/expression line.
  final String upper;

  /// Seven-segment result line (mantissa, may include `×10^` exponent later).
  final String lower;

  final Set<Indicator> indicators;

  @override
  String toString() => 'DisplayState($upper | $lower | $indicators)';
}
