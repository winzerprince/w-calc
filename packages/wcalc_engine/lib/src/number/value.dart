import '../angle_unit.dart';
import 'dec.dart';
import 'frac.dart';
import 'functions.dart';
import 'linalg.dart';
import 'surd.dart';
import 'wide.dart';

/// A calculation value: always a 15-digit [dec]; additionally exact [frac]
/// when it came from fraction input, or flagged [isSexagesimal] when it came
/// from degree/minute/second input. These flags only change how results are
/// shown and how fractions combine (manual: mixing fractions with decimals
/// gives decimals).
final class Value {
  Value.dec(this.dec)
    : frac = null,
      isSexagesimal = false,
      imag = Dec.zero,
      matrix = null,
      vector = null,
      surd = null,
      piCoef = null;

  /// MAT mode matrix (1-3 × 1-3).
  Value.matrix(Mat m)
    : matrix = m,
      vector = null,
      dec = Dec.zero,
      frac = null,
      isSexagesimal = false,
      imag = Dec.zero,
      surd = null,
      piCoef = null;

  /// VCT mode vector (2 or 3 elements).
  Value.vector(Vec v)
    : vector = v,
      matrix = null,
      dec = Dec.zero,
      frac = null,
      isSexagesimal = false,
      imag = Dec.zero,
      surd = null,
      piCoef = null;

  Value.frac(Frac f)
    : frac = f,
      dec = f.toDec(),
      isSexagesimal = false,
      imag = Dec.zero,
      matrix = null,
      vector = null,
      surd = null,
      piCoef = null;

  Value.sexagesimal(this.dec)
    : frac = null,
      isSexagesimal = true,
      imag = Dec.zero,
      matrix = null,
      vector = null,
      surd = null,
      piCoef = null;

  /// re + im·i (CMPLX mode). [dec] is the real part.
  Value.complex(this.dec, this.imag)
    : frac = null,
      isSexagesimal = false,
      matrix = null,
      vector = null,
      surd = null,
      piCoef = null;

  /// r∠θ with θ in [unit].
  factory Value.polar(Dec r, Dec theta, AngleUnit unit) {
    final (x, y) = rectangularDec(r.abs(), theta, unit);
    return r.isNegative ? Value.complex(-x, -y) : Value.complex(x, y);
  }

  /// Exact √ form (textbook-display models). Rational results become
  /// [Value.frac] instead.
  Value.surd(Surd s)
    : surd = s,
      piCoef = null,
      dec = s.toDec(),
      frac = null,
      isSexagesimal = false,
      imag = Dec.zero,
      matrix = null,
      vector = null;

  /// Exact multiple of π (textbook-display models).
  Value.pi(Frac k)
    : piCoef = k,
      surd = null,
      dec = (Wide.fromDec(k.toDec()) * Wide.fromDec(piConstant)).toDec(),
      frac = null,
      isSexagesimal = false,
      imag = Dec.zero,
      matrix = null,
      vector = null;

  /// Exact value from a surd: a fraction when it is rational.
  static Value fromSurd(Surd s) =>
      s.isRational ? Value.frac(s.rationalPart) : Value.surd(s);

  static final imaginaryUnit = Value.complex(Dec.zero, Dec.one);

  static final zero = Value.dec(Dec.zero);

  final Dec dec;
  final Frac? frac;
  final bool isSexagesimal;

  /// Imaginary part (zero for real values).
  final Dec imag;

  final Mat? matrix;
  final Vec? vector;

  /// Exact √ form, or null.
  final Surd? surd;

  /// Exact value is piCoef·π, or null.
  final Frac? piCoef;

  /// This value as a surd when it is exact (rational or √ form).
  Surd? get _asSurd {
    if (surd != null) return surd;
    final e = _exact;
    return e == null ? null : Surd.rational(e);
  }

  /// Exact arithmetic on √ and π forms; null when it does not apply.
  Value? _symbolic(Value o, int op) {
    if (surd != null || o.surd != null) {
      final a = _asSurd, b = o._asSurd;
      if (a == null || b == null) return null;
      final r = switch (op) {
        0 => a + b,
        1 => a - b,
        2 => a * b,
        _ => b.isRational && b.rationalPart.n == BigInt.zero ? null : a / b,
      };
      return r == null ? null : fromSurd(r);
    }
    if (piCoef != null || o.piCoef != null) {
      final ea = _exact, eb = o._exact;
      final pa = piCoef, pb = o.piCoef;
      switch (op) {
        case 0 || 1:
          if (pa != null && pb != null) {
            final k = op == 0 ? pa + pb : pa - pb;
            return k.n == BigInt.zero ? Value.frac(k) : Value.pi(k);
          }
        case 2:
          if (pa != null && eb != null) return _piOrZero(pa * eb);
          if (pb != null && ea != null) return _piOrZero(pb * ea);
        default:
          if (pa != null && eb != null && eb.n != BigInt.zero) {
            return _piOrZero(pa / eb);
          }
          if (pa != null && pb != null) return Value.frac(pa / pb);
      }
    }
    return null;
  }

  static Value _piOrZero(Frac k) =>
      k.n == BigInt.zero ? Value.frac(k) : Value.pi(k);

  bool get isMatrix => matrix != null;
  bool get isVector => vector != null;

  /// Matrix or vector (MAT / VCT values).
  bool get isLinear => matrix != null || vector != null;

