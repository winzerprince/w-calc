import 'dec.dart';
import 'frac.dart';

/// A calculation value: always a 15-digit [dec]; additionally exact [frac]
/// when it came from fraction input, or flagged [isSexagesimal] when it came
/// from degree/minute/second input. These flags only change how results are
/// shown and how fractions combine (manual: mixing fractions with decimals
/// gives decimals).
final class Value {
  Value.dec(this.dec) : frac = null, isSexagesimal = false;

  Value.frac(Frac f) : frac = f, dec = f.toDec(), isSexagesimal = false;

  Value.sexagesimal(this.dec) : frac = null, isSexagesimal = true;

  static final zero = Value.dec(Dec.zero);

  final Dec dec;
  final Frac? frac;
  final bool isSexagesimal;

  /// Fraction view of this value if it may take part in exact arithmetic:
  /// fractions, and integers (an integer combined with a fraction stays a fraction).
  Frac? get _exact =>
      frac ?? (dec.isInteger && !isSexagesimal ? Frac.fromDec(dec) : null);

  Value _combine(
    Value o,
    Frac Function(Frac, Frac) exact,
    Dec Function(Dec, Dec) approx, {
    required bool sexagesimal,
  }) {
    if (frac != null || o.frac != null) {
      final a = _exact, b = o._exact;
      if (a != null && b != null) return Value.frac(exact(a, b));
    }
    final r = approx(dec, o.dec);
    return sexagesimal ? Value.sexagesimal(r) : Value.dec(r);
  }

  Value operator +(Value o) => _combine(
    o,
    (a, b) => a + b,
    (a, b) => a + b,
    sexagesimal: isSexagesimal && o.isSexagesimal,
  );

  Value operator -(Value o) => _combine(
    o,
    (a, b) => a - b,
    (a, b) => a - b,
    sexagesimal: isSexagesimal && o.isSexagesimal,
  );

  Value operator *(Value o) => _combine(
    o,
    (a, b) => a * b,
    (a, b) => a * b,
    sexagesimal: isSexagesimal != o.isSexagesimal,
  );

  Value operator /(Value o) => _combine(
    o,
    (a, b) => a / b,
    (a, b) => a / b,
    sexagesimal: isSexagesimal && !o.isSexagesimal,
  );

  Value operator -() => frac != null
      ? Value.frac(-frac!)
      : (isSexagesimal ? Value.sexagesimal(-dec) : Value.dec(-dec));

  /// Exact integer power of a fraction, or null when not a fraction.
  Value? powInt(int e) => frac == null ? null : Value.frac(frac!.pow(e));

  @override
  String toString() =>
      frac != null ? 'Value($frac)' : 'Value($dec${isSexagesimal ? '°' : ''})';
}
