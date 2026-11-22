import '../number/dec.dart';

enum DisplayMode { norm, fix, sci }

/// Result display setting (setup menu "Fix / Sci / Norm").
class DisplayFormat {
  const DisplayFormat.norm1() : mode = DisplayMode.norm, digits = 1;
  const DisplayFormat.norm2() : mode = DisplayMode.norm, digits = 2;

  /// [places] decimal places, 0..9.
  const DisplayFormat.fix(int places) : mode = DisplayMode.fix, digits = places;

  /// [significant] digits, 1..10; 0 means 10.
  const DisplayFormat.sci(int significant)
    : mode = DisplayMode.sci,
      digits = significant;

  final DisplayMode mode;

  /// Norm: 1 or 2. Fix: decimal places. Sci: significant digits (0 = 10).
  final int digits;

  @override
  String toString() => switch (mode) {
    DisplayMode.norm => 'Norm $digits',
    DisplayMode.fix => 'Fix $digits',
    DisplayMode.sci => 'Sci $digits',
  };
}

/// What the result line shows: mantissa and optional 2-digit exponent (`"-03"`).
class FormattedNumber {
  const FormattedNumber(this.mantissa, [this.exponent]);

  final String mantissa;
  final String? exponent;
}

/// Total digit positions on the result line (excluding sign and exponent).
const int displayDigits = 10;

FormattedNumber formatNumber(Dec value, DisplayFormat format) {
  switch (format.mode) {
    case DisplayMode.sci:
      return _exponential(
        value,
        format.digits == 0 ? displayDigits : format.digits,
        keepZeros: true,
      );
    case DisplayMode.fix:
      final rounded = value.roundDecimals(format.digits);
      // TODO(device): verify what Fix shows when integer digits + places > 10.
      if (rounded.abs().exponent10 >= displayDigits && !rounded.isZero) {
        return _exponential(value, displayDigits, keepZeros: false);
      }
      return FormattedNumber(_fixed(rounded, format.digits, keepZeros: true));
    case DisplayMode.norm:
      if (value.isZero) return const FormattedNumber('0.');
      final lowerLimit = format.digits == 1 ? -2 : -9;
      final r = value.roundSignificant(displayDigits);
      if (r.exponent10 >= displayDigits || r.exponent10 < lowerLimit) {
        return _exponential(value, displayDigits, keepZeros: false);
      }
      final places = displayDigits - (r.exponent10 < 0 ? 1 : r.exponent10 + 1);
      final fixed = value.roundDecimals(places);
      if (fixed.abs().exponent10 >= displayDigits) {
        return _exponential(value, displayDigits, keepZeros: false);
      }
      return FormattedNumber(_fixed(fixed, places, keepZeros: false));
  }
}

FormattedNumber _exponential(
  Dec value,
  int significant, {
  required bool keepZeros,
}) {
  var r = value.roundSignificant(significant);
  final e = r.isZero ? 0 : r.exponent10;
  // Mantissa = r / 10^e, exact because r has <= significant digits.
  final mantissa = Dec(r.coefficient, r.exponent - e);
  final exp = '${e < 0 ? '-' : ''}${e.abs().toString().padLeft(2, '0')}';
  return FormattedNumber(
    _fixed(mantissa, significant - 1, keepZeros: keepZeros),
    exp,
  );
}

/// [value] already rounded to [places] decimals.
String _fixed(Dec value, int places, {required bool keepZeros}) {
  final sign = value.isNegative ? '-' : '';
  final abs = value.abs();
  final scaled = abs.isZero
      ? BigInt.zero
      : abs.coefficient * BigInt.from(10).pow(abs.exponent + places);
  var digits = scaled.toString().padLeft(places + 1, '0');
  final intPart = digits.substring(0, digits.length - places);
  var frac = digits.substring(digits.length - places);
  if (!keepZeros) frac = frac.replaceFirst(RegExp(r'0+$'), '');
  return '$sign$intPart.$frac';
}
