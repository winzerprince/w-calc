import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// The visible part of the plane. Positions are kept in "axis space":
/// x itself on a linear axis, log₁₀ x on a logarithmic one.
@immutable
class GraphView {
  const GraphView({
    required this.size,
    required this.center,
    required this.sx,
    required this.sy,
    this.xLog = false,
    this.yLog = false,
  });

  final Size size;

  /// Axis-space point at the middle of the plot.
  final Offset center;

  /// Pixels per axis unit.
  final double sx;
  final double sy;
  final bool xLog;
  final bool yLog;

  static double _log(double v) => v > 0 ? math.log(v) / math.ln10 : double.nan;

  double ax(double x) => xLog ? _log(x) : x;
  double ay(double y) => yLog ? _log(y) : y;
  double wx(double u) => xLog ? math.pow(10, u).toDouble() : u;
  double wy(double v) => yLog ? math.pow(10, v).toDouble() : v;

  double sxOf(double u) => size.width / 2 + (u - center.dx) * sx;
  double syOf(double v) => size.height / 2 - (v - center.dy) * sy;
  double uOf(double px) => center.dx + (px - size.width / 2) / sx;
  double vOf(double py) => center.dy - (py - size.height / 2) / sy;

  /// Screen point of world (x, y); NaN coordinates when off a log axis.
  Offset toScreen(double x, double y) => Offset(sxOf(ax(x)), syOf(ay(y)));

  /// World point under a screen position.
  Offset toWorld(Offset p) => Offset(wx(uOf(p.dx)), wy(vOf(p.dy)));

  double get xMin => wx(uOf(0));
  double get xMax => wx(uOf(size.width));
  double get yMin => wy(vOf(size.height));
  double get yMax => wy(vOf(0));

  GraphView copyWith({
    Size? size,
    Offset? center,
    double? sx,
    double? sy,
    bool? xLog,
    bool? yLog,
  }) => GraphView(
    size: size ?? this.size,
    center: center ?? this.center,
    sx: sx ?? this.sx,
    sy: sy ?? this.sy,
    xLog: xLog ?? this.xLog,
    yLog: yLog ?? this.yLog,
  );

  /// The view showing [x0..x1] × [y0..y1].
  GraphView framing(double x0, double x1, double y0, double y1) {
    final u0 = ax(x0), u1 = ax(x1), v0 = ay(y0), v1 = ay(y1);
    if (![u0, u1, v0, v1].every((v) => v.isFinite) || u1 <= u0 || v1 <= v0) {
      return this;
    }
    return copyWith(
      center: Offset((u0 + u1) / 2, (v0 + v1) / 2),
      sx: size.width / (u1 - u0),
      sy: size.height / (v1 - v0),
    );
  }

  /// 1, 2 or 5 × 10ⁿ so grid lines are about 70 px apart.
  static double step(double scale) {
    final raw = 70 / scale;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (m * p >= raw) return m * p;
    }
    return 10 * p;
  }
}

/// What the grid shows (the wrench panel).
@immutable
class GridOptions {
  const GridOptions({
    this.grid = true,
    this.minor = true,
    this.numbers = true,
    this.xAxis = true,
    this.yAxis = true,
  });

  final bool grid;
  final bool minor;
  final bool numbers;
  final bool xAxis;
  final bool yAxis;

  GridOptions copyWith({
    bool? grid,
    bool? minor,
    bool? numbers,
    bool? xAxis,
    bool? yAxis,
  }) => GridOptions(
    grid: grid ?? this.grid,
    minor: minor ?? this.minor,
    numbers: numbers ?? this.numbers,
    xAxis: xAxis ?? this.xAxis,
    yAxis: yAxis ?? this.yAxis,
  );

  Map<String, Object> toJson() => {
    'grid': grid,
    'minor': minor,
    'numbers': numbers,
    'xAxis': xAxis,
    'yAxis': yAxis,
  };

  static GridOptions fromJson(Map<String, Object?> j) => GridOptions(
    grid: j['grid'] as bool? ?? true,
    minor: j['minor'] as bool? ?? true,
    numbers: j['numbers'] as bool? ?? true,
    xAxis: j['xAxis'] as bool? ?? true,
    yAxis: j['yAxis'] as bool? ?? true,
  );
}

/// One thing to draw.
sealed class Plot {
  const Plot(this.color);

  final Color color;
}

/// y = f(x), optionally shaded above / below.
class CurvePlot extends Plot {
  const CurvePlot(super.color, this.f, {this.rel});

