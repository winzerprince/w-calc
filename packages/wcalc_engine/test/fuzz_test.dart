import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Random key presses must never throw, and the display must always be
/// readable. Seeds are fixed so failures reproduce.
void main() {
  final engines = <String, CalcEngine Function()>{
    'two-line full': () => Calculator(random: math.Random(1)),
    'two-line basic': () =>
        Calculator(features: CalcFeatures.basic, random: math.Random(1)),
    'textbook': () => NaturalCalculator(random: math.Random(1)),
    'four-line': () => NaturalCalculator(
      random: math.Random(1),
      profile: NaturalProfile.multiLine,
      menuCursor: true,
      listNames: true,
    ),
    'two-line dot': () => NaturalCalculator(
      random: math.Random(1),
      profile: NaturalProfile.twoLine,
    ),
    'big linear': () =>
        NaturalCalculator(random: math.Random(1), bigLinear: true),
  };

  // Keys weighted towards digits and operators so calculations happen.
  final common = [
    for (var i = 0; i < 4; i++) ...[
      CalcKey.d1,
      CalcKey.d2,
      CalcKey.d3,
      CalcKey.d7,
      CalcKey.add,
      CalcKey.multiply,
      CalcKey.equals,
    ],
  ];
  final keys = [...CalcKey.values, ...common];

  for (final MapEntry(key: name, value: make) in engines.entries) {
    for (final seed in [11, 23, 37, 59, 71, 97]) {
      test('$name survives 4000 random keys (seed $seed)', () {
        final rnd = math.Random(seed);
        final calc = make();
        final pressed = <CalcKey>[];
        for (var i = 0; i < 4000; i++) {
          if (i == 2000) calc.restoreState(calc.saveState());
          final k = keys[rnd.nextInt(keys.length)];
          // Switching off would only test ON; keep it rare.
          if (k == CalcKey.on && rnd.nextInt(10) > 0) continue;
          pressed.add(k);
          try {
            calc.press(k);
            switch (calc) {
              case NaturalCalculator c:
                c.screen;
              case Calculator c:
                c.display;
            }
            calc.copyText;
            calc.graphSpec;
          } catch (e, st) {
            fail(
              'Threw after ${pressed.length} keys '
              '(last 20: ${pressed.skip(math.max(0, pressed.length - 20)).map((k) => k.name).join(' ')}): '
              '$e\n$st',
            );
          }
        }
        // State survives a round trip.
        final copy = make()..restoreState(calc.saveState());
        expect(copy, isNotNull);
      });
    }
  }
}
