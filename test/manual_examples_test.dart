import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:w_calc/app/calc_model.dart';
import 'package:w_calc/manual/manual_content.dart';
import 'package:w_calc/manual/manual_model.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Every verified manual example is replayed on the engine it is written
/// for, so the manual cannot drift from the calculator's behaviour.
void main() {
  String run(CalcFamily family, Example e) {
    final engine = family == CalcFamily.textbook
        ? NaturalCalculator(random: math.Random(1))
        : Calculator(random: math.Random(1));
    for (final k in parseKeySequence('${e.setup ?? ''} ${e.keys}')) {
      engine.press(k);
    }
    if (engine is NaturalCalculator) {
      final t = engine.screen.text;
      final i = t.lastIndexOf(' = ');
      return i < 0 ? t : t.substring(i + 3);
    }
    return engine.copyText ?? '(nothing)';
  }

  for (final chapter in manualChapters) {
    for (final article in chapter.articles) {
      for (final block in article.blocks) {
        if (block is! Example || block.verify == null) continue;
        for (final family in CalcFamily.values) {
          if (!article.audience.includes(family)) continue;
          if (!block.only.includes(family)) continue;
          test('${article.id} / ${block.title} (${family.name})', () {
            expect(run(family, block), block.verify);
          });
        }
      }
    }
  }

  test('every article id is unique', () {
    final ids = [
      for (final c in manualChapters)
        for (final a in c.articles) a.id,
    ];
    expect(ids.toSet().length, ids.length);
  });

  test('every key sequence in steps and examples parses', () {
    for (final c in manualChapters) {
      for (final a in c.articles) {
        for (final b in a.blocks) {
          final seqs = switch (b) {
            Example(:final keys, :final setup) => [keys, ?setup],
            Steps(:final steps) => [for (final s in steps) ?s.keys],
            _ => <String>[],
          };
          for (final s in seqs) {
            expect(() => parseKeySequence(s), returnsNormally, reason: s);
          }
        }
      }
    }
  });

  test('search ranks title matches first and respects the model', () {
    final hits = searchManual(manualChapters, CalcModel.plus, 'integration');
    expect(hits.first.article.id, 'integration');
    expect(
      searchManual(
        manualChapters,
        CalcModel.basic,
        'matrix',
      ).map((h) => h.article.id),
      isNot(contains('matrix')),
    );
    expect(
      searchManual(
        manualChapters,
        CalcModel.textbook,
        'sigma',
      ).first.article.id,
      'sum',
    );
  });
}
