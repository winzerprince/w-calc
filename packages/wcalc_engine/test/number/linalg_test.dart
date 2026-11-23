import 'package:test/test.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/linalg.dart';

Dec d(String s) => Dec.parse(s);
Mat m(List<List<num>> rows) => [
  for (final r in rows) [for (final v in r) d('$v')],
];
List<List<String>> s(Mat x) => [
  for (final r in x) [for (final v in r) v.roundSignificant(10).toString()],
];

void main() {
  final a = m([
    [2, 1],
    [1, 1],
  ]);
  final b = m([
    [2, -1],
    [-1, 2],
  ]);
  final c = m([
    [1, 0, -1],
    [0, -1, 1],
  ]);

  group('matrices (manual p.63-66)', () {
    test(
      'A × B',
      () => expect(s(matMul(a, b)), [
        ['3', '0'],
        ['1', '1'],
      ]),
    );
    test(
      'A + B',
      () => expect(s(matAdd(a, b)), [
        ['4', '0'],
        ['0', '3'],
      ]),
    );
    test(
      'A − B',
      () => expect(s(matSub(a, b)), [
        ['0', '2'],
        ['2', '-1'],
      ]),
    );
    test(
      '3 × A',
      () => expect(s(matScale(a, d('3'))), [
        ['6', '3'],
        ['3', '3'],
      ]),
    );
    test('Det A = 1', () => expect(matDet(a), Dec.one));
    test(
      'Trn C',
      () => expect(s(matTranspose(c)), [
        ['1', '0'],
        ['0', '-1'],
        ['-1', '1'],
      ]),
    );
    test(
      'A⁻¹',
      () => expect(s(matInverse(a)), [
        ['1', '-1'],
        ['-1', '2'],
      ]),
    );
    test(
      'Abs B',
      () => expect(s(matAbs(b)), [
        ['2', '1'],
        ['1', '2'],
      ]),
    );
    test('A² and A³', () {
      expect(s(matMul(a, a)), [
        ['5', '3'],
        ['3', '2'],
      ]);
      expect(s(matMul(matMul(a, a), a)), [
        ['13', '8'],
        ['8', '5'],
      ]);
    });
    test('3×3 determinant and inverse', () {
      final x = m([
        [2, 0, 1],
        [1, 3, 2],
        [1, 1, 2],
      ]);
      expect(matDet(x), d('6'));
      final product = [
        for (final r in matMul(x, matInverse(x)))
          [for (final v in r) v.roundDecimals(10).toString()],
      ];
      expect(product, [
        ['1', '0', '0'],
        ['0', '1', '0'],
        ['0', '0', '1'],
      ]);
    });
    test('Dim ERROR for incompatible sizes', () {
      expect(
        () => matAdd(a, c),
        throwsA(
          isA<CalcError>().having((e) => e.kind, 'kind', CalcErrorKind.dim),
        ),
      );
      expect(() => matMul(c, a), throwsA(isA<CalcError>()));
      expect(() => matDet(c), throwsA(isA<CalcError>()));
    });
    test('singular inverse → Math ERROR', () {
      expect(
        () => matInverse(
          m([
            [1, 2],
            [2, 4],
          ]),
        ),
        throwsA(
          isA<CalcError>().having((e) => e.kind, 'kind', CalcErrorKind.math),
        ),
      );
    });
  });

  group('vectors (manual p.66-68)', () {
    final va = [d('1'), d('2'), d('3')];
    final vb = [d('4'), d('5'), d('6')];
    test('dot', () => expect(vecDot(va, vb), d('32')));
    test('cross', () => expect(vecCross(va, vb), [d('-3'), d('6'), d('-3')]));
    test('abs', () => expect(vecAbs([d('3'), d('4')]), d('5')));
    test('add, scale', () {
      expect(vecAdd(va, vb), [d('5'), d('7'), d('9')]);
      expect(vecScale(va, d('2')), [d('2'), d('4'), d('6')]);
    });
    test('Dim ERROR for different sizes', () {
      expect(() => vecDot(va, [d('1'), d('2')]), throwsA(isA<CalcError>()));
    });
  });
}
