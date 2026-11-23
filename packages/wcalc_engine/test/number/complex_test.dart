import 'package:test/test.dart';
import 'package:wcalc_engine/src/angle_unit.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/value.dart';

Value c(String re, String im) => Value.complex(Dec.parse(re), Dec.parse(im));
Value r(String re) => Value.dec(Dec.parse(re));

String show(Value v) => '${v.dec}${v.isComplex ? ' ${v.imag}i' : ''}';

void main() {
  test('construction: zero imaginary part is real', () {
    expect(c('3', '0').isComplex, isFalse);
    expect(c('3', '2').isComplex, isTrue);
    expect(Value.imaginaryUnit.imag, Dec.one);
  });

  test('add, subtract, multiply, divide', () {
    expect(show(c('1', '2') + c('3', '-5')), '4 -3i');
    expect(show(c('1', '2') - r('1')), '0 2i');
    expect(show(c('1', '2') * c('3', '4')), '-5 10i');
    expect(show(c('2', '6') / c('0', '2')), '3 -1i');
    expect(show(r('1') / c('0', '1')), '0 -1i');
  });

  test('division by zero', () {
    expect(() => c('1', '1') / c('0', '0'), throwsA(isA<CalcError>()));
  });

  test('negation and conjugate', () {
    expect(show(-c('1', '2')), '-1 -2i');
    expect(show(c('2', '3').conjugate()), '2 -3i');
  });

  test('integer powers', () {
    expect(show(c('1', '1').powInt(2)!), '0 2i');
    expect(show(c('0', '1').powInt(4)!), '1');
    expect(show(c('1', '1').powInt(-1)!), '0.5 -0.5i');
  });

  test('abs and arg', () {
    expect(c('1', '1').magnitude().toString(), '1.4142135623731');
    expect(c('1', '1').argument(AngleUnit.deg).toString(), '45');
    expect(c('-1', '0').argument(AngleUnit.deg).toString(), '180');
    expect(c('0', '-2').argument(AngleUnit.deg).toString(), '-90');
  });

  test('polar construction r∠θ', () {
    final v = Value.polar(
      Dec.parse('1.4142135623731'),
      Dec.parse('45'),
      AngleUnit.deg,
    );
    expect(v.dec.roundSignificant(10), Dec.one);
    expect(v.imag.roundSignificant(10), Dec.one);
  });
}
