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

  void vector(String sequence, String mantissa, [String? exponent]) {
    final d = press(sequence);
    expect((d.lower, d.exponent), (mantissa, exponent), reason: sequence);
  }

  group('variables (manual p.29)', () {
    test('STO evaluates and stores; ALPHA uses; RCL recalls', () {
      vector('3 + 5 STO kA', '8.');
      vector('A × 10 =', '80.');
      vector('RCL kA', '8.');
      expect(calc.display.upper, 'A=');
    });

    test('0 STO A clears A', () {
      press('3 STO kA');
      vector('0 STO kA', '0.');
      vector('RCL kA', '0.');
    });

    test('STO and RCL show their indicators until a variable key', () {
      expect(press('SHIFT RCL').indicators, contains(Indicator.sto));
      expect(press('kB').indicators, isNot(contains(Indicator.sto)));
      expect(press('RCL').indicators, contains(Indicator.rcl));
    });

    test('STO updates Ans', () => vector('2 STO kB Ans + 1 =', '3.'));

    test('STO after a result stores that result', () {
      press('6 × 7 =');
      press('STO kY');
      vector('RCL kY', '42.');
    });

    test('a non-variable key cancels STO', () {
      press('5 STO');
      expect(press('7').indicators, isNot(contains(Indicator.sto)));
    });

    test('variable names type as text and multiply implicitly', () {
      press('4 STO kX');
      expect(press('AC 2 X').upper, '2X');
      vector('=', '8.');
    });

    test('all nine variables', () {
      var n = 1;
      for (final v in ['A', 'B', 'C', 'D', 'E', 'F', 'M', 'X', 'Y']) {
        press('AC $n STO k$v');
        n++;
      }
      vector('AC A + B + C + D + E + F + M + X + Y =', '45.');
    });

    test('percent example 5 shape: Ans STO A then use A (manual p.22)', () {
      press('168 + 98 + 734 = Ans STO kA');
      vector('A × 20 =', '20000.');
    });
  });

  group('independent memory M (manual p.30)', () {
    test('example 1: clear, add, subtract, recall', () {
      vector('0 STO kM', '0.');
      vector('10 × 5 M+', '50.');
      expect(calc.display.indicators, contains(Indicator.memory));
      vector('10 + 5 M-', '15.');
      vector('RCL kM', '35.');
    });

    test('example 2: running total', () {
      press('23 + 9 STO kM');
      press('53 - 6 M+');
      press('45 × 2 M-');
      press('99 ÷ 3 M+');
      vector('RCL kM', '22.');
    });

    test('M indicator only while M is non-zero', () {
      press('5 M+');
      expect(calc.display.indicators, contains(Indicator.memory));
      press('5 M-');
      expect(calc.display.indicators, isNot(contains(Indicator.memory)));
    });

    test('M+ after a result adds that result again', () {
      press('0 STO kM 4 M+ M+');
      vector('RCL kM', '8.');
    });

    test('M+ updates Ans', () => vector('9 M+ Ans × 2 =', '18.'));
  });

  group('memory survives AC; CLR clears (manual p.30)', () {
    test('AC keeps variables', () {
      press('7 STO kC AC');
      vector('RCL kC', '7.');
    });

    test('CLR menu', () {
      final d = press('CLR');
      expect(d.upper, 'Mcl Mode All');
      expect(d.menuMarks, {1: '1', 5: '2', 10: '3'});
    });

    test('CLR 1 = clears variables and M', () {
      press('7 STO kC 3 M+');
      expect(press('CLR 1').upper, 'Mcl');
      press('=');
      vector('RCL kC', '0.');
      expect(calc.display.indicators, isNot(contains(Indicator.memory)));
    });

    test('CLR then AC cancels', () {
      press('7 STO kC CLR 1 AC');
      vector('RCL kC', '7.');
    });

    test('CLR 2 = resets modes but keeps memory', () {
      press('7 STO kC MODE MODE MODE MODE 2 MODE MODE MODE MODE MODE 1 3');
      press('CLR 2 =');
      expect(calc.display.indicators, containsAll([Indicator.deg]));
      expect(calc.display.indicators, isNot(contains(Indicator.fix)));
      vector('RCL kC', '7.');
    });

    test('CLR 3 = resets everything', () {
      press('7 STO kC 5 M+ 2 = MODE MODE MODE MODE 3 CLR 3 =');
      expect(calc.display.indicators, contains(Indicator.deg));
      vector('RCL kC', '0.');
      vector('AC Ans =', '0.');
    });
  });

  group('calculation history (manual p.26)', () {
    test('▲ scrolls back through earlier calculations', () {
      press('1 + 1 = 2 + 2 = 3 + 3 =');
      final up1 = press('up');
      expect((up1.upper, up1.lower), ('2+2', '4.'));
      final up2 = press('up');
      expect((up2.upper, up2.lower), ('1+1', '2.'));
    });

    test('▲ / ▼ indicators show more history above / below', () {
      press('1 + 1 = 2 + 2 = 3 + 3 =');
      expect(calc.display.indicators, contains(Indicator.scrollUp));
      expect(calc.display.indicators, isNot(contains(Indicator.scrollDown)));
      press('up');
      expect(
        calc.display.indicators,
        containsAll([Indicator.scrollUp, Indicator.scrollDown]),
      );
      press('up');
      expect(calc.display.indicators, isNot(contains(Indicator.scrollUp)));
      expect(press('down down').upper, '3+3');
    });

    test('scrolling stops at both ends', () {
      press('1 + 1 = 2 + 2 =');
      expect(press('up up up').upper, '1+1');
      expect(press('down down down').upper, '2+2');
    });

    test('◀ edits the expression shown from history', () {
      press('1 + 1 = 2 + 2 = up');
      vector('< DEL 5 =', '6.');
    });

    test('history entries keep their own result, not re-evaluated', () {
      press('Ran# = 5 =');
      final first = press('up').lower;
      expect(press('down up').lower, first);
    });

    test('ON clears history', () {
      press('1 + 1 = 2 + 2 = ON');
      expect(press('up').upper, '');
    });

    test('history keeps about 150 bytes of the newest calculations', () {
      for (var i = 0; i < 40; i++) {
        press('AC 1234 + $i =');
      }
      var steps = 0;
      while (calc.display.indicators.contains(Indicator.scrollUp)) {
        press('up');
        steps++;
      }
      expect(steps, inInclusiveRange(5, 20));
    });

    test('errors are not stored in history', () {
      press('1 + 1 = 1 ÷ 0 = AC');
      expect(press('up').upper, '1+1');
    });
  });

  group('multi-statements (manual p.23)', () {
    test('colon joins statements; = steps through them', () {
      final first = press('2 + 3 : Ans × 4 =');
      expect((first.upper, first.lower), ('2+3', '5.'));
      expect(first.indicators, contains(Indicator.disp));
      final second = press('=');
      expect((second.upper, second.lower), ('Ans×4', '20.'));
      expect(second.indicators, isNot(contains(Indicator.disp)));
    });

    test('colon shows as ":"', () {
      expect(press('1 : 2').upper, '1:2');
    });

    test('AC stops a multi-statement', () {
      press('1 : 2 = AC');
      expect(calc.display.upper, '');
    });

    test('error in a later statement points into the whole expression', () {
      press('1 : 1 ÷ 0 = =');
      expect(calc.display.upper, 'Math ERROR');
      expect(press('<').cursor, 3);
    });

    test('empty statement is a syntax error', () {
      expect(press('1 : : 2 =').upper, 'Syntax ERROR');
    });
  });

  group('replay COPY (manual p.27)', () {
    test('copies from the shown entry to the newest as a multi-statement', () {
      press('1 + 1 = 2 + 2 = 3 + 3 = 4 + 4 = 5 + 5 = 6 + 6 =');
      press('up up');
      final d = press('COPY');
      expect(calc.display.cursor, isNotNull);
      expect(d.upper, '4+4:5+5:6+6');
      vector('=', '8.');
      vector('=', '10.');
      vector('=', '12.');
    });
  });

  group('state persistence', () {
    test('memories, Ans and settings round-trip through a snapshot', () {
      press(
        '7 STO kC 2 M+ MODE MODE MODE MODE 2 MODE MODE MODE MODE MODE 1 4 9 =',
      );
      final snapshot = calc.saveState();
      final restored = Calculator()..restoreState(snapshot);
      keys('RCL kC').forEach(restored.press);
      expect(restored.display.lower, '7.0000');
      expect(
        restored.display.indicators,
        containsAll([Indicator.rad, Indicator.fix, Indicator.memory]),
      );
      keys('AC Ans =').forEach(restored.press);
      expect(restored.display.lower, '9.0000');
    });

    test('a corrupt snapshot is ignored', () {
      final c = Calculator()..restoreState({'vars': 'nonsense', 'angle': 42});
      expect(c.display.lower, '0.');
    });
  });
}
