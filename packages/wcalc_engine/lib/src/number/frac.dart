import 'dec.dart';

/// Exact fraction n/d (d > 0, reduced). Used for a b/c input and results.
final class Frac {
  factory Frac(BigInt n, BigInt d) {
    if (d == BigInt.zero) throw const CalcError(CalcErrorKind.math);
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    return g > BigInt.one ? Frac._(n ~/ g, d ~/ g) : Frac._(n, d);
  }

  Frac._(this.n, this.d);

  factory Frac.fromInt(BigInt v) => Frac._(v, BigInt.one);

  /// Exact value of a terminating decimal.
  factory Frac.fromDec(Dec x) => x.exponent >= 0
      ? Frac.fromInt(x.coefficient * BigInt.from(10).pow(x.exponent))
      : Frac(x.coefficient, BigInt.from(10).pow(-x.exponent));

  final BigInt n;
  final BigInt d;

  bool get isInteger => d == BigInt.one;
  bool get isNegative => n.isNegative;

  Frac operator -() => Frac._(-n, d);
  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d);
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d);
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d);
  Frac operator /(Frac o) => Frac(n * o.d, d * o.n);

  Frac pow(int e) {
    if (e < 0) return Frac(d.pow(-e), n.pow(-e));
    return Frac._(n.pow(e), d.pow(e));
  }

  /// 15-digit decimal value (Math ERROR if out of range).
  Dec toDec() => Dec(n, 0) / Dec(d, 0);

  /// Mixed form (whole, numerator, denominator); the sign is on the first
  /// non-zero part: −5/3 → (−1, 2, 3), −1/3 → (0, −1, 3).
  (BigInt, BigInt, BigInt) get mixed {
    final whole = n.abs() ~/ d;
    final rest = n.abs() % d;
    if (!isNegative) return (whole, rest, d);
    return whole == BigInt.zero ? (whole, -rest, d) : (-whole, rest, d);
  }

  /// The simplest fraction equal to [x] at 15 significant digits (continued
  /// fractions), or null if none fits the 10-digit display.
  static Frac? approximate(Dec x) {
    if (x.isInteger) return Frac.fromDec(x);
    final exact = Frac.fromDec(x);
    var (h0, h1) = (BigInt.zero, BigInt.one);
    var (k0, k1) = (BigInt.one, BigInt.zero);
    var rem = exact.abs();
    for (var i = 0; i < 40; i++) {
      final a = rem.n ~/ rem.d;
      (h0, h1) = (h1, a * h1 + h0);
      (k0, k1) = (k1, a * k1 + k0);
      final candidate = Frac(exact.isNegative ? -h1 : h1, k1);
      if (_digits(candidate) > 10) return null;
      if (candidate.toDec() == x) return candidate;
      final frac = rem - Frac.fromInt(a);
      if (frac.n == BigInt.zero) return null;
      rem = Frac(frac.d, frac.n);
    }
    return null;
  }

  Frac abs() => isNegative ? -this : this;

  /// Digits the display needs for this fraction in mixed form, including
  /// separators (manual: more than 10 → shown as decimal).
  static int _digits(Frac f) {
    final (w, r, d) = f.mixed;
    final parts = [if (w != BigInt.zero) w.abs(), r.abs(), d];
    return parts.fold<int>(0, (s, p) => s + p.toString().length) +
        parts.length -
        1;
  }

  /// See [_digits]; [improper] counts n⌟d instead of the mixed form.
  int displayDigits({required bool improper}) => improper
      ? n.abs().toString().length + d.toString().length + 1
      : _digits(this);

  @override
  bool operator ==(Object other) =>
      other is Frac && other.n == n && other.d == d;

  @override
  int get hashCode => Object.hash(n, d);

  @override
  String toString() => '$n/$d';
}
