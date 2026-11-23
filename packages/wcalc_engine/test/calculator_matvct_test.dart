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

  (String, String) screen(String sequence) {
    final d = press(sequence);
    return (d.upper, d.exponent == null ? d.lower : '${d.lower}e${d.exponent}');
  }

  group('MAT (manual p.63-66)', () {
    const mat = 'MODE MODE MODE 2';
    const setup =
        '$mat MAT 1 1 2 = 2 = 2 = 1 = 1 = 1 = '
        'MAT 1 2 2 = 2 = 2 = (-) 1 = (-) 1 = 2 = '
        'MAT 1 3 2 = 3 = 1 = 0 = (-) 1 = 0 = (-) 1 = 1 = AC';

    test('MAT indicator and menus', () {
      expect(press(mat).indicators, contains(Indicator.mat));
      expect(press('MAT').upper, 'Dim Edit Mat→');
      expect(press('>').upper, '←Det Trn');
      expect(press('AC MAT 1').upper, ' A   B   C');
      expect(press('1').upper, 'MatA(m×n) m?');
      expect(press('2 =').upper, 'MatA(m×n) n?');
      expect(screen('2 ='), ('MatA₁₁', '0.'));
      expect(
        calc.display.indicators,
        containsAll([Indicator.scrollRight, Indicator.scrollDown]),
      );
      expect(screen('2 ='), ('MatA₁₂', '0.'));
    });
    test('A × B → MatAns', () {
      press(setup);
      expect(press('MAT 3 1 × MAT 3 2').upper, 'MatA×MatB');
      expect(screen('='), ('MatAns₁₁', '3.'));
      expect(screen('>'), ('MatAns₁₂', '0.'));
      expect(screen('down'), ('MatAns₂₂', '1.'));
    });
    test('A + B', () {
      press(setup);
      expect(screen('MAT 3 1 + MAT 3 2 ='), ('MatAns₁₁', '4.'));
    });
    test('3 × A', () {
      press(setup);
      expect(screen('3 × MAT 3 1 ='), ('MatAns₁₁', '6.'));
    });
    test('Det A = 1', () {
      press(setup);
      expect(screen('MAT > 1 MAT 3 1 =').$2, '1.');
    });
    test('Trn C is 3×2', () {
      press(setup);
      expect(screen('MAT > 2 MAT 3 3 ='), ('MatAns₁₁', '1.'));
      expect(screen('down down'), ('MatAns₃₁', '-1.'));
    });
    test('A⁻¹, Abs B, A², A³', () {
      press(setup);
      expect(screen('MAT 3 1 x-1 = >'), ('MatAns₁₂', '-1.'));
      expect(screen('AC Abs MAT 3 2 = >'), ('MatAns₁₂', '1.'));
      expect(screen('AC MAT 3 1 x2 ='), ('MatAns₁₁', '5.'));
      expect(screen('AC MAT 3 1 x3 ='), ('MatAns₁₁', '13.'));
    });
    test('operator on the MatAns screen continues with MatAns', () {
      press(setup);
      press('MAT 3 1 + MAT 3 2 =');
      expect(press('×').upper, 'MatAns×');
      expect(screen('2 ='), ('MatAns₁₁', '8.'));
    });
    test('Edit changes an element', () {
      press(setup);
      press('MAT 2 1 9 = AC');
      expect(screen('MAT > 1 MAT 3 1 =').$2, '8.');
    });
    test('incompatible sizes → Dim ERROR; undefined matrix → Dim ERROR', () {
      press(setup);
      expect(press('MAT 3 1 + MAT 3 3 =').upper, 'Dim ERROR');
      expect(press('AC MAT 3 4 =').upper, 'Dim ERROR');
    });
    test('dimension outside 1-3 is ignored', () {
      press('$mat MAT 1 1 4 =');
      expect(calc.display.upper, 'MatA(m×n) m?');
    });
    test('matrices survive a snapshot', () {
      press(setup);
      final c = Calculator()..restoreState(calc.saveState());
      keys('MAT > 1 MAT 3 1 =').forEach(c.press);
      expect(c.display.lower, '1.');
    });
  });

  group('VCT (manual p.66-69)', () {
    const vct = 'MODE MODE MODE 3';
    const setup =
        '$vct VCT 1 1 2 = 1 = 2 = VCT 1 2 2 = 3 = 4 = VCT 1 3 3 = 2 = (-) 1 = 2 = AC';

    test('editor', () {
      press(vct);
      expect(calc.display.indicators, contains(Indicator.vct));
      expect(press('VCT').upper, 'Dim Edit Vct→');
      expect(press('1 1').upper, 'VctA(m) m?');
      expect(screen('2 ='), ('VctA₁', '0.'));
      expect(screen('5 ='), ('VctA₂', '0.'));
      expect(screen('<'), ('VctA₁', '5.'));
    });
    test('A + B = (4, 6)', () {
      press(setup);
      expect(screen('VCT 3 1 + VCT 3 2 ='), ('VctAns₁', '4.'));
      expect(screen('>'), ('VctAns₂', '6.'));
    });
    test('3 × A = (3, 6); − B = (0, 2)', () {
      press(setup);
      expect(screen('3 × VCT 3 1 ='), ('VctAns₁', '3.'));
      expect(screen('- VCT 3 2 ='), ('VctAns₁', '0.'));
      expect(screen('>'), ('VctAns₂', '2.'));
    });
    test('A • B = 11', () {
      press(setup);
      expect(screen('VCT 3 1 VCT > 1 VCT 3 2 =').$2, '11.');
    });
    test('A × B = (0, 0, -2)', () {
      press(setup);
      expect(screen('VCT 3 1 × VCT 3 2 = > >'), ('VctAns₃', '-2.'));
    });
    test('Abs C = 3', () {
      press(setup);
      expect(screen('Abs VCT 3 3 =').$2, '3.');
    });
    test('angle between A and B (Fix 3) = 10.305', () {
      press(setup);
      press('MODE MODE MODE MODE MODE 1 3');
      expect(
        screen(
          'acos ( ( VCT 3 1 VCT > 1 VCT 3 2 ) ÷ ( Abs VCT 3 1 × Abs VCT 3 2 ) ) =',
        ).$2,
        '10.305',
      );
    });
  });
}
