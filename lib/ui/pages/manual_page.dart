import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../../app/calc_model.dart';
import '../../manual/manual_content.dart';
import '../../manual/manual_model.dart';
import '../../manual/reference_data.dart';
import '../keypad_layout.dart';
import '../legend.dart';
import '../reading_theme.dart';
import '../skin.dart';
import '../tour/tours.dart';

/// Manual home: search and chapters for the model in use.
class ManualPage extends StatefulWidget {
  const ManualPage({super.key, this.startTour = false});

  /// Settings ▸ Help: replay this page's tour.
  final bool startTour;

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  final _search = TextEditingController();
  late bool _tourOnce = widget.startTour;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ModelScope.of(context);
    final chapters = [
      for (final c in manualChapters)
        if (c.articlesFor(model).isNotEmpty) c,
    ];
    final hits = searchManual(chapters, model, _query);
    runTourOnce(context, Tours.manual, () => manualTour, force: _tourOnce);
    _tourOnce = false;
    return Theme(
      data: readingTheme(context),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manual'),
                  Text(
                    'For ${model.name}',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    key: TourKeys.manualSearch,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      key: const Key('manual-search'),
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search: fraction, integral, mean …',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _query.trim().isEmpty
                        ? _ChapterList(chapters: chapters, model: model)
                        : _Results(hits: hits, query: _query),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.chapters, required this.model});

  final List<ManualChapter> chapters;
  final CalcModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: chapters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = chapters[i];
        final articles = c.articlesFor(model);
        return Card(
          key: i == 0 ? TourKeys.manualChapters : null,
          elevation: 0,
          color: scheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey('chapter-${c.id}'),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(c.icon),
            ),
            title: Text(
              c.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            subtitle: Text(
              '${articles.length} topic${articles.length == 1 ? '' : 's'}',
            ),
            shape: const Border(),
            children: [
              for (final a in articles)
                ListTile(
                  key: Key('article-${a.id}'),
                  title: Text(a.title),
                  subtitle: Text(a.summary),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openArticle(context, c, a),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.hits, required this.query});

  final List<ManualHit> hits;
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Nothing found for “$query”.\nTry another word, e.g. “mean” or '
              '“root”.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final h = hits[i];
        return ListTile(
          key: Key('hit-${h.article.id}'),
          leading: Icon(h.chapter.icon, color: scheme.primary),
          title: Text(h.article.title),
          subtitle: Text('${h.chapter.title} · ${h.article.summary}'),
          onTap: () => openArticle(context, h.chapter, h.article),
        );
      },
    );
  }
}

void openArticle(BuildContext context, ManualChapter c, ManualArticle a) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ArticlePage(chapter: c, article: a),
    ),
  );
}

/// One article: explanation, steps, worked examples and tips.
class ArticlePage extends StatelessWidget {
  const ArticlePage({super.key, required this.chapter, required this.article});

  final ManualChapter chapter;
  final ManualArticle article;

