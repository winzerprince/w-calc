import 'package:test/test.dart';
import 'package:wcalc_engine/src/format/number_format.dart';
import 'package:wcalc_engine/src/format/value_format.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/frac.dart';
import 'package:wcalc_engine/src/number/value.dart';

Value fv(int n, int d) => Value.frac(Frac(BigInt.from(n), BigInt.from(d)));
Value dv(String s) => Value.dec(Dec.parse(s));
Value sx(String s) => Value.sexagesimal(Dec.parse(s));

const base = DisplaySettings();

(String, String?, String?) show(
  Value v, {
  DisplaySettings s = base,
  ResultView view = ResultView.auto,
  int? eng,
}) {
  final r = formatValue(v, s, view: view, engExponent: eng);
  return (r.mantissa, r.exponent, r.engSymbol);
}

void main() {
  group('fractions (manual p.19-20)', () {
    test('proper and mixed fractions with trailing point', () {
      expect(show(fv(13, 15)).$1, '13┘15.');
      expect(show(fv(53, 12)).$1, '4┘5┘12.');
      expect(show(fv(-1, 2)).$1, '-1┘2.');
      expect(show(fv(-5, 3)).$1, '-1┘2┘3.');
    });
    test('d/c setting shows improper fractions', () {
      const s = DisplaySettings(improperFractions: true);
      expect(show(fv(11, 4), s: s).$1, '11┘4.');
    });
    test(
      'integers show as plain numbers',
      () => expect(show(fv(4, 2)).$1, '2.'),
    );
    test('more than 10 digits falls back to decimal', () {
      expect(show(fv(1, 123456789)), ('8.100000074', '-09', null));
    });
    test('decimal view of a fraction', () {
      expect(show(fv(1, 2), view: ResultView.decimal).$1, '0.5');
    });
    test('fraction view of a decimal', () {
      expect(show(dv('2.75'), view: ResultView.fraction).$1, '2┘3┘4.');
      expect(
        show(dv('3.14159265358980'), view: ResultView.fraction).$1,
        '3.141592654',
      );
    });
  });

  group('sexagesimal (manual p.22-23)', () {
    test('degrees, minutes, seconds', () {
      expect(show(sx('3')).$1, '3°0°0.');
      expect(
        show(
          Value.sexagesimal(
            Dec.parse('2') + Dec.parse('30') / Dec.parse('3600'),
          ),
        ).$1,
        '2°0°30.',
      );
      expect(show(dv('2.258'), view: ResultView.sexagesimal).$1, '2°15°28.8');
    });
    test('seconds get the remaining digits', () {
      final v =
          Dec.parse('12') +
          Dec.parse('34') / Dec.parse('60') +
          Dec.parse('56') / Dec.parse('3600');
      expect(show(Value.sexagesimal(v * Dec.parse('3.45'))).$1, '43°24°31.2');
    });
    test('negative values', () => expect(show(sx('-1.5')).$1, '-1°30°0.'));
    test(
      'decimal view',
      () => expect(show(sx('2.258'), view: ResultView.decimal).$1, '2.258'),
    );
    test('too large for sexagesimal shows decimal', () {
      expect(show(sx('12345678.5')).$1, '12345678.5');
    });
  });

  group('ENG shifts (manual p.24)', () {
    test('ENG uses exponents that are multiples of 3', () {
      expect(show(dv('56088'), eng: 3), ('56.088', '03', null));
      expect(show(dv('0.08125'), eng: -3), ('81.25', '-03', null));
      expect(show(dv('1234'), eng: 0), ('1234.', '00', null));
      expect(show(dv('123'), eng: 6), ('0.000123', '06', null));
    });
    test('natural ENG exponent', () {
      expect(engExponentFor(Dec.parse('56088')), 3);
      expect(engExponentFor(Dec.parse('0.08125')), -3);
      expect(engExponentFor(Dec.parse('123')), 0);
      expect(engExponentFor(Dec.zero), 0);
    });
  });

  group('engineering symbols on (manual p.25)', () {
    const s = DisplaySettings(engOn: true);
    test('results use symbols', () {
      expect(show(dv('5e-7'), s: s), ('500.', null, 'n'));
      expect(show(dv('0.9'), s: s), ('900.', null, 'm'));
      expect(show(dv('12000'), s: s), ('12.', null, 'k'));
    });
    test(
      'no symbol needed',
      () => expect(show(dv('5'), s: s), ('5.', null, null)),
    );
    test('ENG shift with symbols', () {
      expect(show(dv('0.9'), s: s, eng: 0), ('0.9', null, null));
    });
    test('outside f..T uses normal display', () {
      expect(show(dv('1e20'), s: s).$2, '20');
    });
  });

  test('Fix applies to plain decimals', () {
    const s = DisplaySettings(format: DisplayFormat.fix(2));
    expect(show(dv('3.14159'), s: s).$1, '3.14');
  });
}