  final double? Function(double x) f;
  final GxRel? rel;
}

/// x = g(y), optionally shaded left / right.
class SidewaysPlot extends Plot {
  const SidewaysPlot(super.color, this.g, {this.rel});

  final double Function(double y) g;
  final GxRel? rel;
}

/// F(x, y) compared with 0.
class ImplicitPlot extends Plot {
  const ImplicitPlot(super.color, this.f, this.rel);

  final double Function(double x, double y) f;
  final GxRel rel;
}

/// A single point.
class PointPlot extends Plot {
  const PointPlot(super.color, this.x, this.y, {this.ring = false});

  final double x;
  final double y;

  /// Data points are drawn as rings.
  final bool ring;
}

/// Paints grid, axes, plots, points of interest and the traced point.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.view,
    required this.grid,
    required this.plots,
    required this.poi,
    required this.trace,
    required this.paper,
    required this.ink,
  });

  final GraphView view;
  final GridOptions grid;
  final List<Plot> plots;
  final List<Offset> poi;
  final (Offset, Color)? trace;
  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _grid(canvas, size);
    for (final p in plots) {
      switch (p) {
        case CurvePlot():
          _curve(canvas, size, p);
        case SidewaysPlot():
          _sideways(canvas, size, p);
        case ImplicitPlot():
          _implicit(canvas, size, p);
        case PointPlot():
          break;
      }
    }
    _labels(canvas, size);
    for (final p in plots.whereType<PointPlot>()) {
      final s = view.toScreen(p.x, p.y);
      if (!s.isFinite) continue;
      if (p.ring) {
        canvas.drawCircle(
          s,
          5,
          Paint()
            ..color = p.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      } else {
        canvas.drawCircle(s, 6, Paint()..color = p.color);
      }
    }
    final dot = Paint()..color = ink.withValues(alpha: 0.45);
    for (final w in poi) {
      final s = view.toScreen(w.dx, w.dy);
      if (s.isFinite) canvas.drawCircle(s, 4.5, dot);
    }
    if (trace case (final w, final c)?) {
      final s = view.toScreen(w.dx, w.dy);
      if (s.isFinite) {
        canvas.drawCircle(s, 9, Paint()..color = c.withValues(alpha: 0.25));
        canvas.drawCircle(s, 5.5, Paint()..color = c);
      }
    }
    canvas.restore();
  }

  // ── grid ────────────────────────────────────────────────────────────

  /// Grid line positions (axis space) and whether each is major.
  Iterable<(double, bool)> _lines(
    double lo,
    double hi,
    double scale,
    bool log,
  ) sync* {
    if (log) {
      final decade = scale; // pixels per decade
      final every = decade < 22 ? (22 / decade).ceil() : 1;
      for (var n = lo.floor(); n <= hi.ceil(); n++) {
        if (n % every == 0) yield (n.toDouble(), true);
        if (grid.minor && decade > 60) {
          for (var k = 2; k <= 9; k++) {
            yield (n + math.log(k) / math.ln10, false);
          }
        }
      }
      return;
    }
    final major = GraphView.step(scale);
    final step = grid.minor ? major / 5 : major;
    var k = (lo / step).floor();
    final end = (hi / step).ceil();
    for (; k <= end; k++) {
      final v = k * step;
      yield (v, (v / major - (v / major).roundToDouble()).abs() < 1e-6);
    }
  }

  void _grid(Canvas canvas, Size size) {
    final u0 = view.uOf(0), u1 = view.uOf(size.width);
    final v0 = view.vOf(size.height), v1 = view.vOf(0);
    if (grid.grid) {
      final minorPaint = Paint()
        ..color = ink.withValues(alpha: 0.06)
        ..strokeWidth = 1;
      final majorPaint = Paint()
        ..color = ink.withValues(alpha: 0.17)
        ..strokeWidth = 1;
      for (final (u, major) in _lines(u0, u1, view.sx, view.xLog)) {
        final x = view.sxOf(u);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          major ? majorPaint : minorPaint,
        );
      }
      for (final (v, major) in _lines(v0, v1, view.sy, view.yLog)) {
        final y = view.syOf(v);
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          major ? majorPaint : minorPaint,
        );
      }
    }
    final axis = Paint()
      ..color = ink.withValues(alpha: 0.75)
      ..strokeWidth = 1.5;
    final o = _origin(size);
    if (grid.xAxis) {
      canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), axis);
    }
    if (grid.yAxis) {
      canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), axis);
    }
  }

  /// Where the axes cross: (0, 0) on linear axes, 1 on log ones.
  Offset _origin(Size size) =>
      Offset(view.sxOf(0), view.syOf(0)); // log axes: 10⁰ = 1

  static String _label(double v, double step, bool log) {
    if (log) {
      final n = v.round();
      if (n >= -3 && n <= 6) {
        final s = math.pow(10, n).toString();
        return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
      }
      return '1e$n';
    }
    final r = (v / step).round() * step;
    if (r.abs() < step / 1e6) return '0';
    if (r.abs() >= 1e5 || r.abs() < 1e-3) return r.toStringAsExponential(0);
    return r
        .toStringAsFixed(step < 1 ? (-math.log(step) / math.ln10).ceil() : 0)
        .replaceFirst('-', '−');
  }

  void _labels(Canvas canvas, Size size) {
    if (!grid.numbers) return;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final style = TextStyle(
      color: ink.withValues(alpha: 0.75),
      fontSize: 12,
      fontFamily: 'Barlow',
      shadows: [Shadow(color: paper, blurRadius: 3)],
    );
    final o = _origin(size);
    final xStep = GraphView.step(view.sx), yStep = GraphView.step(view.sy);
    var zero = false;
    for (final (u, major) in _lines(
      view.uOf(0),
      view.uOf(size.width),
      view.sx,
      view.xLog,
    )) {
      if (!major) continue;
      final isZero = !view.xLog && u.abs() < xStep / 2;
      if (isZero && !grid.yAxis) continue;
      tp.text = TextSpan(text: _label(u, xStep, view.xLog), style: style);
      tp.layout();
      final x = view.sxOf(u);
      final y = (o.dy + 3).clamp(2.0, size.height - tp.height - 2);
      if (isZero) {
        zero = true;
        tp.paint(canvas, Offset(x - tp.width - 4, y));
      } else {
        tp.paint(canvas, Offset(x - tp.width / 2, y));
      }
    }
    for (final (v, major) in _lines(
      view.vOf(size.height),
      view.vOf(0),
      view.sy,
      view.yLog,
    )) {
      if (!major) continue;
      if (!view.yLog && v.abs() < yStep / 2) continue;
      if (zero && view.yLog && v.abs() < 0.5) continue;
      tp.text = TextSpan(text: _label(v, yStep, view.yLog), style: style);
      tp.layout();
      final y = view.syOf(v);
      final x = (o.dx - tp.width - 5).clamp(2.0, size.width - tp.width - 2);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    }
  }

  // ── plots ───────────────────────────────────────────────────────────

  Paint _stroke(Color c) => Paint()
    ..color = c
    ..strokeWidth = 2.6
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _edge(Canvas canvas, Path path, Color c, {bool dashed = false}) {
    if (!dashed) return canvas.drawPath(path, _stroke(c));
    final paint = _stroke(c);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, math.min(d + 8, m.length)), paint);
      }
    }
  }

  void _curve(Canvas canvas, Size size, CurvePlot p) {
    final n = (size.width / 1.5).ceil();
    final path = Path();
    // Runs of drawable samples, for shading.
    final runs = <List<Offset>>[];
    var run = <Offset>[];
    double? prevY;
    for (var k = 0; k <= n; k++) {
      final px = size.width * k / n;
      final x = view.wx(view.uOf(px));
      final y = p.f(x);
      final v = y == null ? double.nan : view.ay(y);
      if (!v.isFinite) {
        if (run.isNotEmpty) runs.add(run);
        run = [];
        prevY = null;
        continue;
      }
      final py = view.syOf(v).clamp(-size.height, 2 * size.height);
      final jump = prevY != null && (prevY - py).abs() > size.height * 1.5;
      if (jump) {
        runs.add(run);
        run = [];
      }
      run.add(Offset(px, py));
      prevY = py;
    }
    if (run.isNotEmpty) runs.add(run);
    final rel = p.rel;
    for (final r in runs) {
      path.moveTo(r.first.dx, r.first.dy);
      for (final q in r.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      if (rel != null && rel != GxRel.eq && r.length > 1) {
        final below = rel == GxRel.lt || rel == GxRel.le;
        final edge = below ? 2 * size.height : -size.height;
        final fill = Path()..moveTo(r.first.dx, edge);
        for (final q in r) {
          fill.lineTo(q.dx, q.dy);
        }
        fill
          ..lineTo(r.last.dx, edge)
          ..close();
        canvas.drawPath(fill, Paint()..color = p.color.withValues(alpha: 0.2));
      }
    }
    _edge(canvas, path, p.color, dashed: rel != null && !rel.inclusive);
  }

  void _sideways(Canvas canvas, Size size, SidewaysPlot p) {
    final n = (size.height / 1.5).ceil();
    final runs = <List<Offset>>[];
    var run = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final py = size.height * k / n;
      final y = view.wy(view.vOf(py));
      final u = view.ax(p.g(y));
      if (!u.isFinite) {
        if (run.isNotEmpty) runs.add(run);
        run = [];
        continue;
      }
      run.add(Offset(view.sxOf(u).clamp(-size.width, 2 * size.width), py));
    }
    if (run.isNotEmpty) runs.add(run);
    final path = Path();
    final rel = p.rel;
    for (final r in runs) {
      path.moveTo(r.first.dx, r.first.dy);
      for (final q in r.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      if (rel != null && rel != GxRel.eq && r.length > 1) {
        final left = rel == GxRel.lt || rel == GxRel.le;
        final edge = left ? -size.width : 2 * size.width;
        final fill = Path()..moveTo(edge, r.first.dy);
        for (final q in r) {
          fill.lineTo(q.dx, q.dy);
        }
        fill
          ..lineTo(edge, r.last.dy)
          ..close();
        canvas.drawPath(fill, Paint()..color = p.color.withValues(alpha: 0.2));
      }
    }
    _edge(canvas, path, p.color, dashed: rel != null && !rel.inclusive);
  }

  /// Marching squares on a coarse grid; inequalities fill the cells whose
  /// centre satisfies them.
  void _implicit(Canvas canvas, Size size, ImplicitPlot p) {
    const cell = 5.0;
    final cols = (size.width / cell).ceil(), rows = (size.height / cell).ceil();
    final xs = [for (var i = 0; i <= cols; i++) view.wx(view.uOf(i * cell))];
    final ys = [for (var j = 0; j <= rows; j++) view.wy(view.vOf(j * cell))];
    final v = List.generate(
      rows + 1,
      (j) => List.generate(cols + 1, (i) => p.f(xs[i], ys[j])),
    );
    if (p.rel != GxRel.eq) {
      final fill = Paint()..color = p.color.withValues(alpha: 0.2);
      for (var j = 0; j < rows; j++) {
        int? start;
        for (var i = 0; i <= cols; i++) {
          final inside =
              i < cols &&
              () {
                final c =
                    (v[j][i] + v[j][i + 1] + v[j + 1][i] + v[j + 1][i + 1]) / 4;
                return c.isFinite && p.rel.holds(c);
              }();
          if (inside) {
            start ??= i;
          } else if (start != null) {
            canvas.drawRect(
              Rect.fromLTRB(start * cell, j * cell, i * cell, (j + 1) * cell),
              fill,
            );
            start = null;
          }
        }
      }
    }
    final path = Path();
    Offset lerp(int i0, int j0, int i1, int j1) {
      final a = v[j0][i0], b = v[j1][i1];
      final t = (a / (a - b)).clamp(0.0, 1.0);
      return Offset((i0 + (i1 - i0) * t) * cell, (j0 + (j1 - j0) * t) * cell);
    }

    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final a = v[j][i],
            b = v[j][i + 1],
            c = v[j + 1][i + 1],
            d = v[j + 1][i];
        if (![a, b, c, d].every((e) => e.isFinite && e.abs() < 1e9)) continue;
        final pts = <Offset>[
          if ((a < 0) != (b < 0)) lerp(i, j, i + 1, j),
          if ((b < 0) != (c < 0)) lerp(i + 1, j, i + 1, j + 1),
          if ((c < 0) != (d < 0)) lerp(i + 1, j + 1, i, j + 1),
          if ((d < 0) != (a < 0)) lerp(i, j + 1, i, j),
        ];
        // Skip sign changes through a pole (tan-like jumps).
        final spread = [a, b, c, d].map((e) => e.abs()).reduce(math.min);
        if (pts.length >= 2 && spread < 1e6) {
          path
            ..moveTo(pts[0].dx, pts[0].dy)
            ..lineTo(pts[1].dx, pts[1].dy);
          if (pts.length == 4) {
            path
              ..moveTo(pts[2].dx, pts[2].dy)
              ..lineTo(pts[3].dx, pts[3].dy);
          }
        }
      }
    }
    _edge(canvas, path, p.color, dashed: !p.rel.inclusive);
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}
