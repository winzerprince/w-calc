/// Scientific functions on [Dec] with the device's input ranges.
///
/// Every function: check domain (Math ERROR), compute in [Wide] precision,
/// round to 15 digits.
library;

import 'dart:math' as math;

import '../angle_unit.dart';
import 'dec.dart';
import 'wide.dart';

Never _mathError() => throw const CalcError(CalcErrorKind.math);

Wide _w(Dec d) => Wide.fromDec(d);
Wide _wi(int v) => Wide.fromInt(v);

/// The value the device uses for π (manual: 3.14159265358980).
final Dec piConstant = Dec.parse('3.14159265358980');

/// The value the device uses for e (manual: 2.71828182845904).
final Dec eConstant = Dec.parse('2.71828182845904');

// ---------------------------------------------------------------- angles

/// Units per full turn: 360°, 2π rad, 400 grad.
Wide _turn(AngleUnit u) => switch (u) {
  AngleUnit.deg => _wi(360),
  AngleUnit.rad => Wide.two * Wide.pi,
  AngleUnit.gra => _wi(400),
};

/// Converts [x] from unit [from] to unit [to].
Dec convertAngle(Dec x, AngleUnit from, AngleUnit to) {
  if (from == to) return x;
  return (_w(x) * _turn(to) / _turn(from)).toDec();
}

Wide _toRadians(Wide x, AngleUnit u) =>
    u == AngleUnit.rad ? x : x * Wide.two * Wide.pi / _turn(u);

Dec _fromRadians(Wide r, AngleUnit u) =>
    (u == AngleUnit.rad ? r : r * _turn(u) / (Wide.two * Wide.pi)).toDec();

/// Input limit for sin/cos/tan per unit (manual "Function Calculation Input Ranges").
bool _trigInRange(Dec x, AngleUnit u) {
  final a = x.abs();
  return switch (u) {
    AngleUnit.deg => a < Dec.parse('9e9'),
    AngleUnit.rad => a < Dec.parse('157079632.7'),
    AngleUnit.gra => a < Dec.parse('1e10'),
  };
}

/// Reduces x to (quadrant, remainder) where x = quadrant·(turn/4) + remainder
/// and the remainder is in radians, |remainder| <= turn/8.
/// Exact for Deg/Gra. In Rad, values within 1e-13 (relative) of a non-zero
/// multiple of π/2 snap to it, so sin π = 0 like the device.
(int, Wide) _reduce(Dec x, AngleUnit u) {
  final quarter = _turn(u) * Wide(BigInt.from(25), -2);
  final wx = _w(x);
  final k = (wx / quarter).round();
  var rem = wx - Wide(k, 0) * quarter;
  if (u == AngleUnit.rad && k != BigInt.zero) {
    final tolerance = wx.abs() * Wide(BigInt.one, -13);
    if (rem.abs() <= tolerance) rem = Wide.zero;
  }
  final quadrant = (k % BigInt.from(4)).toInt();
  return (quadrant, _toRadians(rem, u));
}

(Wide, Wide) _sinCos(Dec x, AngleUnit u) {
  if (!_trigInRange(x, u)) _mathError();
  final (q, r) = _reduce(x, u);
  final (s, c) = WideMath.sinCosSmall(r);
  return switch (q) {
    0 => (s, c),
    1 => (c, -s),
    2 => (-s, -c),
    _ => (-c, s),
  };
}

Dec sinDec(Dec x, AngleUnit u) => _sinCos(x, u).$1.toDec();

Dec cosDec(Dec x, AngleUnit u) => _sinCos(x, u).$2.toDec();

Dec tanDec(Dec x, AngleUnit u) {
  final (s, c) = _sinCos(x, u);
  if (c.isZero) _mathError();
  return (s / c).toDec();
}

Dec asinDec(Dec x, AngleUnit u) {
  final w = _w(x);
  if (w.abs() > Wide.one) _mathError();
  if (w.abs() == Wide.one) {
    return _fromRadians(Wide.pi * Wide.half * _wi(w.sign), u);
  }
  return _fromRadians(WideMath.atan(w / WideMath.sqrt(Wide.one - w * w)), u);
}