  @override
  Widget build(BuildContext context) {
    final model = ModelScope.of(context);
    final articles = chapter.articlesFor(model);
    final i = articles.indexWhere((a) => a.id == article.id);
    final prev = i > 0 ? articles[i - 1] : null;
    final next = i >= 0 && i < articles.length - 1 ? articles[i + 1] : null;
    return Theme(
      data: readingTheme(context),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(title: Text(chapter.title)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    article.title,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.summary,
                    style: text.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final b in article.blocks)
                    if (b is! Example || b.only.includes(model.family))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _block(context, b, model),
                      ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      if (prev != null)
                        Expanded(
                          child: _NavButton(
                            label: prev.title,
                            back: true,
                            onTap: () => _replace(context, prev),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      if (next != null)
                        Expanded(
                          child: _NavButton(
                            label: next.title,
                            back: false,
                            onTap: () => _replace(context, next),
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _replace(BuildContext context, ManualArticle a) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ArticlePage(chapter: chapter, article: a),
      ),
    );
  }

  Widget _block(BuildContext context, ManualBlock b, CalcModel model) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final body = text.bodyLarge?.copyWith(height: 1.5, fontSize: 17);
    switch (b) {
      case Para(:final text):
        return SelectableText(text, style: body);
      case Tip(:final text):
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: body?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        );
      case Steps(:final steps):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (n, s) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Text(
                        '${n + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.text, style: body),
                          if (s.keys != null) ...[
                            const SizedBox(height: 6),
                            KeyChips(keys: s.keys!, model: model),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case Example():
        return _ExampleCard(example: b, model: model);
      case RefTable(:final kind):
        return _RefTableView(kind: kind);
    }
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.back,
    required this.onTap,
  });

  final String label;
  final bool back;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: back ? Alignment.centerLeft : Alignment.centerRight,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (back) const Icon(Icons.chevron_left),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: back ? TextAlign.left : TextAlign.right,
            ),
          ),
          if (!back) const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example, required this.model});

  final Example example;
  final CalcModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lcd = CalcSkin.of(context).lcd;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    example.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            if (example.setup != null) ...[
              const SizedBox(height: 10),
              Text('First', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              KeyChips(keys: example.setup!, model: model),
            ],
            const SizedBox(height: 10),
            Text('Press', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            KeyChips(keys: example.keys, model: model),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: lcd.glass,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                example.result,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: lcd.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (example.note != null) ...[
              const SizedBox(height: 8),
              Text(example.note!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A key sequence drawn as small keycaps in the current model's labels;
/// consecutive digits are grouped into one number.
class KeyChips extends StatelessWidget {
  const KeyChips({super.key, required this.keys, required this.model});

  final String keys;
  final CalcModel model;

  static const _arrows = {
    CalcKey.up: '▲',
    CalcKey.down: '▼',
    CalcKey.left: '◀',
    CalcKey.right: '▶',
  };

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    final specs = {for (final s in model.layout.allKeys) s.key: s};
    List<CalcKey> parsed;
    try {
      parsed = parseKeySequence(keys);
    } on FormatException {
      return Text(keys);
    }
    final chips = <Widget>[];
    var number = StringBuffer();
    void flushNumber() {
      if (number.isEmpty) return;
      chips.add(_chip(context, number.toString(), null, digit: true));
      number = StringBuffer();
    }

    CalcKey? modifier;
    for (final k in parsed) {
      if ((k.digit != null || k == CalcKey.dot) && modifier == null) {
        number.write(k == CalcKey.dot ? '.' : '${k.digit}');
        continue;
      }
      flushNumber();
      final spec = specs[k];
      final label = _arrows[k] ?? spec?.main ?? k.name;
      Color? color;
      String? caption;
      if (k == CalcKey.shift) color = skin.label(LabelKind.shift);
      if (k == CalcKey.alpha) color = skin.label(LabelKind.alpha);
      if (modifier != null && spec != null) {
        final kind = modifier == CalcKey.shift
            ? LabelKind.shift
            : LabelKind.alpha;
        for (final l in spec.above) {
          if (l.kind == kind) caption = legendText(l.text);
        }
      }
      chips.add(_chip(context, label, color, caption: caption));
      modifier = k == CalcKey.shift || k == CalcKey.alpha ? k : null;
    }
    flushNumber();
    return Semantics(
      label: 'Keys: $keys',
      child: ExcludeSemantics(
        child: Wrap(spacing: 6, runSpacing: 6, children: chips),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    Color? accent, {
    String? caption,
    bool digit = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = digit
        ? scheme.surfaceContainerHighest
        : (accent ?? scheme.inverseSurface);
    final fg = digit
        ? scheme.onSurface
        : (accent != null ? Colors.black : scheme.onInverseSurface);
    final style = TextStyle(
      color: fg,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Text(
              caption,
              style: style.copyWith(
                fontSize: 10,
                color: fg.withValues(alpha: 0.8),
              ),
            ),
          Text.rich(TextSpan(children: legendSpans(label, style))),
        ],
      ),
    );
  }
}

/// CONST / CONV list with its own filter box.
class _RefTableView extends StatefulWidget {
  const _RefTableView({required this.kind});

  final RefKind kind;

  @override
  State<_RefTableView> createState() => _RefTableViewState();
}

class _RefTableViewState extends State<_RefTableView> {
  String _filter = '';

  /// 1.6726e-27 → "1.672621777 × 10^{-27}" (legend superscript markup).
  static String _value(Dec v) {
    final f = formatNumber(v, const DisplayFormat.norm1());
    var m = f.mantissa;
    if (m.endsWith('.')) m = m.substring(0, m.length - 1);
    final e = f.exponent;
    return e == null ? m : '$m × 10^{${int.parse(e)}}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _filter.toLowerCase();
    final rows =
        <(int, String, String, String)>[
              if (widget.kind == RefKind.constants)
                for (final c in constantTable)
                  (c.number, c.symbol, c.name, '${_value(c.value)}  ${c.unit}')
              else
                for (final c in conversionTable)
                  (c.number, c.symbol, '${c.from} → ${c.to}', ''),
            ]
            .where(
              (r) =>
                  q.isEmpty ||
                  '${r.$1} ${r.$2} ${r.$3}'.toLowerCase().contains(q),
            )
            .toList();
    final style = TextStyle(color: scheme.onSurfaceVariant, fontSize: 15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: Key('ref-filter-${widget.kind.name}'),
          onChanged: (v) => setState(() => _filter = v),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.filter_list),
            hintText: widget.kind == RefKind.constants
                ? 'Filter: light, mass, gas …'
                : 'Filter: inch, gallon, °C …',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        for (final (n, symbol, title, value) in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    n.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text.rich(
                        TextSpan(
                          children: legendSpans(
                            value.isEmpty ? symbol : '$symbol   $value',
                            style,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (rows.isEmpty) Text('No match for “$_filter”.', style: style),
      ],
    );
  }
}
