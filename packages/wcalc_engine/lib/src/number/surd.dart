import 'dec.dart';
import 'frac.dart';
import 'wide.dart';

/// Exact value Σ cᵢ·√bᵢ: rational coefficients, square-free radicands
/// (b = 1 is the rational part). Textbook-display models keep √ results
/// exact with it (√2 × √3 = √6, (1 + √5)/2 …).
final class Surd {
  Surd._(this.terms);

  /// Normalises: drops zero coefficients. Returns null when the value would
  /// get too complex to show (more than [maxTerms] terms or a huge radicand).
  static Surd? of(Map<BigInt, Frac> terms) {
    final t = <BigInt, Frac>{
      for (final e in terms.entries)
        if (e.value.n != BigInt.zero) e.key: e.value,
    };
    if (t.length > maxTerms) return null;
    if (t.keys.any((b) => b > _maxRadicand)) return null;
    return Surd._(Map.unmodifiable(t));
  }

  static const maxTerms = 3;
  static final _maxRadicand = BigInt.from(1000000);

  final Map<BigInt, Frac> terms;

  static Surd rational(Frac f) => Surd._({BigInt.one: f});

  /// √f for a rational f ≥ 0: √(n/d) = √(n·d)/d, squares pulled out.
  static Surd? sqrtOf(Frac f) {
    if (f.isNegative) return null;
    if (f.n == BigInt.zero) return rational(f);
    final (s, b) = _splitSquare(f.n * f.d);
    if (s == null) return null;
    return of({b: Frac(s, f.d)});
  }

  /// m = s²·b with b square-free (trial division; null if m is too big).
  static (BigInt?, BigInt) _splitSquare(BigInt m) {
    if (m > BigInt.from(10).pow(12)) return (null, m);
    var s = BigInt.one, b = BigInt.one, rest = m;
    for (var p = BigInt.two; p * p <= rest; p += BigInt.one) {
      var k = 0;
      while (rest % p == BigInt.zero) {
        rest ~/= p;
        k++;
      }
      s *= p.pow(k ~/ 2);
      if (k.isOdd) b *= p;
    }
    b *= rest;
    return (s, b);
  }

  bool get isRational =>
      terms.isEmpty || (terms.length == 1 && terms.containsKey(BigInt.one));

  Frac get rationalPart => terms[BigInt.one] ?? Frac.fromInt(BigInt.zero);

  /// Irrational terms (radicand > 1), radicands ascending.
  List<(BigInt, Frac)> get radicals => [
    for (final b in terms.keys.toList()..sort())
      if (b != BigInt.one) (b, terms[b]!),
  ];

  Surd? operator +(Surd o) {
    final t = Map<BigInt, Frac>.of(terms);
    for (final e in o.terms.entries) {
      t[e.key] = (t[e.key] ?? Frac.fromInt(BigInt.zero)) + e.value;
    }
    return of(t);
  }

  Surd operator -() => Surd._({for (final e in terms.entries) e.key: -e.value});

  Surd? operator -(Surd o) => this + -o;

  Surd? operator *(Surd o) {
    final t = <BigInt, Frac>{};
    for (final a in terms.entries) {
      for (final b in o.terms.entries) {
        // √a·√b = g·√(ab/g²) with g = gcd(a, b) (both square-free).
        final g = a.key.gcd(b.key);
        final r = (a.key ~/ g) * (b.key ~/ g);
        final c = a.value * b.value * Frac.fromInt(g);
        t[r] = (t[r] ?? Frac.fromInt(BigInt.zero)) + c;
      }
    }
    return of(t);
  }

  /// Division by a single-term value (c√b); null otherwise.
  Surd? operator /(Surd o) {
    if (o.terms.length != 1) return null;
    final MapEntry(key: b, value: c) = o.terms.entries.single;
    if (c.n == BigInt.zero) return null;
    // x / (c√b) = x · √b / (c·b)
    final inv = Surd._({b: Frac(c.d, c.n * b)});
    return this * inv;
  }

  /// 15-digit decimal value.
  Dec toDec() {
    var sum = Wide.zero;
    for (final e in terms.entries) {
      final c =
          Wide.fromDec(Dec(e.value.n, 0)) / Wide.fromDec(Dec(e.value.d, 0));
      final r = e.key == BigInt.one
          ? Wide.one
          : WideMath.sqrt(Wide.fromDec(Dec(e.key, 0)));
      sum = sum + c * r;
    }
    return sum.toDec();
  }

  @override
  bool operator ==(Object other) =>
      other is Surd &&
      other.terms.length == terms.length &&
      terms.entries.every((e) => other.terms[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    terms.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => [
    for (final b in terms.keys.toList()..sort())
      b == BigInt.one ? '${terms[b]}' : '${terms[b]}√$b',
  ].join(' + ');
}