Dec acosDec(Dec x, AngleUnit u) {
  final w = _w(x);
  if (w.abs() > Wide.one) _mathError();
  final asin = w.abs() == Wide.one
      ? Wide.pi * Wide.half * _wi(w.sign)
      : WideMath.atan(w / WideMath.sqrt(Wide.one - w * w));
  return _fromRadians(Wide.pi * Wide.half - asin, u);
}

Dec atanDec(Dec x, AngleUnit u) => _fromRadians(WideMath.atan(_w(x)), u);

// ---------------------------------------------------------------- hyperbolic

final _hypLimit = Dec.parse('230.2585092');

/// Extra digits for arguments near zero, where exp-based formulas cancel.
int _guard(Wide x) => x.isZero ? 0 : (x.exponent10 < 0 ? -x.exponent10 + 2 : 0);

Dec sinhDec(Dec x) {
  if (x.abs() > _hypLimit) _mathError();
  final w = _w(x);
  return Wide.withPrecision(Wide.precision + _guard(w), () {
    final ex = WideMath.exp(w);
    return ((ex - Wide.one / ex) * Wide.half).toDec();
  });
}

Dec coshDec(Dec x) {
  if (x.abs() > _hypLimit) _mathError();
  final ex = WideMath.exp(_w(x));
  return ((ex + Wide.one / ex) * Wide.half).toDec();
}

Dec tanhDec(Dec x) {
  final w = _w(x);
  if (w.abs() > _wi(40)) {
    return Dec.fromInt(w.sign); // |tanh| rounds to 1 at 15 digits.
  }
  return Wide.withPrecision(Wide.precision + _guard(w), () {
    final e2 = WideMath.exp(Wide.two * w);
    return ((e2 - Wide.one) / (e2 + Wide.one)).toDec();
  });
}

Dec asinhDec(Dec x) {
  final w = _w(x);
  if (x.abs() >= Dec.parse('5e99')) _mathError();
  if (w.isZero) return Dec.zero;
  return Wide.withPrecision(Wide.precision + _guard(w), () {
    final a = w.abs();
    // For huge a, a² overflows nothing in Wide, so the formula is safe.
    final r = WideMath.ln(a + WideMath.sqrt(a * a + Wide.one));
    return (w.isNegative ? -r : r).toDec();
  });
}

Dec acoshDec(Dec x) {
  final w = _w(x);
  if (w < Wide.one || x >= Dec.parse('5e99')) _mathError();
  return WideMath.ln(w + WideMath.sqrt(w * w - Wide.one)).toDec();
}

Dec atanhDec(Dec x) {
  final w = _w(x);
  if (w.abs() >= Wide.one) _mathError();
  if (w.isZero) return Dec.zero;
  return Wide.withPrecision(Wide.precision + _guard(w), () {
    return (WideMath.ln((Wide.one + w) / (Wide.one - w)) * Wide.half).toDec();
  });
}

// ---------------------------------------------------------------- exp / log

Dec lnDec(Dec x) {
  if (x <= Dec.zero) _mathError();
  if (x == Dec.one) return Dec.zero;
  return WideMath.ln(_w(x)).toDec();
}

Dec logDec(Dec x) {
  if (x <= Dec.zero) _mathError();
  // Exact for powers of ten.
  if (x.coefficient == BigInt.one) return Dec.fromInt(x.exponent);
  return (WideMath.ln(_w(x)) / Wide.ln10).toDec();
}

Dec expDec(Dec x) {
  if (x > _hypLimit) _mathError();
  if (x < Dec.parse('-230.2585093')) return Dec.zero; // underflow
  return WideMath.exp(_w(x)).toDec();
}

Dec tenPowDec(Dec x) {
  if (x >= Dec.fromInt(100)) _mathError();
  if (x.isInteger) {
    if (x < Dec.fromInt(-99)) return Dec.zero;
    return Dec(BigInt.one, x.toInt());
  }
  if (x < Dec.fromInt(-100)) return Dec.zero;
  return WideMath.exp(_w(x) * Wide.ln10).toDec();
}

// ---------------------------------------------------------------- powers / roots

Dec sqrtDec(Dec x) {
  if (x.isNegative) _mathError();
  return WideMath.sqrt(_w(x)).toDec();
}

