import 'package:flutter/widgets.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/calc_model.dart';

/// Which calculators an article is about.
enum ManualAudience {
  /// Every model.
  all,

  /// Two-line LCD models (Scientific Plus / Grid / Basic).
  twoLine,

  /// Textbook-display models (Textbook Plus / Plus II).
  textbook;

  bool includes(CalcFamily f) => switch (this) {
    all => true,
    twoLine => f == CalcFamily.twoLine,
    textbook => f == CalcFamily.textbook,
  };
}

/// One piece of an article.
sealed class ManualBlock {
  const ManualBlock();

  /// Searchable text of the block.
  String get searchText;
}

/// A paragraph of explanation.
final class Para extends ManualBlock {
  const Para(this.text);
  final String text;

  @override
  String get searchText => text;
}

/// Numbered steps; each may show the keys to press.
final class Steps extends ManualBlock {
  const Steps(this.steps);
  final List<ManualStep> steps;

  @override
  String get searchText => steps.map((s) => s.text).join(' ');
}

final class ManualStep {
  const ManualStep(this.text, [this.keys]);
  final String text;

  /// Key names as in test vectors (see `parseKeySequence`), or null.
  final String? keys;
}

/// A worked example: press [keys] (after [setup]) and the display shows
/// [result]. [verify] is what the engine's plain-text result must equal;
/// the manual test replays every verified example on the real engine.
final class Example extends ManualBlock {
  const Example({
    required this.title,
    required this.keys,
    required this.result,
    this.setup,
    this.verify,
    this.note,
    this.only = ManualAudience.all,
  });

  /// Families this example is written for (keys differ between them).
  final ManualAudience only;

  final String title;
  final String keys;
  final String result;
  final String? setup;
  final String? verify;
  final String? note;

  @override
  String get searchText => '$title $result ${note ?? ''}';
}

/// Highlighted hint.
final class Tip extends ManualBlock {
  const Tip(this.text);
  final String text;

  @override
  String get searchText => text;
}

/// A help article (one task or concept).
final class ManualArticle {
  const ManualArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.blocks,
    this.audience = ManualAudience.all,
    this.requires = const {},
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String summary;
  final List<ManualBlock> blocks;
  final ManualAudience audience;

  /// Two-line modes the article needs (hidden on models without them).
  final Set<CalcMode> requires;
  final List<String> keywords;

  bool appliesTo(CalcModel m) =>
      audience.includes(m.family) &&
      (m.family == CalcFamily.textbook ||
          requires.every(m.features.modes.contains));

  String get searchText => [
    title,
    summary,
    ...keywords,
    for (final b in blocks) b.searchText,
  ].join(' ').toLowerCase();
}

/// A group of articles (shown on the manual home page).
final class ManualChapter {
  const ManualChapter({
    required this.id,
    required this.title,
    required this.icon,
    required this.articles,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<ManualArticle> articles;

  List<ManualArticle> articlesFor(CalcModel m) => [
    for (final a in articles)
      if (a.appliesTo(m)) a,
  ];
}

/// A search hit with its chapter.
final class ManualHit {
  const ManualHit(this.chapter, this.article, this.score);
  final ManualChapter chapter;
  final ManualArticle article;
  final int score;
}

/// Ranked full-text search: every word must match; title and keyword
/// matches rank above body matches.
List<ManualHit> searchManual(
  List<ManualChapter> chapters,
  CalcModel model,
  String query,
) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final hits = <ManualHit>[];
  for (final c in chapters) {
    for (final a in c.articlesFor(model)) {
      final body = a.searchText;
      // Words match at the start of a word ("int" finds "integral").
      if (!words.every(
        (w) => RegExp('\\b${RegExp.escape(w)}').hasMatch(body),
      )) {
        continue;
      }
      final title = a.title.toLowerCase();
      final keys = a.keywords.join(' ').toLowerCase();
      var score = 0;
      for (final w in words) {
        if (title.contains(w)) score += 10;
        if (keys.contains(w)) score += 5;
        if (c.title.toLowerCase().contains(w)) score += 3;
        score += 1;
      }
      hits.add(ManualHit(c, a, score));
    }
  }
  hits.sort((x, y) => y.score.compareTo(x.score));
  return hits;
}
