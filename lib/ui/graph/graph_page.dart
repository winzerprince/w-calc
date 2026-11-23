import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../haptics.dart';
import '../reading_theme.dart';

/// Colours for successive curves (readable on light and dark paper).
const _palette = [
  Color(0xFFE0453A),
  Color(0xFF2F7DE1),
  Color(0xFF2FA35B),
  Color(0xFF8E44D8),
  Color(0xFFE38B12),
  Color(0xFF0FA3A3),
];

/// One function on the graph.
class GraphCurve {
  GraphCurve({required this.text, required this.function, required this.color});

  String text;
  GraphFunction? function;
  final Color color;
  bool visible = true;
  String? error;
}

/// Desmos-style graph: functions listed below, pan and pinch to move,
/// tap to trace, points of interest marked.
class GraphPage extends StatefulWidget {
  const GraphPage({super.key, this.tokens, this.angle = AngleUnit.rad});

  /// A function from the calculator (uses X), or null to start empty.
  final List<Tok>? tokens;
  final AngleUnit angle;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

/// Readable formula text for calculator tokens.
String formulaText(List<Tok> tokens) {
  final b = StringBuffer();
  for (final t in tokens) {
    b.write(switch (t) {
      Tok.varX => 'x',
      Tok.negative || Tok.subtract => '−',
      Tok.multiply => '×',
      Tok.divide || Tok.fracDiv => '/',
      Tok.power => '^',
      Tok.square => '²',
      Tok.cube => '³',
      Tok.sqrt => '√',
      Tok.cAbs => 'abs',
      Tok.ePow => 'exp',
      Tok.tenPow => '10^',
      _ => t.text.trim(),
    });
  }
  return b.toString();
}

class _GraphPageState extends State<GraphPage> {
  final List<GraphCurve> _curves = [];
  late AngleUnit _angle = widget.angle;

  // View: world point at the centre and pixels per unit.
  Offset _center = Offset.zero;
  double _scale = 40;

  // Gesture start state.
  Offset _startCenter = Offset.zero;
  double _startScale = 40;
  Offset _startFocal = Offset.zero;

  /// Traced point: curve index and world x.
  (int, double)? _trace;

  /// Points of interest for the current view (recomputed when idle).
  List<(Offset, String)> _poi = const [];

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    final t = widget.tokens;
    if (t != null) {
      _curves.add(
        GraphCurve(
          text: formulaText(t),
          function: GraphFunction(t, angle: _angle),
          color: _palette[0],
        ),
      );
    } else {
      _addCurve('x^2');
    }
  }

  void _addCurve(String text) {
    final c = GraphCurve(
      text: text,
      function: null,
      color: _palette[_curves.length % _palette.length],
    );
    _curves.add(c);
    _parse(c);
  }

  void _parse(GraphCurve c) {
    try {
      c.function = GraphFunction(parseFormula(c.text), angle: _angle);
      c.error = null;
    } on FormatException catch (e) {
      c.function = null;
      c.error = e.message;
    }
    _poi = const [];
  }

  void _setAngle(AngleUnit a) {
    setState(() {
      _angle = a;
      for (final c in _curves) {
        final f = c.function;
        if (f != null) c.function = GraphFunction(f.tokens, angle: a);
      }
      _poi = const [];
    });
    _schedulePoi();
  }

  Offset _toScreen(Offset w) => Offset(
    _size.width / 2 + (w.dx - _center.dx) * _scale,
    _size.height / 2 - (w.dy - _center.dy) * _scale,
  );

  Offset _toWorld(Offset s) => Offset(
    _center.dx + (s.dx - _size.width / 2) / _scale,
    _center.dy - (s.dy - _size.height / 2) / _scale,
  );

  void _zoom(double factor, [Offset? focal]) {
    final f = focal ?? _size.center(Offset.zero);
    final before = _toWorld(f);
    setState(() {
      _scale = (_scale * factor).clamp(1e-3, 1e6);
      final after = _toWorld(f);
      _center += before - after;
    });
    _schedulePoi();
  }

  int _poiToken = 0;

