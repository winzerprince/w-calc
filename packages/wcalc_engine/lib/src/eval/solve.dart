import '../number/dec.dart';

/// Newton's method (manual: "SOLVE uses Newton's method"), starting at [x0].
/// [f] may throw [CalcError] where undefined. Throws Can't Solve when the
/// iteration does not converge.
Dec newtonSolve(Dec Function(Dec x) f, Dec x0) {
  var x = x0;
  final tolerance = Dec.parse('1e-12');
  for (var i = 0; i < 150; i++) {
    final fx = f(x);
    if (fx.isZero) return x;
    final scale = x.abs() > Dec.one ? x.abs() : Dec.one;
    final h = Dec.parse('1e-6') * scale;
    final slope = (f(x + h) - f(x - h)) / (Dec.fromInt(2) * h);
    if (slope.isZero) {
      // Flat spot: nudge and retry.
      x = x + Dec.parse('0.1') * scale;
      continue;
    }
    final step = fx / slope;
    x = x - step;
    if (step.abs() <= tolerance * scale) {
      final residual = f(x).abs();
      final yScale = fx.abs() > Dec.one ? fx.abs() : Dec.one;
      if (residual <= Dec.parse('1e-9') * yScale) return x;
    }
  }
  throw const CalcError(CalcErrorKind.cantSolve);
}
