import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void main() {
  test('numbers expand to one key per character', () {
    expect(parseKeySequence('2.5'), [CalcKey.d2, CalcKey.dot, CalcKey.d5]);
  });

  test('named keys and multi-key names', () {
    expect(parseKeySequence('(-) INS ='), [
      CalcKey.negative,
      CalcKey.shift,
      CalcKey.del,
      CalcKey.equals,
    ]);
  });

  test('extra whitespace is ignored', () {
    expect(parseKeySequence('  1   + 2 '), hasLength(3));
  });

  test('unknown names are rejected', () {
    expect(() => parseKeySequence('1 frobnicate'), throwsFormatException);
  });
}
