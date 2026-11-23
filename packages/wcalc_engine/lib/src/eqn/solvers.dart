/// EQN mode solvers (manual p.59-62), computed at working precision.
library;

import '../angle_unit.dart';
import '../number/dec.dart';
import '../number/functions.dart';
import '../number/value.dart';
import '../number/wide.dart';

Never _mathError() => throw const CalcError(CalcErrorKind.math);

Wide _w(Dec d) => Wide.fromDec(d);

/// Solves n linear equations (rows of n coefficients + constant) by Gaussian
/// elimination with partial pivoting. Math ERROR without a unique solution.
List<Value> solveLinear(List<List<Dec>> rows) {
  final n = rows.length;
  final m = [
    for (final r in rows) [for (final v in r) _w(v)],
  ];
  final scale = m
      .expand((r) => r)
      .fold(Wide.zero, (s, v) => v.abs() > s ? v.abs() : s);
  final tiny = scale * Wide.parse('1e-20');
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
    }
    if (m[pivot][col].abs() <= tiny) _mathError();
    final tmp = m[col];
    m[col] = m[pivot];
    m[pivot] = tmp;
    for (var r = col + 1; r < n; r++) {
      final f = m[r][col] / m[col][col];
      for (var c = col; c <= n; c++) {
        m[r][c] = m[r][c] - f * m[col][c];
      }
    }
  }
  final x = List<Wide>.filled(n, Wide.zero);
  for (var r = n - 1; r >= 0; r--) {
    var s = m[r][n];
    for (var c = r + 1; c < n; c++) {
      s = s - m[r][c] * x[c];
    }
    x[r] = s / m[r][r];
  }
  return [for (final v in x) Value.dec(v.toDec())];
}

/// Roots of a·x² + b·x + c (2 coefficients after a) or a·x³ + b·x² + c·x + d.
List<Value> solvePolynomial(List<Dec> coefficients) {
  if (coefficients.first.isZero) _mathError();
  return coefficients.length == 3
      ? _quadratic(coefficients[0], coefficients[1], coefficients[2])
      : _cubic(
          coefficients[0],
          coefficients[1],
          coefficients[2],
          coefficients[3],
        );
}

List<Value> _quadratic(Dec a0, Dec b0, Dec c0) {
  final a = _w(a0), b = _w(b0), c = _w(c0);
  final disc = b * b - Wide.fromInt(4) * a * c;
  final twoA = Wide.two * a;
  if (disc.isNegative) {
    final re = (-b / twoA).toDec();
    final im = (WideMath.sqrt(-disc) / twoA).toDec();
    return [Value.complex(re, im), Value.complex(re, -im)];
  }
  final root = WideMath.sqrt(disc);
  // Stable form: q = −(b + sign(b)·√D)/2, roots q/a and c/q.
  if (b.isZero) {
    final r = root / twoA;
    return [Value.dec(r.toDec()), Value.dec((-r).toDec())];
  }
  final q = -(b + (b.isNegative ? -root : root)) * Wide.half;
  final r1 = q / a;
  final r2 = q.isZero ? Wide.zero : c / q;
  // Device order: x1 = (−b + √D) / 2a, x2 = (−b − √D) / 2a.
  final plus = b.isNegative == a.isNegative ? r2 : r1;
  final minus = identical(plus, r1) ? r2 : r1;
  final (first, second) = a.isNegative ? (minus, plus) : (plus, minus);
  return [Value.dec(first.toDec()), Value.dec(second.toDec())];
}

List<Value> _cubic(Dec a0, Dec b0, Dec c0, Dec d0) {
  final a = _w(a0);
  final b = _w(b0) / a, c = _w(c0) / a, d = _w(d0) / a;
  final three = Wide.fromInt(3);
  final shift = b / three;
  // Depressed cubic t³ + p·t + q with x = t − b/3.
  final p = c - b * b / three;
  final q = Wide.two * b * b * b / Wide.fromInt(27) - b * c / three + d;
  final half = q * Wide.half;
  final third = p / three;
  final delta = half * half + third * third * third;
  Value real(Wide t) => Value.dec((t - shift).toDec());

  if (p.isZero && q.isZero) {
    final x = real(Wide.zero);
    return [x, x, x];
  }
  if (!delta.isNegative && !delta.isZero) {
    final s = WideMath.sqrt(delta);
    final u = _cbrt(-half + s), v = _cbrt(-half - s);
    final re = (-(u + v) * Wide.half - shift).toDec();
    final im = ((u - v) * WideMath.sqrt(three) * Wide.half).toDec();
    return [
      real(u + v),
      Value.complex(re, im.abs()),
      Value.complex(re, -im.abs()),
    ];
  }
  // Three real roots (trigonometric form); order k = 0, 2, 1 as on the device.
  final r = Wide.two * WideMath.sqrt(-third);
  var cos3 = (three * q / (Wide.two * p)) * WideMath.sqrt(-three / p);
  if (cos3 > Wide.one) cos3 = Wide.one;
  if (cos3 < -Wide.one) cos3 = -Wide.one;
  final phi = Wide.fromDec(acosDec(cos3.toDec(), AngleUnit.rad)) / three;
  final step = Wide.two * Wide.pi / three;
  Value root(int k) {
    final angle = phi - step * Wide.fromInt(k);
    return real(r * Wide.fromDec(cosDec(angle.toDec(), AngleUnit.rad)));
  }

  return [root(0), root(2), root(1)];
}

Wide _cbrt(Wide x) {
  if (x.isZero) return Wide.zero;
  final r = Wide.fromDec(cbrtDec(x.abs().toDec()));
  // One Newton step at working precision.
  final y = (Wide.two * r + x.abs() / (r * r)) / Wide.fromInt(3);
  return x.isNegative ? -y : y;
}
