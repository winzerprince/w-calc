import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:w_calc/ui/legend.dart';
import 'package:w_calc/ui/lcd/dot_font.dart';
import 'package:w_calc/ui/lcd/seven_segment.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void main() {
  group('dot-matrix font', () {
    test('every glyph is 7 rows of 5 columns', () {
      for (final ch in ' 0123456789AZaz×÷√π²³⁻¹°′″∠∫▶■←→θΣσμℏ'.split('')) {
        final g = glyphFor(ch);
        expect(g, hasLength(dotFontHeight), reason: ch);
        expect(g.every((r) => r.length == dotFontWidth), isTrue, reason: ch);
      }
    });

    test('covers every error message', () {
      for (final kind in CalcErrorKind.values) {
        for (final ch in kind.message.split('')) {
          expect(hasGlyph(ch), isTrue, reason: '"$ch" in ${kind.message}');
        }
      }
    });

    test('unknown characters fall back to a box', () {
      expect(hasGlyph('☃'), isFalse);
      expect(glyphFor('☃').first, '#####');
    });
  });

  group('seven-segment cells', () {
    test('points attach to the preceding digit', () {
      final cells = toCells('-6.25');
      expect(cells.map((c) => c.char).join(), '-625');
      expect(cells[1].point, isTrue);
      expect(cells[2].point, isFalse);
    });

    test('integer result keeps its trailing point', () {
      expect(toCells('36.').last.point, isTrue);
    });

    test('leading point gets a 0 cell', () {
      expect(toCells('.5').first.char, '0');
    });

    test('all decimal digits and minus have segments', () {
      for (final ch in '0123456789-'.split('')) {
        expect(segmentsFor(ch), isNotEmpty, reason: ch);
      }
      expect(segmentsFor('8'), hasLength(7));
    });
  });

  group('legend markup', () {
    test('superscripts become raised spans', () {
      final spans = legendSpans('x^{-1}', const TextStyle(fontSize: 10));
      expect(spans, hasLength(2));
      expect(spans.last, isA<WidgetSpan>());
    });

    test('plain legends stay single text spans', () {
      expect(legendSpans('sin', const TextStyle()), hasLength(1));
    });

    test('text form for semantics', () {
      expect(legendText('10^{x}'), '10x');
      expect(legendText('^{3}√'), '3√');
    });
  });
}