Dec cbrtDec(Dec x) {
  if (x.isZero) return Dec.zero;
  final w = _w(x).abs();
  // Newton on y³ = w from a double seed.
  var y = Wide.fromDouble(_cbrtSeed(w));
  for (var i = 0; i < 6; i++) {
    final next = (Wide.two * y + w / (y * y)) / Wide.fromInt(3);
    if (next == y) break;
    y = next;
  }
  final r = y.toDec();
  return x.isNegative ? -r : r;
}

double _cbrtSeed(Wide w) {
  final k = w.exponent10 - (w.exponent10 % 3);
  final m = Wide(w.c, w.e - k).toDouble();
  return math.pow(m, 1 / 3) * math.pow(10, k ~/ 3).toDouble();
}

Dec squareDec(Dec x) => x * x;

Dec cubeDec(Dec x) => x * x * x;

Dec reciprocalDec(Dec x) => Dec.one / x;

/// x^y with the device rules (manual input ranges for x^y).
Dec powDec(Dec x, Dec y) {
  if (x.isZero) {
    if (y > Dec.zero) return Dec.zero;
    _mathError();
  }
  if (y.isInteger) {
    final n = BigInt.parse(y.toString());
    return WideMath.powInt(_w(x), n).toDec();
  }
  if (x.isNegative) {
    // Allowed only when 1/y is an odd integer: (−8)^(1/3) = −2.
    final inv = (Wide.one / _w(y));
    final n = inv.round();
    final close = (inv - Wide(n, 0)).abs() < Wide(BigInt.one, -12);
    if (!close || n.isEven) _mathError();
    return -_positivePow(-x, y);
  }
  return _positivePow(x, y);
}

Dec _positivePow(Dec x, Dec y) {
  final l = WideMath.ln(_w(x)) * _w(y);
  if (l > Wide.parse('230.2585092994045684017991454684364207601')) _mathError();
  if (l < Wide.parse('-230.2585093')) return Dec.zero;
  return WideMath.exp(l).toDec();
}

/// x-th root of y (ˣ√y).
Dec xRootDec(Dec x, Dec y) {
  if (x.isZero) _mathError();
  if (y.isNegative) {
    if (!x.isInteger || x.toInt().isEven) _mathError();
    return -xRootDec(x, -y);
  }
  if (y.isZero) {
    if (x > Dec.zero) return Dec.zero;
    _mathError();
  }
  if (x == Dec.fromInt(2)) return sqrtDec(y);
  if (x == Dec.fromInt(3)) return cbrtDec(y);
  final l = WideMath.ln(_w(y)) / _w(x);
  return WideMath.exp(l).toDec();
}

// ---------------------------------------------------------------- combinatorics

BigInt _nonNegInt(Dec x, {int? max}) {
  if (x.isNegative || !x.isInteger) _mathError();
  final v = BigInt.parse(x.toString());
  if (max != null && v > BigInt.from(max)) _mathError();
  return v;
}

Dec factorialDec(Dec x) {
  final n = _nonNegInt(x, max: 69).toInt();
  var r = BigInt.one;
  for (var i = 2; i <= n; i++) {
    r *= BigInt.from(i);
  }
  return Dec(r, 0);
}

final _limit = BigInt.from(10).pow(100);
final _nMax = BigInt.from(10).pow(10);

(BigInt, BigInt) _nr(Dec n, Dec r) {
  final nn = _nonNegInt(n);
  final rr = _nonNegInt(r);
  if (nn >= _nMax || rr > nn) _mathError();
  return (nn, rr);
}

Dec permutationDec(Dec n, Dec r) {
  final (nn, rr) = _nr(n, r);
  var p = BigInt.one;
  for (var i = BigInt.zero; i < rr; i += BigInt.one) {
    p *= nn - i;
    if (p >= _limit) _mathError();
  }
  return Dec(p, 0);
}

Dec combinationDec(Dec n, Dec r) {
  final (nn, rr0) = _nr(n, r);
  final rr = rr0 > nn - rr0 ? nn - rr0 : rr0;
  var c = BigInt.one;
  for (var i = BigInt.zero; i < rr; i += BigInt.one) {
    c = c * (nn - i) ~/ (i + BigInt.one);
    if (c >= _limit) _mathError();
  }
  return Dec(c, 0);
}