  /// Roots, extrema and y-intercepts of visible curves, after the view
  /// has settled.
  void _schedulePoi() {
    final token = ++_poiToken;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || token != _poiToken || _size.isEmpty) return;
      final a = _toWorld(Offset.zero).dx,
          b = _toWorld(Offset(_size.width, 0)).dx;
      final pts = <(Offset, String)>[];
      for (final c in _curves) {
        final f = c.function;
        if (!c.visible || f == null) continue;
        for (final r in f.roots(a, b, n: 300)) {
          pts.add((Offset(r, 0), 'root'));
        }
        for (final (x, y, isMax) in f.extrema(a, b, n: 300)) {
          pts.add((Offset(x, y), isMax ? 'maximum' : 'minimum'));
        }
        final y0 = f.at(0);
        if (y0 != null) pts.add((Offset(0, y0), 'y-intercept'));
      }
      setState(() => _poi = pts);
    });
  }

  void _onTap(Offset p) {
    // A point of interest close by wins; otherwise trace the nearest curve.
    for (final (w, _) in _poi) {
      if ((_toScreen(w) - p).distance < 18) {
        _traceAt(w.dx);
        return;
      }
    }
    _traceAt(_toWorld(p).dx, near: p);
  }

  void _traceAt(double x, {Offset? near}) {
    int? best;
    var bestD = double.infinity;
    for (final (i, c) in _curves.indexed) {
      final y = c.visible ? c.function?.at(x) : null;
      if (y == null) continue;
      final d = near == null ? 0.0 : (_toScreen(Offset(x, y)) - near).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    keyVibration();
    setState(() => _trace = best == null ? null : (best, x));
  }

  static String _fmt(double v) {
    if (v == 0) return '0';
    final a = v.abs();
    if (a >= 1e6 || a < 1e-4) return v.toStringAsExponential(4);
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s == '-0' ? '0' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: readingTheme(context),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Graph'),
              actions: [
                SegmentedButton<AngleUnit>(
                  key: const Key('graph-angle'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: AngleUnit.rad, label: Text('Rad')),
                    ButtonSegment(value: AngleUnit.deg, label: Text('Deg')),
                  ],
                  selected: {
                    _angle == AngleUnit.deg ? AngleUnit.deg : AngleUnit.rad,
                  },
                  onSelectionChanged: (s) => _setAngle(s.first),
                ),
                IconButton(
                  tooltip: 'Back to the origin',
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  onPressed: () {
                    setState(() {
                      _center = Offset.zero;
                      _scale = 40;
                      _trace = null;
                    });
                    _schedulePoi();
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (_size != box.biggest) {
                        _size = box.biggest;
                        _schedulePoi();
                      }
                      return Stack(
                        children: [
                          GestureDetector(
                            key: const Key('graph-canvas'),
                            onScaleStart: (d) {
                              _startCenter = _center;
                              _startScale = _scale;
                              _startFocal = d.localFocalPoint;
                            },
                            onScaleUpdate: (d) {
                              setState(() {
                                _scale = (_startScale * d.scale).clamp(
                                  1e-3,
                                  1e6,
                                );
                                // Keep the world point under the fingers.
                                final w0 = Offset(
                                  _startCenter.dx +
                                      (_startFocal.dx - _size.width / 2) /
                                          _startScale,
                                  _startCenter.dy -
                                      (_startFocal.dy - _size.height / 2) /
                                          _startScale,
                                );
                                _center = Offset(
                                  w0.dx -
                                      (d.localFocalPoint.dx - _size.width / 2) /
                                          _scale,
                                  w0.dy +
                                      (d.localFocalPoint.dy -
                                              _size.height / 2) /
                                          _scale,
                                );
                              });
                            },
                            onScaleEnd: (_) => _schedulePoi(),
                            onTapUp: (d) => _onTap(d.localPosition),
                            onDoubleTapDown: (d) => _zoom(2, d.localPosition),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _GraphPainter(
                                center: _center,
                                scale: _scale,
                                curves: _curves,
                                poi: _poi,
                                trace: _trace,
                                paper: scheme.surface,
                                ink: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (_trace case (final i, final x)?)
                            if (_curves[i].function?.at(x) case final y?)
                              Positioned(
                                left: 12,
                                top: 12,
                                child: _Label(
                                  key: const Key('graph-trace'),
                                  color: _curves[i].color,
                                  text: '(${_fmt(x)}, ${_fmt(y)})',
                                ),
                              ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              children: [
                                _RoundButton(
                                  icon: Icons.add,
                                  tooltip: 'Zoom in',
                                  onTap: () => _zoom(1.5),
                                ),
                                const SizedBox(height: 8),
                                _RoundButton(
                                  icon: Icons.remove,
                                  tooltip: 'Zoom out',
                                  onTap: () => _zoom(1 / 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _FunctionList(
                  curves: _curves,
                  onChanged: (c) {
                    setState(() => _parse(c));
                    _schedulePoi();
                  },
                  onToggle: (c) {
                    setState(() => c.visible = !c.visible);
                    _schedulePoi();
                  },
                  onRemove: (c) {
                    setState(() {
                      _curves.remove(c);
                      _trace = null;
                    });
                    _schedulePoi();
                  },
                  onAdd: () {
                    setState(() => _addCurve(''));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({super.key, required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onTap),
    );
  }
}

/// The function list under the graph: colour dot (show / hide), editable
/// formula, remove; "Add function" at the end.
class _FunctionList extends StatelessWidget {
  const _FunctionList({
    required this.curves,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  final List<GraphCurve> curves;
  final ValueChanged<GraphCurve> onChanged;
  final ValueChanged<GraphCurve> onToggle;
  final ValueChanged<GraphCurve> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.32,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final (i, c) in curves.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: c.visible ? 'Hide' : 'Show',
                        onPressed: () => onToggle(c),
                        icon: Icon(
                          c.visible ? Icons.circle : Icons.circle_outlined,
                          color: c.color,
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          key: Key('graph-formula-$i'),
                          initialValue: c.text,
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: 'y = ',
                            hintText: 'type a function of x, e.g. 2x+1',
                            errorText: c.error,
                            border: const OutlineInputBorder(),
                          ),
                          onFieldSubmitted: (v) {
                            c.text = v;
                            onChanged(c);
                          },
                          onChanged: (v) {
                            c.text = v;
                            onChanged(c);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onRemove(c),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('graph-add'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add function'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.center,
    required this.scale,
    required this.curves,
    required this.poi,
    required this.trace,
    required this.paper,
    required this.ink,
  });

  final Offset center;
  final double scale;
  final List<GraphCurve> curves;
  final List<(Offset, String)> poi;
  final (int, double)? trace;
  final Color paper;
  final Color ink;

  /// 1, 2 or 5 × 10ⁿ so grid lines are about 70 px apart.
  static double _step(double scale) {
    final raw = 70 / scale;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (m * p >= raw) return m * p;
    }
    return 10 * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    Offset s(double x, double y) => Offset(
      size.width / 2 + (x - center.dx) * scale,
      size.height / 2 - (y - center.dy) * scale,
    );
    final x0 = center.dx - size.width / 2 / scale;
    final x1 = center.dx + size.width / 2 / scale;
    final y0 = center.dy - size.height / 2 / scale;
    final y1 = center.dy + size.height / 2 / scale;

    final major = _step(scale), minor = major / 5;
    final minorPaint = Paint()
      ..color = ink.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = ink.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (final (step, paint) in [(minor, minorPaint), (major, majorPaint)]) {
      for (var x = (x0 / step).floor() * step; x <= x1; x += step) {
        canvas.drawLine(s(x, y0), s(x, y1), paint);
      }
      for (var y = (y0 / step).floor() * step; y <= y1; y += step) {
        canvas.drawLine(s(x0, y), s(x1, y), paint);
      }
    }

    // Axes and tick labels.
    final axis = Paint()
      ..color = ink.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(s(x0, 0), s(x1, 0), axis);
    canvas.drawLine(s(0, y0), s(0, y1), axis);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    String lab(double v) {
      final r = (v / major).round() * major;
      if (r.abs() < major / 1e6) return '0';
      final t = r.abs() >= 1e5 || r.abs() < 1e-3
          ? r.toStringAsExponential(0)
          : r.toStringAsFixed(
              major < 1 ? (-math.log(major) / math.ln10).ceil() : 0,
            );
      return t;
    }

    final labelStyle = TextStyle(
      color: ink.withValues(alpha: 0.65),
      fontSize: 11,
      fontFamily: 'Barlow',
    );
    final ax = s(0, 0);
    for (var x = (x0 / major).floor() * major; x <= x1; x += major) {
      if ((x).abs() < major / 2) continue;
      tp.text = TextSpan(text: lab(x), style: labelStyle);
      tp.layout();
      final p = s(x, 0);
      final y = (ax.dy + 4).clamp(2.0, size.height - tp.height - 2);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, y));
    }
    for (var y = (y0 / major).floor() * major; y <= y1; y += major) {
      if ((y).abs() < major / 2) continue;
      tp.text = TextSpan(text: lab(y), style: labelStyle);
      tp.layout();
      final p = s(0, y);
      final x = (ax.dx - tp.width - 4).clamp(2.0, size.width - tp.width - 2);
      tp.paint(canvas, Offset(x, p.dy - tp.height / 2));
    }

    // Curves: one sample per 1.5 px, broken at gaps and jumps.
    final n = (size.width / 1.5).ceil();
    for (final c in curves) {
      final f = c.function;
      if (!c.visible || f == null) continue;
      final paint = Paint()
        ..color = c.color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      var pen = false;
      double? prevY;
      for (var k = 0; k <= n; k++) {
        final x = x0 + (x1 - x0) * k / n;
        final y = f.at(x);
        if (y == null || y.isNaN) {
          pen = false;
          prevY = null;
          continue;
        }
        final p = s(x, y);
        final jump =
            prevY != null && (prevY - y).abs() * scale > size.height * 2;
        final py = p.dy.clamp(-size.height, 2 * size.height);
        if (!pen || jump) {
          path.moveTo(p.dx, py);
          pen = true;
        } else {
          path.lineTo(p.dx, py);
        }
        prevY = y;
      }
      canvas.drawPath(path, paint);
    }

    // Points of interest: grey dots.
    final dot = Paint()..color = ink.withValues(alpha: 0.45);
    for (final (w, _) in poi) {
      canvas.drawCircle(s(w.dx, w.dy), 4.5, dot);
    }

    // Trace marker.
    final t = trace;
    if (t != null && t.$1 < curves.length) {
      final c = curves[t.$1];
      final y = c.function?.at(t.$2);
      if (y != null) {
        final p = s(t.$2, y);
        canvas.drawCircle(
          p,
          8,
          Paint()..color = c.color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(p, 5, Paint()..color = c.color);
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}
