import 'package:flutter/widgets.dart';

/// Builds spans for a key legend. `^{...}` marks a superscript, e.g.
/// `x^{-1}`, `10^{x}`, `^{3}√`. Superscripts are drawn smaller and raised,
/// so no superscript glyphs are needed in the bundled fonts.
List<InlineSpan> legendSpans(String legend, TextStyle style) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\^\{([^}]*)\}');
  var last = 0;
  for (final m in pattern.allMatches(legend)) {
    if (m.start > last) {
      spans.add(TextSpan(text: legend.substring(last, m.start), style: style));
    }
    final size = (style.fontSize ?? 14) * 0.75;
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
          offset: Offset(0, -size * 0.55),
          child: Text(
            m.group(1)!.replaceAll('-', '−'),
            style: style.copyWith(fontSize: size),
          ),
        ),
      ),
    );
    last = m.end;
  }
  if (last < legend.length) {
    spans.add(TextSpan(text: legend.substring(last), style: style));
  }
  return spans;
}

/// Plain-text form of a legend (`x^{-1}` → `x-1`), for semantics.
String legendText(String legend) =>
    legend.replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) => m.group(1)!);
