/// Wide-precision decimal used *inside* function evaluation.
///
/// Functions (sin, ln, x^y, …) are computed with [Wide.precision] significant
/// digits and rounded to 15 digits ([Dec]) only at the end, so results are
/// correctly rounded in practically every case.
library;

import 'dart:math' as math;

import 'dec.dart';

final class Wide implements Comparable<Wide> {
  Wide._(this.c, this.e);

  factory Wide(BigInt c, int e) => _norm(c, e, precision);

  factory Wide.fromInt(int v) => Wide(BigInt.from(v), 0);

  factory Wide.fromDec(Dec d) => Wide(d.coefficient, d.exponent);

  factory Wide.parse(String s) {
    final d = s.trim();
    final m = RegExp(r'^(-?)(\d*)(?:\.(\d*))?(?:e([+-]?\d+))?$').firstMatch(d);
    if (m == null) throw FormatException('bad wide literal', s);
    final frac = m.group(3) ?? '';
    var c = BigInt.parse('${m.group(2)!.isEmpty ? '0' : m.group(2)}$frac');
    if (m.group(1) == '-') c = -c;
    return Wide(c, int.parse(m.group(4) ?? '0') - frac.length);
  }

  /// Working precision in significant digits. Raised temporarily by
  /// [withPrecision] where cancellation would otherwise lose digits.
  static int precision = 34;

  static T withPrecision<T>(int digits, T Function() body) {
    final saved = precision;
    precision = digits;
    try {
      return body();
    } finally {
      precision = saved;
    }
  }

  final BigInt c;
  final int e;

  static final zero = Wide._(BigInt.zero, 0);
  static final one = Wide._(BigInt.one, 0);
  static final two = Wide._(BigInt.two, 0);
  static final half = Wide._(BigInt.from(5), -1);

  // 60-digit constants.
  static final pi = Wide.parse(
    '3.14159265358979323846264338327950288419716939937510582097494',
  );
  static final ln10 = Wide.parse(
    '2.30258509299404568401799145468436420760110148862877297603333',
  );
  static final ln2 = Wide.parse(
    '0.693147180559945309417232121458176568075500134360255254120680',
  );

  bool get isZero => c == BigInt.zero;
  bool get isNegative => c.isNegative;
  int get sign => c.sign;

  /// floor(log10|x|).
  int get exponent10 => isZero ? -1 << 30 : _digits(c.abs()) - 1 + e;

  Dec toDec() => Dec(c, e);

  Wide operator -() => Wide._(-c, e);
  Wide abs() => isNegative ? -this : this;

  Wide operator +(Wide o) {
    if (isZero) return o;
    if (o.isZero) return this;
    if ((exponent10 - o.exponent10).abs() > precision + 3) {
      return exponent10 > o.exponent10 ? this : o;
    }
    final m = e < o.e ? e : o.e;
    return Wide(c * _p10(e - m) + o.c * _p10(o.e - m), m);
  }

  Wide operator -(Wide o) => this + (-o);
  Wide operator *(Wide o) => Wide(c * o.c, e + o.e);

  Wide operator /(Wide o) {
    if (o.isZero) throw const CalcError(CalcErrorKind.math);
    if (isZero) return zero;
    final shift = precision + 3 + _digits(o.c.abs()) - _digits(c.abs()) + 1;
    final s = shift > 0 ? shift : 0;
    return Wide((c * _p10(s)) ~/ o.c, e - o.e - s);
  }

  bool operator <(Wide o) => compareTo(o) < 0;
  bool operator >(Wide o) => compareTo(o) > 0;
  bool operator <=(Wide o) => compareTo(o) <= 0;
  bool operator >=(Wide o) => compareTo(o) >= 0;

  @override
  int compareTo(Wide o) => (this - o).sign;

  @override
  bool operator ==(Object other) => other is Wide && compareTo(other) == 0;

  @override
  int get hashCode => toDec().hashCode;

  bool get isInteger =>
      isZero || e >= 0 || c.remainder(_p10(-e)) == BigInt.zero;

  /// Truncates toward zero.
  BigInt toBigInt() => e >= 0 ? c * _p10(e) : c ~/ _p10(-e);

  /// Nearest integer (half away from zero).
  BigInt round() =>
      (abs() + half).toBigInt() * BigInt.from(sign == 0 ? 1 : sign);

  BigInt floor() {
    final t = toBigInt();
    return (isNegative && !isInteger) ? t - BigInt.one : t;
  }

  double toDouble() => double.parse('${c}e$e');

  @override
  String toString() => '${c}e$e';

  // ---- internals ----

  static Wide _norm(BigInt c, int e, int digits) {
    if (c == BigInt.zero) return zero;
    final n = _digits(c.abs());
    if (n > digits) {
      final drop = n - digits;
      final d = _p10(drop);
      final mag = c.abs();
      var q = mag ~/ d;
      if ((mag % d) * BigInt.two >= d) q += BigInt.one;
      c = c.isNegative ? -q : q;
      e += drop;
    }
    return Wide._(c, e);
  }

  static int _digits(BigInt n) => n == BigInt.zero ? 1 : n.toString().length;

