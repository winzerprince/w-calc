import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  late Calculator calc;

  setUp(() => calc = Calculator());

  DisplayState press(String sequence) {
    keys(sequence).forEach(calc.press);
    return calc.display;
  }

  group('OFF (SHIFT AC)', () {
    test('turns the display off; only ON turns it back on', () {
      press('7 STO kA 1 + 2');
      expect(press('SHIFT AC').isOff, isTrue);
      expect(press('5 = sin').isOff, isTrue);
      final on = press('ON');
      expect(on.isOff, isFalse);
      expect((on.upper, on.lower), ('', '0.'));
      expect(press('RCL kA').lower, '7.');
    });
  });

  group('contrast (manual p.8)', () {
    test(
      'Disp page offers ◀CONT▶; ▶ opens contrast; ◀ ▶ adjust; AC closes',
      () {
        expect(press('MODE MODE MODE MODE MODE MODE').upper, 'Disp ◀CONT▶');
        expect(press('>').upper, 'CONT ◀  ▶');
        expect(calc.display.contrast, 0);
        expect(press('> >').contrast, 2);
        expect(press('< < < < < < < < <').contrast, -5);
        press('AC');
        expect(calc.display.contrast, -5);
        expect(calc.display.menuMarks, isNull);
      },
    );
    test('contrast survives a snapshot and is clamped', () {
      press('MODE MODE MODE MODE MODE MODE > > > > > > > > AC');
      expect(calc.display.contrast, 5);
      final c = Calculator()..restoreState(calc.saveState());
      expect(c.display.contrast, 5);
    });
  });
}
