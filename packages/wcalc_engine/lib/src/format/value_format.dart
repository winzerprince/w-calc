import '../number/dec.dart';
import '../number/frac.dart';
import '../number/value.dart';
import 'number_format.dart';

/// Setup that affects how results look (setup menu Fix/Sci/Norm and Disp).
class DisplaySettings {
  const DisplaySettings({
    this.format = const DisplayFormat.norm1(),
    this.engOn = false,
    this.improperFractions = false,
    this.decimalComma = false,
    this.polarComplex = false,
    this.leadingZeroCounts = true,
  });

  /// See [formatNumber]: false on textbook-display models.
  final bool leadingZeroCounts;

  final DisplayFormat format;

  /// EngON: results use engineering symbols (k, m, μ …).
  final bool engOn;

  /// d/c: fractions shown improper (11⌟4) instead of mixed (2⌟3⌟4).
  final bool improperFractions;

  /// Comma: decimal comma and period group separator.
  final bool decimalComma;

  /// CMPLX results as r∠θ instead of a+bi.
  final bool polarComplex;

  DisplaySettings copyWith({
    DisplayFormat? format,
    bool? engOn,
    bool? improperFractions,
    bool? decimalComma,
    bool? polarComplex,
  }) => DisplaySettings(
    format: format ?? this.format,
    engOn: engOn ?? this.engOn,
    improperFractions: improperFractions ?? this.improperFractions,
    decimalComma: decimalComma ?? this.decimalComma,
    polarComplex: polarComplex ?? this.polarComplex,
    leadingZeroCounts: leadingZeroCounts,
  );
}

/// How the shown result is being viewed after conversion keys.
enum ResultView { auto, decimal, fraction, sexagesimal }

/// Fraction separator on the display.
const fractionMark = '┘';

/// Engineering symbols by exponent (manual p.24).
const engSymbols = {
  12: 'T',
  9: 'G',
  6: 'M',
  3: 'k',
  -3: 'm',
  -6: 'μ',
  -9: 'n',
  -12: 'p',
  -15: 'f',
};

/// Largest multiple of 3 not above floor(log10|x|).
int engExponentFor(Dec x) {
  if (x.isZero) return 0;
  final e = x.exponent10;
  return e - (e % 3);
}

FormattedNumber formatValue(
  Value v,
  DisplaySettings s, {
  ResultView view = ResultView.auto,
  int? engExponent,
}) {
  if (engExponent != null) return _eng(v.dec, engExponent, s.engOn);
  switch (view) {
    case ResultView.fraction:
      final f = v.frac ?? Frac.approximate(v.dec);
      if (f != null) return _fraction(f, s, v.dec);
    case ResultView.sexagesimal:
      return _sexagesimal(v.dec, s);
    case ResultView.auto:
      if (v.frac != null) return _fraction(v.frac!, s, v.dec);
      if (v.isSexagesimal) return _sexagesimal(v.dec, s);
    case ResultView.decimal:
      break;
  }
  return _decimal(v.dec, s);
}

FormattedNumber _decimal(Dec x, DisplaySettings s) {
  if (s.engOn && !x.isZero) {
    final e = engExponentFor(x);
    if (engSymbols.containsKey(e)) return _eng(x, e, true);
  }
  return formatNumber(x, s.format, leadingZeroCounts: s.leadingZeroCounts);
}

FormattedNumber _fraction(Frac f, DisplaySettings s, Dec fallback) {
  if (f.isInteger ||
      f.displayDigits(improper: s.improperFractions) > displayDigits) {
    return _decimal(fallback, s);
  }
  if (s.improperFractions) {
    return FormattedNumber('${f.n}$fractionMark${f.d}.');
  }
  final (w, r, d) = f.mixed;
  if (w == BigInt.zero) return FormattedNumber('$r$fractionMark$d.');
  return FormattedNumber('$w$fractionMark$r$fractionMark$d.');
}

/// Degrees°minutes°seconds; seconds get the digits left of the 10.
FormattedNumber _sexagesimal(Dec x, DisplaySettings s) {
  final abs = x.abs();
  if (abs >= Dec.parse('10000000')) return _decimal(x, s);
  final seconds = abs * Dec.fromInt(3600);
  for (var places = 9; places >= 0; places--) {
    final total = seconds.roundDecimals(places);
    final d = (total / Dec.fromInt(3600)).toIntFloor();
    final rest = total - Dec.fromInt(d) * Dec.fromInt(3600);
    final m = (rest / Dec.fromInt(60)).toIntFloor();
    final sec = rest - Dec.fromInt(m) * Dec.fromInt(60);
    var secText = sec.isZero ? '0' : sec.toString();
    final digits = '$d$m$secText'.replaceAll('.', '').length;
    if (digits > displayDigits) continue;
    if (!secText.contains('.')) secText = '$secText.';
    final sign = x.isNegative ? '-' : '';
    return FormattedNumber('$sign$d°$m°$secText');
  }
  return _decimal(x, s);
}

/// Mantissa × 10^[e], up to 10 digits; with [symbols] the exponent shows as
/// an engineering symbol (none for e = 0).
FormattedNumber _eng(Dec x, int e, bool symbols) {
  final m = Dec(x.coefficient, x.exponent - e);
  final intDigits = m.abs() < Dec.one ? 1 : m.abs().exponent10 + 1;
  final places = (displayDigits - intDigits).clamp(0, displayDigits);
  final rounded = m.roundDecimals(places);
  var text = rounded.toString();
  if (!text.contains('.')) text = '$text.';
  if (symbols && (e == 0 || engSymbols.containsKey(e))) {
    return FormattedNumber(text, null, engSymbols[e]);
  }
  final exp = '${e < 0 ? '-' : ''}${e.abs().toString().padLeft(2, '0')}';
  return FormattedNumber(text, exp);
}
