import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:w_calc/ui/legend.dart';
import 'package:w_calc/ui/lcd/dot_font.dart';
import 'package:w_calc/ui/lcd/seven_segment.dart';
import 'package:wcalc_engine/wcalc_engine.dart';
// ignore: implementation_imports
import 'package:wcalc_engine/src/input/token.dart';

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

    test('covers every input token and menu text', () {
      final texts = [
        for (final t in Tok.values) t.text,
        'COMP CMPLX',
        'SD REG BASE',
        'EQN MAT VCT',
        'Deg Rad Gra',
        'Fix Sci Norm',
        'Disp',
        'Fix 0~9?',
        'Sci 0~9?',
        'Norm 1~2?',
      ];
      for (final text in texts) {
        for (final ch in text.split('')) {
          expect(hasGlyph(ch), isTrue, reason: '"$ch" in "$text"');
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

    test('comma lights dot and tail on the preceding digit', () {
      final cells = toCells('1,234.5');
      expect(cells.map((c) => c.char).join(), '12345');
      expect(cells[0].comma, isTrue);
      expect(cells[3].point, isTrue);
    });

    test('integer part is grouped in threes', () {
      expect(groupDigits('1234567.25'), '1,234,567.25');
      expect(groupDigits('-40320.'), '-40,320.');
      expect(groupDigits('999.'), '999.');
      expect(groupDigits('0.000123'), '0.000123');
      expect(groupDigits('Math'), 'Math');
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
