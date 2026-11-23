import '../number/dec.dart';
import '../number/frac.dart';
import '../number/functions.dart';
import '../number/surd.dart';
import '../number/value.dart';
import '../number/wide.dart';

/// Exact ways a textbook-display result can be shown.
sealed class ExactForm {
  const ExactForm();
}

/// p/q (mixed or improper per setup).
final class FractionForm extends ExactForm {
  const FractionForm(this.value);
  final Frac value;
}

/// (n₀ + n₁√b₁ + n₂√b₂) / d.
final class SurdForm extends ExactForm {
  const SurdForm(this.value);
  final Surd value;
}

/// (p/q)·π.
final class PiForm extends ExactForm {
  const PiForm(this.coefficient);
  final Frac coefficient;
}

/// Display limits (our reading of the device: two-digit coefficients and
/// denominators, three-digit radicands; π form below 10⁶).
const _maxCoef = 99;
const _maxDen = 99;
final _maxRadicand = BigInt.from(999);
final _piLimit = Dec.parse('1e6');

/// The exact form for [v], or null to show a decimal. [surd] / [pi] allow
/// those forms (after SHIFT =, S⇔D offers fractions and π forms only).
ExactForm? exactFormOf(Value v, {bool surd = true, bool pi = true}) {
  if (v.isComplex || v.isLinear || v.isSexagesimal) return null;
  if (v.dec.isInteger && v.surd == null && v.piCoef == null) return null;
  final f = v.frac;
  if (f != null) return _fits(f) ? FractionForm(f) : null;
  final s = v.surd;
  if (s != null) return surd && _surdFits(s) ? SurdForm(s) : null;
  final k = v.piCoef;
  if (k != null) return pi && _piFits(k, v.dec) ? PiForm(k) : null;
  return _recognise(v.dec, surd: surd, pi: pi);
}

bool _fits(Frac f) => Frac.approximate(f.toDec()) == f;

bool _surdFits(Surd s) {
  final d = _commonDenominator(s);
  if (d > BigInt.from(_maxDen)) return false;
  for (final e in s.terms.entries) {
    if (e.key > _maxRadicand) return false;
    final n = (e.value * Frac.fromInt(d)).n.abs();
    if (n > BigInt.from(_maxCoef)) return false;
  }
  return true;
}

BigInt _commonDenominator(Surd s) =>
    s.terms.values.fold(BigInt.one, (l, c) => l * c.d ~/ l.gcd(c.d));

bool _piFits(Frac k, Dec x) =>
    x.abs() < _piLimit &&
    k.n.abs() <= BigInt.from(999) &&
    k.d <= BigInt.from(999);

/// Finds a simple exact form close to a 15-digit decimal (function results
/// such as sin 45° = √2/2 or sin⁻¹ 1 = π/2 in Rad).
ExactForm? _recognise(Dec x, {required bool surd, required bool pi}) {
  final f = Frac.approximate(x);
  if (f != null) return FractionForm(f);
  if (pi) {
    final k = _close(Wide.fromDec(x) / Wide.fromDec(piConstant), 999);
    if (k != null && _piFits(k, x)) return PiForm(k);
  }
  if (surd) {
    // x = ±a√b/c  ⇔  x² = a²b/c² is a simple fraction.
    final wx = Wide.fromDec(x);
    final sq = _close(wx * wx, 999999);
    if (sq != null && !sq.isNegative) {
      final s = Surd.sqrtOf(sq);
      if (s != null && !s.isRational && s.terms.length == 1) {
        final signed = x.isNegative ? -s : s;
        if (_surdFits(signed)) return SurdForm(signed);
      }
    }
  }
  return null;
}

/// Continued-fraction approximation within 1e-12 relative error and a
/// denominator ≤ [maxDen], or null.
Frac? _close(Wide x, int maxDen) {
  final target = x.toDec();
  if (target.isZero) return null;
  final neg = target.isNegative;
  var rem = Frac.fromDec(target.abs());
  var (h0, h1) = (BigInt.zero, BigInt.one);
  var (k0, k1) = (BigInt.one, BigInt.zero);
  final tol = Wide.fromDec(target.abs()) * Wide.fromDec(Dec.parse('1e-12'));
  for (var i = 0; i < 30; i++) {
    final a = rem.n ~/ rem.d;
    (h0, h1) = (h1, a * h1 + h0);
    (k0, k1) = (k1, a * k1 + k0);
    if (k1 > BigInt.from(maxDen)) return null;
    final cand = Frac(h1, k1);
    final diff = Wide.fromDec(cand.toDec()) - Wide.fromDec(target.abs());
    if (diff.abs() <= tol) return neg ? -cand : cand;
    final frac = rem - Frac.fromInt(a);
    if (frac.n == BigInt.zero) return null;
    rem = Frac(frac.d, frac.n);
  }
  return null;
}
