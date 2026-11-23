import '../angle_unit.dart';
import 'dec.dart';
import 'frac.dart';
import 'functions.dart';
import 'wide.dart';

/// A calculation value: always a 15-digit [dec]; additionally exact [frac]
/// when it came from fraction input, or flagged [isSexagesimal] when it came
/// from degree/minute/second input. These flags only change how results are
/// shown and how fractions combine (manual: mixing fractions with decimals
/// gives decimals).
final class Value {
  Value.dec(this.dec) : frac = null, isSexagesimal = false, imag = Dec.zero;

  Value.frac(Frac f)
    : frac = f,
      dec = f.toDec(),
      isSexagesimal = false,
      imag = Dec.zero;

  Value.sexagesimal(this.dec)
    : frac = null,
      isSexagesimal = true,
      imag = Dec.zero;

  /// re + im·i (CMPLX mode). [dec] is the real part.
  Value.complex(this.dec, this.imag) : frac = null, isSexagesimal = false;

  /// r∠θ with θ in [unit].
  factory Value.polar(Dec r, Dec theta, AngleUnit unit) {
    final (x, y) = rectangularDec(r.abs(), theta, unit);
    return r.isNegative ? Value.complex(-x, -y) : Value.complex(x, y);
  }

  static final imaginaryUnit = Value.complex(Dec.zero, Dec.one);

  static final zero = Value.dec(Dec.zero);

  final Dec dec;
  final Frac? frac;
  final bool isSexagesimal;

  /// Imaginary part (zero for real values).
  final Dec imag;

  bool get isComplex => !imag.isZero;

  /// |z|.
  Dec magnitude() {
    if (!isComplex) return dec.abs();
    final x = Wide.fromDec(dec), y = Wide.fromDec(imag);
    return WideMath.sqrt(x * x + y * y).toDec();
  }

  /// arg z in [unit], in (−180°, 180°].
  Dec argument(AngleUnit unit) => polarDec(dec, imag, unit).$2;

  Value conjugate() => Value.complex(dec, -imag);

  Value _complexOp(Value o, int op) {
    final a = Wide.fromDec(dec), b = Wide.fromDec(imag);
    final c = Wide.fromDec(o.dec), d = Wide.fromDec(o.imag);
    final (Wide re, Wide im) = switch (op) {
      0 => (a + c, b + d),
      1 => (a - c, b - d),
      2 => (a * c - b * d, a * d + b * c),
      _ => () {
        final den = c * c + d * d;
        if (den.isZero) throw const CalcError(CalcErrorKind.math);
        return ((a * c + b * d) / den, (b * c - a * d) / den);
      }(),
    };
    return Value.complex(re.toDec(), im.toDec());
  }

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

  Value operator +(Value o) => isComplex || o.isComplex
      ? _complexOp(o, 0)
      : _combine(
          o,
          (a, b) => a + b,
          (a, b) => a + b,
          sexagesimal: isSexagesimal && o.isSexagesimal,
        );

  Value operator -(Value o) => isComplex || o.isComplex
      ? _complexOp(o, 1)
      : _combine(
          o,
          (a, b) => a - b,
          (a, b) => a - b,
          sexagesimal: isSexagesimal && o.isSexagesimal,
        );

  Value operator *(Value o) => isComplex || o.isComplex
      ? _complexOp(o, 2)
      : _combine(
          o,
          (a, b) => a * b,
          (a, b) => a * b,
          sexagesimal: isSexagesimal != o.isSexagesimal,
        );

  Value operator /(Value o) => isComplex || o.isComplex
      ? _complexOp(o, 3)
      : _combine(
          o,
          (a, b) => a / b,
          (a, b) => a / b,
          sexagesimal: isSexagesimal && !o.isSexagesimal,
        );

  Value operator -() => isComplex
      ? Value.complex(-dec, -imag)
      : frac != null
      ? Value.frac(-frac!)
      : (isSexagesimal ? Value.sexagesimal(-dec) : Value.dec(-dec));

  /// Exact integer power of a fraction or complex value, else null.
  Value? powInt(int e) {
    if (frac != null) return Value.frac(frac!.pow(e));
    if (!isComplex) return null;
    var result = Value.complex(Dec.one, Dec.zero);
    for (var i = 0; i < e.abs(); i++) {
      result = result * this;
    }
    return e < 0 ? Value.dec(Dec.one) / result : result;
  }

  @override
  String toString() => isComplex
      ? 'Value($dec + ${imag}i)'
      : frac != null
      ? 'Value($frac)'
      : 'Value($dec${isSexagesimal ? '°' : ''})';
}