  /// +, −, ×, ÷ when a matrix or vector is involved (op 0-3).
  Value _linearOp(Value o, int op) {
    Never bad() => throw const CalcError(CalcErrorKind.math);
    final (a, b) = (this, o);
    if (a.isMatrix && b.isMatrix) {
      return Value.matrix(switch (op) {
        0 => matAdd(a.matrix!, b.matrix!),
        1 => matSub(a.matrix!, b.matrix!),
        2 => matMul(a.matrix!, b.matrix!),
        _ => bad(),
      });
    }
    if (a.isVector && b.isVector) {
      return Value.vector(switch (op) {
        0 => vecAdd(a.vector!, b.vector!),
        1 => vecSub(a.vector!, b.vector!),
        2 => vecCross(a.vector!, b.vector!),
        _ => bad(),
      });
    }
    if (a.isLinear && b.isLinear) throw const CalcError(CalcErrorKind.dim);
    final linear = a.isLinear ? a : b;
    final scalar = a.isLinear ? b : a;
    if (scalar.isComplex) bad();
    final Dec k;
    if (op == 2) {
      k = scalar.dec;
    } else if (op == 3 && a.isLinear) {
      k = Dec.one / scalar.dec;
    } else {
      bad();
    }
    return linear.isMatrix
        ? Value.matrix(matScale(linear.matrix!, k))
        : Value.vector(vecScale(linear.vector!, k));
  }

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

  /// Fraction bar of the textbook display: exact when both sides are
  /// integers or fractions, otherwise ordinary division.
  Value fractionOver(Value o) {
    if (!isLinear && !o.isLinear && !isComplex && !o.isComplex) {
      final a = _exact, b = o._exact;
      if (a != null && b != null) {
        if (b.n == BigInt.zero) throw const CalcError(CalcErrorKind.math);
        return Value.frac(a / b);
      }
    }
    return this / o;
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

  Value operator +(Value o) => isLinear || o.isLinear
      ? _linearOp(o, 0)
      : isComplex || o.isComplex
      ? _complexOp(o, 0)
      : _symbolic(o, 0) ??
            _combine(
              o,
              (a, b) => a + b,
              (a, b) => a + b,
              sexagesimal: isSexagesimal && o.isSexagesimal,
            );

  Value operator -(Value o) => isLinear || o.isLinear
      ? _linearOp(o, 1)
      : isComplex || o.isComplex
      ? _complexOp(o, 1)
      : _symbolic(o, 1) ??
            _combine(
              o,
              (a, b) => a - b,
              (a, b) => a - b,
              sexagesimal: isSexagesimal && o.isSexagesimal,
            );

  Value operator *(Value o) => isLinear || o.isLinear
      ? _linearOp(o, 2)
      : isComplex || o.isComplex
      ? _complexOp(o, 2)
      : _symbolic(o, 2) ??
            _combine(
              o,
              (a, b) => a * b,
              (a, b) => a * b,
              sexagesimal: isSexagesimal != o.isSexagesimal,
            );

  Value operator /(Value o) => isLinear || o.isLinear
      ? _linearOp(o, 3)
      : isComplex || o.isComplex
      ? _complexOp(o, 3)
      : _symbolic(o, 3) ??
            _combine(
              o,
              (a, b) => a / b,
              (a, b) => a / b,
              sexagesimal: isSexagesimal && !o.isSexagesimal,
            );

  Value operator -() => isMatrix
      ? Value.matrix(matNeg(matrix!))
      : isVector
      ? Value.vector(vecNeg(vector!))
      : isComplex
      ? Value.complex(-dec, -imag)
      : frac != null
      ? Value.frac(-frac!)
      : surd != null
      ? Value.surd(-surd!)
      : piCoef != null
      ? Value.pi(-piCoef!)
      : (isSexagesimal ? Value.sexagesimal(-dec) : Value.dec(-dec));

  /// Exact integer power of a fraction or complex value, else null.
  Value? powInt(int e) {
    if (isVector) throw const CalcError(CalcErrorKind.math);
    if (isMatrix) {
      if (e == -1) return Value.matrix(matInverse(matrix!));
      if (e < 1) throw const CalcError(CalcErrorKind.math);
      var r = matrix!;
      for (var i = 1; i < e; i++) {
        r = matMul(r, matrix!);
      }
      return Value.matrix(r);
    }
    if (frac != null) return Value.frac(frac!.pow(e));
    if (surd != null && e >= 1 && e <= 3) {
      Surd? r = surd!;
      for (var i = 1; i < e && r != null; i++) {
        r = r * surd!;
      }
      if (r != null) return fromSurd(r);
    }
    if (surd != null && e == -1) {
      final r = Surd.rational(Frac.fromInt(BigInt.one)) / surd!;
      if (r != null) return fromSurd(r);
    }
    if (!isComplex) return null;
    var result = Value.complex(Dec.one, Dec.zero);
    for (var i = 0; i < e.abs(); i++) {
      result = result * this;
    }
    return e < 0 ? Value.dec(Dec.one) / result : result;
  }

  @override
  String toString() => isLinear
      ? 'Value(${matrix ?? vector})'
      : isComplex
      ? 'Value($dec + ${imag}i)'
      : frac != null
      ? 'Value($frac)'
      : 'Value($dec${isSexagesimal ? '°' : ''})';
}
