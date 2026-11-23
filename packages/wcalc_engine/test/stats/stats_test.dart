import 'package:test/test.dart';
import 'package:wcalc_engine/src/format/number_format.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/stats/stats.dart';

Dec d(String s) => Dec.parse(s);

/// As the display shows it (Norm 1), without the trailing point.
String r10(Dec v) {
  final f = formatNumber(v, const DisplayFormat.norm1());
  final m = f.mantissa.endsWith('.')
      ? f.mantissa.substring(0, f.mantissa.length - 1)
      : f.mantissa;
  return f.exponent == null ? m : '${m}e${f.exponent}';
}

StatData sd(List<String> xs) {
  final data = StatData();
  for (final x in xs) {
    data.add(StatItem(d(x)));
  }
  return data;
}

StatData reg(List<(String, String)> pts, RegressionType type) {
  final data = StatData(type: type);
  for (final (x, y) in pts) {
    data.add(StatItem(d(x), y: d(y)));
  }
  return data;
}

void main() {
  group('single-variable (manual p.48)', () {
    final data = sd(['55', '54', '51', '55', '53', '53', '54', '52']);
    test('sums', () {
      expect(data.n, d('8'));
      expect(data.sumX, d('427'));
      expect(data.sumX2, d('22805'));
    });
    test('mean and deviations', () {
      expect(data.meanX, d('53.375'));
      expect(r10(data.sigmaX), '1.316956719');
      expect(r10(data.sampleX), '1.407885953');
    });
    test('frequencies count as repeated data', () {
      final f = StatData()
        ..add(StatItem(d('110'), freq: d('10')))
        ..add(StatItem(d('100')));
      expect(f.n, d('11'));
      expect(f.sumX, d('1200'));
    });
    test('no data → Math ERROR; s needs two items', () {
      expect(() => StatData().meanX, throwsA(isA<CalcError>()));
      expect(() => sd(['5']).sampleX, throwsA(isA<CalcError>()));
    });
    test('normalized variate →t (manual p.55)', () {
      // Exact value −0.28474739873 rounds to …399; the manual prints …398
      // (device precision ±1 in the 10th digit). behaviour-notes #54.
      expect(r10(data.toT(d('53'))), '-0.284747399');
    });
  });

  group('linear regression (manual p.52-53)', () {
    final data = reg([
      ('10', '1003'),
      ('15', '1005'),
      ('20', '1010'),
      ('25', '1011'),
      ('30', '1014'),
    ], RegressionType.lin);
    test('coefficients', () {
      expect(data.a, d('997.4'));
      expect(data.b, d('0.56'));
      // Exact 0.98260736888 → …369; manual prints …368 (behaviour-notes #54).
      expect(r10(data.r), '0.982607369');
    });
    test('estimates', () {
      expect(data.estimateY(d('-5')), d('994.6'));
      expect(r10(data.estimateX(d('1000'))), '4.642857143');
    });
    test('y sums', () {
      expect(data.sumY, d('5043'));
      expect(data.sumXY, d('101000'));
    });
  });

  group('other regressions (mpmath)', () {
    final pts = [
      ('1', '2.1'),
      ('2', '3.9'),
      ('3', '6.2'),
      ('4', '7.8'),
      ('5', '10.1'),
    ];
    void check(RegressionType t, String a, String b, String r) {
      final data = reg(pts, t);
      expect(r10(data.a), a, reason: '$t A');
      expect(r10(data.b), b, reason: '$t B');
      expect(r10(data.r), r, reason: '$t r');
    }

    test(
      'log',
      () => check(
        RegressionType.log,
        '1.419241623',
        '4.804977872',
        '0.969179872',
      ),
    );
    test(
      'exp',
      () => check(
        RegressionType.exp,
        '1.662830828',
        '0.383434334',
        '0.976935383',
      ),
    );
    test(
      'pwr',
      () => check(
        RegressionType.pwr,
        '2.064514818',
        '0.975384686',
        '0.998855751',
      ),
    );
    test(
      'inv',
      () => check(
        RegressionType.inv,
        '9.990034319',
        '-8.693505808',
        '-0.895034287',
      ),
    );
    test('estimates invert the model', () {
      for (final t in [
        RegressionType.log,
        RegressionType.exp,
        RegressionType.pwr,
        RegressionType.inv,
      ]) {
        final data = reg(pts, t);
        final y = data.estimateY(d('3'));
        expect(r10(data.estimateX(y)), '3', reason: '$t');
      }
    });
    test('log of non-positive x → Math ERROR', () {
      final data = StatData(type: RegressionType.log)
        ..add(StatItem(d('0'), y: d('1')));
      expect(() => data.a, throwsA(isA<CalcError>()));
    });
  });

  group('quadratic regression (manual p.53-54)', () {
    final data = reg([
      ('29', '1.6'),
      ('50', '23.5'),
      ('74', '38.0'),
      ('103', '46.4'),
      ('118', '48.0'),
    ], RegressionType.quad);
    test('coefficients', () {
      expect(r10(data.a), '-35.59856934');
      expect(r10(data.b), '1.495939413');
      expect(r10(data.c), '-6.71629667e-03');
    });
    test('estimates', () {
      expect(r10(data.estimateY(d('16'))), '-13.38291067');
      expect(r10(data.estimateX1(d('20'))), '47.14556728');
      expect(r10(data.estimateX2(d('20'))), '175.5872105');
    });
    test('quadratic sums', () {
      expect(data.sumX3 > Dec.zero, isTrue);
      expect(data.sumX4 > data.sumX3, isTrue);
      expect(data.sumX2Y > Dec.zero, isTrue);
    });
  });

  group('normal distribution (manual p.55)', () {
    test('P, Q, R rounded to 5 decimals like the device', () {
      expect(normalP(d('-0.28')), d('0.38974'));
      expect(normalQ(d('1.5')), d('0.43319'));
      expect(normalR(d('1.5')), d('0.06681'));
      expect(normalP(d('0')), d('0.5'));
      expect(normalQ(d('-2')), d('0.47725'));
    });
  });
}
