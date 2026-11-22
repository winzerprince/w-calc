/// Decimal floating-point number with 15 significant digits.
///
/// The reference calculator works in decimal with 15 internal digits, which is
/// why `0.1 + 0.2` is exactly `0.3` and `1 ÷ 3 × 3` displays as `1`.
/// Binary `double` cannot reproduce that, so every value that can reach the
/// display is a [Dec].
///
/// Value = [coefficient] × 10^[exponent]. Instances are normalized: the
/// coefficient has no trailing zeros and at most [precision] digits; zero is
/// `0 × 10^0`.
library;

import 'calc_error.dart';

export 'calc_error.dart';

final class Dec implements Comparable<Dec> {
  Dec._raw(this.coefficient, this.exponent);

  /// Builds `coef × 10^exp`, rounding to [precision] digits and range-checking.
  factory Dec(BigInt coef, int exp) => _normalize(coef, exp, precision);

  factory Dec.fromInt(int value) => Dec(BigInt.from(value), 0);

  /// Parses `[-]digits[.digits][e[-]digits]`.
  factory Dec.parse(String source) {
    final m = _pattern.firstMatch(source.trim());
    if (m == null || (m.group(2)!.isEmpty && (m.group(3) ?? '').isEmpty)) {
      throw FormatException('Not a number', source);
    }
    final negative = m.group(1) == '-';
    final intPart = m.group(2)!;
    final fracPart = m.group(3) ?? '';
    final exp = int.parse(m.group(4) ?? '0');
    var coef = BigInt.parse('${intPart.isEmpty ? '0' : intPart}$fracPart');
    if (negative) coef = -coef;
    return Dec(coef, exp - fracPart.length);
  }

  static final _pattern = RegExp(
    r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  /// Significant digits kept internally.
  static const int precision = 15;

  /// Values with magnitude below this become zero.
  static const int minExponent10 = -99;

  /// Values with magnitude >= 10^[maxExponent10 + 1] are a Math ERROR.
  static const int maxExponent10 = 99;

  static final Dec zero = Dec._raw(BigInt.zero, 0);
  static final Dec one = Dec._raw(BigInt.one, 0);

  final BigInt coefficient;
  final int exponent;

  bool get isZero => coefficient == BigInt.zero;
  bool get isNegative => coefficient.isNegative;
  bool get isInteger => isZero || exponent >= 0;

  /// floor(log10(|this|)); undefined (0) for zero.
  int get exponent10 =>
      isZero ? 0 : _digitCount(coefficient.abs()) - 1 + exponent;

  Dec operator -() => Dec._raw(-coefficient, exponent);

  Dec abs() => isNegative ? -this : this;

  Dec operator +(Dec other) {
    if (isZero) return other;
    if (other.isZero) return this;
    // Operand far below the other's last kept digit cannot change the rounded result.
    if ((exponent10 - other.exponent10).abs() > precision + 2) {
      return exponent10 > other.exponent10 ? this : other;
    }
    final e = exponent < other.exponent ? exponent : other.exponent;
    final a = coefficient * _pow10(exponent - e);
    final b = other.coefficient * _pow10(other.exponent - e);
    return Dec(a + b, e);
  }

  Dec operator -(Dec other) => this + (-other);

  Dec operator *(Dec other) =>
      Dec(coefficient * other.coefficient, exponent + other.exponent);

  Dec operator /(Dec other) {
    if (other.isZero) throw const CalcError(CalcErrorKind.math);
    if (isZero) return zero;
    // Scale so the quotient has precision + 3 guard digits, then fold the
    // remainder into a sticky digit so half-up rounding is exact.
    final shift = precision + 3 + _digitCount(other.coefficient.abs());
    final scaled = coefficient * _pow10(shift);
    var q = scaled ~/ other.coefficient;
    var e = exponent - other.exponent - shift;
    if (scaled.remainder(other.coefficient) != BigInt.zero) {
      q =
          q * BigInt.from(10) +
          (q.isNegative || (scaled.isNegative != other.coefficient.isNegative)
              ? -BigInt.one
              : BigInt.one);
      e -= 1;
    }
    return Dec(q, e);
  }

  bool operator <(Dec other) => compareTo(other) < 0;
  bool operator <=(Dec other) => compareTo(other) <= 0;
  bool operator >(Dec other) => compareTo(other) > 0;
  bool operator >=(Dec other) => compareTo(other) >= 0;

  @override
  int compareTo(Dec other) {
    final diff = this - other;
    return diff.isZero ? 0 : (diff.isNegative ? -1 : 1);
  }

  @override
  bool operator ==(Object other) =>
      other is Dec &&
      other.coefficient == coefficient &&
      other.exponent == exponent;

  @override
  int get hashCode => Object.hash(coefficient, exponent);

  /// Rounds half-up (away from zero) to [digits] significant digits.
  Dec roundSignificant(int digits) => _normalize(coefficient, exponent, digits);

  /// Rounds half-up (away from zero) to [places] digits after the decimal point.
  Dec roundDecimals(int places) {
    if (isZero || exponent >= -places) return this;
    final drop = -places - exponent;
    return Dec(_roundDrop(coefficient, drop), -places);
  }

  int toInt() {
    if (!isInteger) throw StateError('$this is not an integer');
    return (coefficient * _pow10(exponent)).toInt();
  }

  /// Plain decimal notation (no exponent), for debugging and tests.
  @override
  String toString() {
    if (isZero) return '0';
    final digits = coefficient.abs().toString();
    final sign = isNegative ? '-' : '';
    if (exponent >= 0) return '$sign$digits${'0' * exponent}';
    final point = digits.length + exponent;
    if (point > 0) {
      return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
    }
    return '${sign}0.${'0' * -point}$digits';
  }

  // ---- internals ----

  static Dec _normalize(BigInt coef, int exp, int digits) {
    if (coef == BigInt.zero) return zero;
    final count = _digitCount(coef.abs());
    if (count > digits) {
      final drop = count - digits;
      coef = _roundDrop(coef, drop);
      exp += drop;
    }
    final ten = BigInt.from(10);
    while (coef.remainder(ten) == BigInt.zero) {
      coef = coef ~/ ten;
      exp += 1;
    }
    final e10 = _digitCount(coef.abs()) - 1 + exp;
    if (e10 > maxExponent10) throw const CalcError(CalcErrorKind.math);
    if (e10 < minExponent10) return zero;
    return Dec._raw(coef, exp);
  }

  /// Removes [drop] low digits from [coef], rounding half away from zero.
  static BigInt _roundDrop(BigInt coef, int drop) {
    final divisor = _pow10(drop);
    final magnitude = coef.abs();
    var q = magnitude ~/ divisor;
    if ((magnitude % divisor) * BigInt.two >= divisor) q += BigInt.one;
    return coef.isNegative ? -q : q;
  }

  static int _digitCount(BigInt n) =>
      n == BigInt.zero ? 1 : n.toString().length;

  static final List<BigInt> _powCache = List.generate(
    64,
    (i) => BigInt.from(10).pow(i),
  );

  static BigInt _pow10(int n) =>
      n < _powCache.length ? _powCache[n] : BigInt.from(10).pow(n);
}
