import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void main() {
  String? copy(String keys) {
    final calc = Calculator();
    for (final k in parseKeySequence(keys)) {
      calc.press(k);
    }
    return calc.display.copyText;
  }

  test('integer result drops the display point', () {
    expect(copy('3 + 4 ='), '7');
  });
  test('decimal result is copied as shown', () {
    expect(copy('1 / 3 ='), '0.333333333');
  });
  test('negative result keeps its sign', () {
    expect(copy('2 - 5 ='), '-3');
  });
  test('exponent becomes E notation', () {
    expect(copy('2 EXP 20 * 3 ='), '6E20');
    expect(copy('1 / 8000 ='), '1.25E-04');
  });
  test('menus and errors have nothing to copy', () {
    expect(copy('MODE'), isNull);
    expect(copy('1 / 0 ='), isNull);
    expect(DisplayState.off.copyText, isNull);
    expect(DisplayState.busy.copyText, isNull);
  });
}