  static final _cache = List.generate(80, (i) => BigInt.from(10).pow(i));
  static BigInt _p10(int n) =>
      n < _cache.length ? _cache[n] : BigInt.from(10).pow(n);

  /// Integer square root (floor).
  static BigInt isqrt(BigInt n) {
    if (n < BigInt.two) return n;
    var x = BigInt.one << ((n.bitLength + 1) >> 1);
    while (true) {
      final y = (x + n ~/ x) >> 1;
      if (y >= x) return x;
      x = y;
    }
  }

  /// Seed from a double (for Newton starting points).
  static Wide fromDouble(double v) =>
      Wide.parse(v.toStringAsExponential(16).replaceAll('e+', 'e'));
}

/// Elementary functions on [Wide]. Arguments are assumed valid; callers
/// (the function layer) do domain and range checks.
abstract final class WideMath {
  static Wide sqrt(Wide x) {
    if (x.isNegative) throw const CalcError(CalcErrorKind.math);
    if (x.isZero) return Wide.zero;
    // Scale so the integer square root has precision + 2 digits.
    final p = Wide.precision + 2;
    var shift = 2 * p - Wide._digits(x.c);
    if ((x.e - shift).isOdd) shift++;
    final scaled = shift >= 0
        ? x.c * Wide._p10(shift)
        : x.c ~/ Wide._p10(-shift);
    return Wide(Wide.isqrt(scaled), (x.e - shift) ~/ 2);
  }

  static Wide exp(Wide x) {
    if (x.isZero) return Wide.one;
    // x = n·ln2 + r, |r| <= ln2/2; then r / 2^k with Taylor and k squarings.
    final n = (x / Wide.ln2).round();
    var r = x - Wide(n, 0) * Wide.ln2;
    const k = 8;
    r = r / Wide.fromInt(1 << k);
    var term = Wide.one, sum = Wide.one;
    final eps = Wide(BigInt.one, -Wide.precision - 4);
    for (var i = 1; i < 200; i++) {
      term = term * r / Wide.fromInt(i);
      sum = sum + term;
      if (term.abs() < eps) break;
    }
    for (var i = 0; i < k; i++) {
      sum = sum * sum;
    }
    final two = Wide(BigInt.two.pow(n.abs().toInt()), 0);
    return n.isNegative ? sum / two : sum * two;
  }

  static Wide ln(Wide x) {
    if (x.isNegative || x.isZero) throw const CalcError(CalcErrorKind.math);
    // x = m·10^k, m in [1,10).
    final k = x.exponent10;
    final m = Wide(x.c, x.e - k);
    var y = Wide.fromDouble(math.log(m.toDouble()));
    // Halley iteration: y += 2(m - e^y)/(m + e^y). Cubic convergence.
    for (var i = 0; i < 4; i++) {
      final ey = exp(y);
      final delta = Wide.two * (m - ey) / (m + ey);
      y = y + delta;
      if (delta.isZero || delta.exponent10 < -Wide.precision - 2) break;
    }
    return y + Wide.fromInt(k) * Wide.ln10;
  }

  /// sin and cos of |r| <= ~0.8 by Taylor series.
  static (Wide, Wide) sinCosSmall(Wide r) {
    final eps = Wide(BigInt.one, -Wide.precision - 4);
    final r2 = r * r;
    var term = r, sin = r;
    for (var i = 1; i < 200; i++) {
      term = -(term * r2) / Wide.fromInt((2 * i) * (2 * i + 1));
      sin = sin + term;
      if (term.abs() < eps) break;
    }
    term = Wide.one;
    var cos = Wide.one;
    for (var i = 1; i < 200; i++) {
      term = -(term * r2) / Wide.fromInt((2 * i - 1) * (2 * i));
      cos = cos + term;
      if (term.abs() < eps) break;
    }
    return (sin, cos);
  }

  static Wide atan(Wide x) {
    if (x.isZero) return Wide.zero;
    if (x.isNegative) return -atan(-x);
    if (x > Wide.one) return Wide.pi * Wide.half - atan(Wide.one / x);
    // Halve the argument twice: atan(x) = 2·atan(x / (1 + sqrt(1 + x²))).
    var y = x;
    for (var i = 0; i < 2; i++) {
      y = y / (Wide.one + sqrt(Wide.one + y * y));
    }
    final eps = Wide(BigInt.one, -Wide.precision - 4);
    final y2 = y * y;
    var power = y, sum = y;
    for (var i = 1; i < 500; i++) {
      power = -(power * y2);
      final term = power / Wide.fromInt(2 * i + 1);
      sum = sum + term;
      if (term.abs() < eps) break;
    }
    return sum * Wide.fromInt(4);
  }

  /// Integer power by repeated squaring (exact up to working precision).
  static Wide powInt(Wide x, BigInt n) {
    if (n.isNegative) return Wide.one / powInt(x, -n);
    var result = Wide.one, base = x;
    var k = n;
    while (k > BigInt.zero) {
      if (k.isOdd) result = result * base;
      k = k >> 1;
      if (k > BigInt.zero) base = base * base;
    }
    return result;
  }
}
