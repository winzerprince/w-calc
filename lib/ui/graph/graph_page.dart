import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../haptics.dart';
import '../reading_theme.dart';
import '../tour/tours.dart';
import 'graph_painter.dart';
import 'gx_keypad.dart';
import 'gx_view.dart';

/// Curve colours (readable on light and dark paper).
const _palette = [
  Color(0xFFC74440),
  Color(0xFF2D70B3),
  Color(0xFF388C46),
  Color(0xFF6042A6),
  Color(0xFFE07B12),
  Color(0xFF0FA3A3),
];

/// One row of the expression list.
class _Expr {
  _Expr(this.id, GxRow row, this.color) : editor = GxEditor(row);

  final int id;
  GxEditor editor;
  int color;
  bool hidden = false;

  // Slider settings.
  double min = -10;
  double max = 10;
  double step = 0;
  bool playing = false;
  bool loop = false;
  double dir = 1;

  /// A curve handed over by the calculator (drawn with its own maths
  /// until the row is edited).
  GraphFunction? external;

  GxStatement st = gxAnalyse(GxRow());

  /// y = f(x) for tracing and points of interest.
  GraphFunction? fn;

  /// Shown as "= value" for constant rows.
  double? value;

  GxRow get row => editor.root;

  Map<String, Object?> toJson() => {
    't': row.toText(),
    'c': color,
    if (hidden) 'h': true,
    if (min != -10) 'min': min,
    if (max != 10) 'max': max,
    if (step != 0) 'step': step,
    if (loop) 'loop': true,
  };

  static _Expr fromJson(int id, Map<String, Object?> j) =>
      _Expr(id, GxRow.parse(j['t'] as String? ?? ''), j['c'] as int? ?? 0)
        ..hidden = j['h'] as bool? ?? false
        ..min = (j['min'] as num?)?.toDouble() ?? -10
        ..max = (j['max'] as num?)?.toDouble() ?? 10
        ..step = (j['step'] as num?)?.toDouble() ?? 0
        ..loop = j['loop'] as bool? ?? false;
}

/// Desmos-style graphing: a typeset expression list with its own maths
/// keypad under the plot; sliders for variables; settings behind the
/// wrench.
class GraphPage extends StatefulWidget {
  const GraphPage({super.key, this.spec, this.angle = AngleUnit.rad});

  /// What the calculator offers to draw, or null for graph mode.
  final GraphSpec? spec;
  final AngleUnit angle;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage>
    with SingleTickerProviderStateMixin {
  final List<_Expr> _exprs = [];
  int _nextId = 0;
  final GxEnv _env = GxEnv();

  /// Focused row (keypad shown) or null.
  int? _focus;
  bool _editMode = false;
  bool _collapsed = false;
  bool _settings = false;

  GridOptions _grid = const GridOptions();
  GraphView _view = const GraphView(
    size: Size.zero,
    center: Offset.zero,
    sx: 40,
    sy: 40,
  );
  bool _framed = false;

  // Pinch / pan start.
  GraphView? _start;
  Offset _startFocal = Offset.zero;

  /// Traced row id and world x.
  (int, double)? _trace;
  List<Offset> _poi = const [];

  /// Statistics data from the calculator.
  List<Offset> _points = const [];
  bool _pointsHidden = false;

  final List<String> _undo = [];
  final List<String> _redo = [];
  String? _lastEditKey;
  DateTime _lastEdit = DateTime(0);

  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  final ValueNotifier<bool> _blink = ValueNotifier(true);
  Timer? _blinkTimer;
  final FocusNode _keys = FocusNode(debugLabel: 'graph-keys');
  final ScrollController _listScroll = ScrollController();

  /// Scrolls the list so a row added at the end is in view.
  void _revealEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScroll.hasClients) {
        _listScroll.jumpTo(_listScroll.position.maxScrollExtent);
      }
    });
  }

  static const _storeKey = 'wcalc.graph.v2';
  static const _oldKey = 'wcalc.graph.v1';
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _env.degrees = widget.angle == AngleUnit.deg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runTourOnce(context, Tours.graph, () => graphTour);
    });
    final spec = widget.spec;
    if (spec == null) {
      _add(GxRow.parse('x^2'));
      _analyse();
      _restore();
      return;
    }
    for (final (label, f) in spec.curves) {
      _add(GxRow.parse(label)).external = f;
    }
    _points = [for (final p in spec.points) Offset(p.x, p.y)];
    _restored = true;
    _analyse();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blinkTimer?.cancel();
    _blink.dispose();
    _keys.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  _Expr _add(GxRow row, {int? at}) {
    final used = _exprs.map((e) => e.color).toSet();
    final color = List.generate(_palette.length, (i) => i).firstWhere(
      (i) => !used.contains(i),
      orElse: () => _exprs.length % _palette.length,
    );
    final e = _Expr(_nextId++, row, color);
    _exprs.insert(at ?? _exprs.length, e);
    return e;
  }

  // ── persistence and undo ─────────────────────────────────────────────

  String _snapshot() => jsonEncode({
    'exprs': [
      for (final e in _exprs)
        if (e.external == null) e.toJson(),
    ],
    'grid': _grid.toJson(),
    'deg': _env.degrees,
    'xLog': _view.xLog,
    'yLog': _view.yLog,
  });

  void _load(String json, {bool settings = true}) {
    final j = jsonDecode(json) as Map<String, Object?>;
    _exprs.removeWhere((e) => e.external == null);
    for (final x in (j['exprs'] as List? ?? const [])) {
      final e = _Expr.fromJson(_nextId++, (x as Map).cast<String, Object?>());
      _exprs.add(e);
    }
    if (settings) {
      _grid = GridOptions.fromJson(
        (j['grid'] as Map? ?? const {}).cast<String, Object?>(),
      );
      _env.degrees = j['deg'] as bool? ?? _env.degrees;
      _view = _view.copyWith(
        xLog: j['xLog'] as bool? ?? false,
        yLog: j['yLog'] as bool? ?? false,
      );
    }
    _focus = null;
    _trace = null;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storeKey);
      final old = prefs.getStringList(_oldKey);
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _load(saved);
          _analyse();
        });
      } else if (old != null && old.isNotEmpty) {
        setState(() {
          _exprs.clear();
          for (final t in old) {
            _add(GxRow.parse(t));
          }
          _analyse();
        });
      }
    } on Object {
      // No storage: start with the example.
    } finally {
      _restored = true;
    }
  }

  Timer? _saveTimer;

  void _save() {
    if (widget.spec != null || !_restored) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      final s = _snapshot();
      SharedPreferences.getInstance()
          .then((p) => p.setString(_storeKey, s))
          .catchError((Object _) => true);
    });
  }

  /// Records the state before a change; typing into one row (same [key])
  /// within a second is one step.
  void _remember([String? key]) {
    final now = DateTime.now();
    if (key != null &&
        key == _lastEditKey &&
        now.difference(_lastEdit) < const Duration(seconds: 1)) {
      _lastEdit = now;
      return;
    }
    _lastEditKey = key;
    _lastEdit = now;
    _undo.add(_snapshot());
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoRedo(bool undo) {
    final from = undo ? _undo : _redo, to = undo ? _redo : _undo;
    if (from.isEmpty) return;
    keyVibration();
    setState(() {
      to.add(_snapshot());
      _load(from.removeLast());
      _lastEditKey = null;
      _analyse();
    });
  }

  // ── meaning of the rows ──────────────────────────────────────────────

  void _analyse() {
    final fnNames = {
      for (final e in _exprs)
        if (e.external == null) ?gxDefinedFunction(e.row),
    };
    _env
      ..vars.clear()
      ..fns.clear();
    for (final e in _exprs) {
      e.fn = null;
      e.value = null;
      if (e.external != null) {
        e.fn = e.external;
        continue;
      }
      e.st = gxAnalyse(e.row, functions: fnNames);
    }
    for (final e in _exprs) {
      final st = e.st;
      if (e.external != null) continue;
      if (st.shape == GxShape.slider) _env.vars[st.name!] = st.number!;
      if (st.shape == GxShape.userFunction) {
        _env.fns[st.name!] = GxUserFn(st.params, st.f!);
      }
    }
    // Definitions may use each other: settle in a few passes.
    final defs = [
      for (final e in _exprs)
        if (e.external == null && e.st.shape == GxShape.define) e,
    ];
    for (var pass = 0; pass <= defs.length; pass++) {
      for (final e in defs) {
        _env.vars[e.st.name!] = e.st.f!(_env);
      }
    }
    for (final e in _exprs) {
      if (e.external != null) continue;
      final st = e.st;
      final f = st.f;
      switch (st.shape) {
        case GxShape.function when st.rel == null || st.rel == GxRel.eq:
          e.fn = GraphFunction.of((x) {
            _env.x = x;
            return f!(_env);
          });
        case GxShape.userFunction
            when st.params.length == 1 && st.params.first == 'x':
          e.fn = GraphFunction.of((x) {
            _env.x = x;
            return f!(_env);
          });
        case GxShape.value || GxShape.define:
          e.value = f!(_env);
        default:
      }
    }
    _poi = const [];
    _save();
    _schedulePoi();
  }

  Set<String> get _defined => {
    for (final e in _exprs)
      if (e.external == null &&
          (e.st.shape == GxShape.slider ||
              e.st.shape == GxShape.define ||
              e.st.shape == GxShape.userFunction))
        e.st.name!,
  };

  List<Plot> _plots(Color ink) {
    final out = <Plot>[];
    for (final e in _exprs) {
      if (e.hidden) continue;
      final c = _palette[e.color % _palette.length];
      final st = e.st, f = st.f;
      if (e.external != null) {
        out.add(CurvePlot(c, e.external!.at));
        continue;
      }
      switch (st.shape) {
        case GxShape.function || GxShape.userFunction
            when e.fn != null || st.rel != null:
          if (st.shape == GxShape.userFunction && e.fn == null) break;
          out.add(
            CurvePlot(c, (x) {
              _env.x = x;
              final y = f!(_env);
              return y.isFinite ? y : null;
            }, rel: st.rel),
          );
        case GxShape.xFunction:
          out.add(
            SidewaysPlot(c, (y) {
              _env.y = y;
              return f!(_env);
            }, rel: st.rel),
          );
        case GxShape.implicit:
          out.add(
            ImplicitPlot(c, (x, y) {
              _env
                ..x = x
                ..y = y;
              return f!(_env);
            }, st.rel!),
          );
        case GxShape.point:
          final x = f!(_env), y = st.g!(_env);
          if (x.isFinite && y.isFinite) out.add(PointPlot(c, x, y));
        default:
      }
    }
    if (!_pointsHidden) {
      for (final p in _points) {
        out.add(
          PointPlot(
            _exprs.isEmpty ? ink : _palette[_exprs.first.color],
            p.dx,
            p.dy,
            ring: true,
          ),
        );
      }
    }
    return out;
  }

  // ── points of interest and tracing ───────────────────────────────────

  int _poiToken = 0;

  void _schedulePoi() {
    final token = ++_poiToken;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || token != _poiToken || _view.size.isEmpty) return;
      final a = _view.xMin, b = _view.xMax;
      if (!a.isFinite || !b.isFinite) return;
      final pts = <Offset>[];
      final shown = [
        for (final e in _exprs)
          if (!e.hidden && e.fn != null) e.fn!,
      ];
      for (final f in shown) {
        for (final r in f.roots(a, b, n: 300)) {
          pts.add(Offset(r, 0));
        }
        for (final (x, y, _) in f.extrema(a, b, n: 300)) {
          pts.add(Offset(x, y));
        }
        if (a <= 0 && b >= 0) {
          if (f.at(0) case final y0?) pts.add(Offset(0, y0));
        }
      }
      for (var i = 0; i < shown.length; i++) {
        for (var j = i + 1; j < shown.length; j++) {
          for (final p in intersections(shown[i], shown[j], a, b)) {
            pts.add(Offset(p.x, p.y));
          }
        }
      }
      setState(() => _poi = pts);
    });
  }

  void _onTap(Offset p) {
    if (_settings) return setState(() => _settings = false);
    if (_focus != null) _unfocus();
    for (final w in _poi) {
      final s = _view.toScreen(w.dx, w.dy);
      if ((s - p).distance < 18) return _traceAt(w.dx);
    }
    _traceAt(_view.toWorld(p).dx, near: p);
  }

  void _traceAt(double x, {Offset? near}) {
    int? best;
    var bestD = double.infinity;
    for (final e in _exprs) {
      final y = e.hidden ? null : e.fn?.at(x);
      if (y == null) continue;
      final d = near == null ? 0.0 : (_view.toScreen(x, y) - near).distance;
      if (d < bestD) {
        bestD = d;
        best = e.id;
      }
    }
    keyVibration();
    setState(() => _trace = best == null ? null : (best, x));
  }

  _Expr? _byId(int id) => _exprs.where((e) => e.id == id).firstOrNull;

  // ── view ─────────────────────────────────────────────────────────────

  void _home() {
    final w = _view.size.width;
    setState(() {
      _view = _view.copyWith(
        center: Offset.zero,
        sx: w > 0 ? w / 22 : 40,
        sy: w > 0 ? w / 22 : 40,
      );
      if (_view.xLog || _view.yLog) {
        _view = _view.copyWith(
          sx: _view.xLog ? w / 6 : null,
          sy: _view.yLog ? w / 6 : null,
        );
      }
      _trace = null;
    });
    _schedulePoi();
  }

  void _zoom(double factor, [Offset? focal]) {
    final f = focal ?? _view.size.center(Offset.zero);
    final u = _view.uOf(f.dx), v = _view.vOf(f.dy);
    setState(() {
      final sx = (_view.sx * factor).clamp(1e-4, 1e7);
      final sy = (_view.sy * factor).clamp(1e-4, 1e7);
      _view = _view.copyWith(
        sx: sx,
        sy: sy,
        center: Offset(
          u - (f.dx - _view.size.width / 2) / sx,
          v + (f.dy - _view.size.height / 2) / sy,
        ),
      );
    });
    _schedulePoi();
  }

  void _fitPoints() {
    final xs = _points.map((p) => p.dx), ys = _points.map((p) => p.dy);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    _view = _view.framing(
      minX - w * 0.2,
      maxX + w * 0.2,
      minY - h * 0.2,
      maxY + h * 0.2,
    );
  }

  // ── editing ─────────────────────────────────────────────────────────

  void _focusRow(int index, {GxCursor? at}) {
    final e = _exprs[index];
    if (at != null) e.editor.moveTo(at);
    if (_focus != index && at == null) e.editor.end();
    setState(() {
      _focus = index;
      _settings = false;
      _collapsed = false;
    });
    _blink.value = true;
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(
      const Duration(milliseconds: 530),
      (_) => _blink.value = !_blink.value,
    );
    _keys.requestFocus();
  }

  void _unfocus() {
    _blinkTimer?.cancel();
    setState(() => _focus = null);
  }

  void _edit(GxEdit edit) {
    final i = _focus;
    if (i == null || i >= _exprs.length) return;
    final e = _exprs[i];
    _remember('type-${e.id}');
    setState(() {
      edit(e.editor);
      e.external = null;
      _analyse();
    });
    _blink.value = true;
  }

  void _enter() {
    final i = _focus;
    if (i == null) return;
    // ↵ moves to the next row, adding one at the end.
    if (i == _exprs.length - 1) {
      if (_exprs[i].row.isEmpty) return _unfocus();
      _remember();
      setState(() => _add(GxRow()));
      _revealEnd();
    }
    _focusRow(i + 1);
  }

  void _newRow() {
    _remember();
    setState(() {
      _add(GxRow());
      _analyse();
    });
    _focusRow(_exprs.length - 1);
    _revealEnd();
  }

  void _remove(_Expr e) {
    _remember();
    setState(() {
      final i = _exprs.indexOf(e);
      _exprs.remove(e);
      if (_focus != null) {
        if (_focus == i) {
          _focus = null;
        } else if (_focus! > i) {
          _focus = _focus! - 1;
        }
      }
      if (_trace?.$1 == e.id) _trace = null;
      _analyse();
    });
  }

  void _duplicate(_Expr e) {
    _remember();
    setState(() {
      final c = _add(e.row.copy(), at: _exprs.indexOf(e) + 1)
        ..min = e.min
        ..max = e.max
        ..step = e.step;
      c.external = e.external;
      _analyse();
    });
  }

  void _deleteAll() {
    _remember();
    setState(() {
      _exprs.clear();
      _points = const [];
      _focus = null;
      _trace = null;
      _editMode = false;
      _analyse();
    });
  }

  void _addSliders(_Expr after, Iterable<String> names) {
    _remember();
    setState(() {
      var at = _exprs.indexOf(after);
      for (final n in names) {
        _add(GxRow.parse('${_nameText(n)}=1'), at: ++at);
      }
      _analyse();
    });
  }

  static String _nameText(String name) {
    final i = name.indexOf('_');
    return i < 0 ? name : '${name.substring(0, i)}_{${name.substring(i + 1)}}';
  }

  void _setSlider(_Expr e, double v, {bool record = true}) {
    if (record) _remember('slider-${e.id}');
    final st = e.st;
    if (st.shape != GxShape.slider) return;
    final s = _sliderText(e, v);
    final focused = _focus != null && _exprs[_focus!] == e;
    e.editor = GxEditor(GxRow.parse('${_nameText(st.name!)}=$s'));
    if (focused) e.editor.end();
    _analyse();
  }

  /// Slider value text: snapped to the step, or to a sensible precision.
  static String _sliderText(_Expr e, double v) {
    if (e.step > 0) v = e.min + ((v - e.min) / e.step).round() * e.step;
    final unit = e.step > 0 ? e.step : (e.max - e.min).abs() / 1000;
    final decimals = unit >= 1
        ? 0
        : (-math.log(unit) / math.ln10).ceil().clamp(0, 8);
    var s = v.toStringAsFixed(decimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s == '-0' ? '0' : s;
  }

  void _togglePlay(_Expr e) {
    setState(() => e.playing = !e.playing);
    if (_exprs.any((x) => x.playing)) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration t) {
    final dt = (t - _lastTick).inMicroseconds / 1e6;
    _lastTick = t;
    if (dt <= 0 || dt > 0.5) return;
    final playing = [
      for (final e in _exprs)
        if (e.playing && e.st.shape == GxShape.slider) e,
    ];
    if (playing.isEmpty) {
      _ticker.stop();
      return;
    }
    setState(() {
      for (final e in playing) {
        final span = e.max - e.min;
        var v = e.st.number! + e.dir * span * dt / 6;
        if (v > e.max || v < e.min) {
          if (e.loop) {
            v = e.dir > 0 ? e.min : e.max;
          } else {
            e.dir = -e.dir;
            v = v.clamp(e.min, e.max);
          }
        }
        _setSlider(e, v, record: false);
      }
    });
  }

  void _setAngle(bool degrees) {
    _remember();
    setState(() {
      _env.degrees = degrees;
      for (final e in _exprs) {
        final f = e.external;
        if (f != null && f.tokens.isNotEmpty) {
          e.external = GraphFunction(
            f.tokens,
            angle: degrees ? AngleUnit.deg : AngleUnit.rad,
          );
        }
      }
      _analyse();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent ev) {
    if (_focus == null || ev is KeyUpEvent) return KeyEventResult.ignored;
    final k = ev.logicalKey;
    if (k == LogicalKeyboardKey.backspace) {
      _edit((e) => e.backspace());
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _edit((e) => e.left());
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _edit((e) => e.right());
    } else if (k == LogicalKeyboardKey.enter) {
      _enter();
    } else if (k == LogicalKeyboardKey.escape) {
      _unfocus();
    } else {
      final c = ev.character;
      if (c == null || c.isEmpty || c.codeUnitAt(0) < 32) {
        return KeyEventResult.ignored;
      }
      if (c == '|') {
        _edit((e) => e.box(GxKind.abs));
      } else if (RegExp(r'^[A-Za-z0-9+\-*/^_()=<>,.!]$').hasMatch(c)) {
        _edit((e) => e.type(c));
      } else {
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.handled;
  }

  // ── table and summary ───────────────────────────────────────────────

  void _showTable(_Expr e) {
    final f = e.fn;
    if (f == null) return;
    final step = GraphView.step(_view.sx) / 2;
    final from = (_view.xMin / step).ceil() * step;
    final xs = [for (var k = 0; k < 21; k++) from + k * step];
    final color = _palette[e.color % _palette.length];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: DataTable(
            key: const Key('graph-values'),
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columnSpacing: 28,
            columns: [
              const DataColumn(
                label: Text('x', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              DataColumn(
                label: Text(
                  'y',
                  style: TextStyle(color: color, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            rows: [
              for (final x in xs)
                DataRow(
                  onSelectChanged: (_) {
                    Navigator.pop(sheet);
                    setState(() => _trace = (e.id, x));
                  },
                  cells: [
                    DataCell(Text(_fmt(x))),
                    DataCell(
                      Text(switch (f.at(x)) {
                        final y? => _fmt(y),
                        null => '—',
                      }),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _summary() {
    final shown = [
      for (final e in _exprs)
        if (!e.hidden && (e.st.isPlot || e.external != null))
          e.st.shape == GxShape.function && !e.row.plain().contains('=')
              ? 'y = ${e.row.plain()}'
              : e.row.plain(),
    ];
    if (shown.isEmpty && _points.isEmpty) return 'Empty graph';
    final parts = <String>['Graph of ${shown.join(', ')}'];
    final roots = [
      for (final p in _poi)
        if (p.dy == 0) _fmt(p.dx),
    ];
    if (roots.isNotEmpty) parts.add('roots at x = ${roots.join(', ')}');
    if (_points.isNotEmpty) parts.add('${_points.length} data points');
    return parts.join('; ');
  }

  static String _fmt(double v) {
    if (v == 0) return '0';
    if (!v.isFinite) return v.isNaN ? 'undefined' : (v > 0 ? '∞' : '−∞');
    final a = v.abs();
    if (a >= 1e9 || a < 1e-5) {
      return v.toStringAsExponential(4).replaceFirst('-', '−');
    }
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    if (s == '-0') return '0';
    return s.replaceFirst('-', '−');
  }

  // ── build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppPageTheme(
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Focus(
            focusNode: _keys,
            onKeyEvent: _onKey,
            child: Scaffold(
              body: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, outer) {
                    final wide = outer.maxWidth > outer.maxHeight * 1.2;
                    final plot = _plot(context, scheme);
                    final panel = _panel(context, scheme, wide: wide);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: plot),
                          if (!_collapsed)
                            SizedBox(width: outer.maxWidth * 0.4, child: panel),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: plot),
                        if (!_collapsed) panel,
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _plot(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, box) {
        if (_view.size != box.biggest) {
          final first = _view.size.isEmpty;
          _view = _view.copyWith(size: box.biggest);
          if (first) {
            _view = _view.copyWith(
              sx: box.maxWidth / 22,
              sy: box.maxWidth / 22,
            );
            if (_view.xLog) _view = _view.copyWith(sx: box.maxWidth / 6);
            if (_view.yLog) _view = _view.copyWith(sy: box.maxWidth / 6);
          }
          if (!_framed && _points.isNotEmpty) {
            _framed = true;
            _fitPoints();
          }
          _schedulePoi();
        }
        final traced = _trace == null ? null : _byId(_trace!.$1);
        final ty = traced?.fn?.at(_trace!.$2);
        final traceColor = traced == null
            ? null
            : _palette[traced.color % _palette.length];
        return Stack(
          children: [
            Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  _zoom(
                    e.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15,
                    e.localPosition,
                  );
                }
              },
              child: GestureDetector(
                key: const Key('graph-canvas'),
                onScaleStart: (d) {
                  _start = _view;
                  _startFocal = d.localFocalPoint;
                },
                onScaleUpdate: (d) {
                  final s = _start;
                  if (s == null) return;
                  setState(() {
                    final sx = (s.sx * d.scale).clamp(1e-4, 1e7);
                    final sy = (s.sy * d.scale).clamp(1e-4, 1e7);
                    final u = s.uOf(_startFocal.dx), v = s.vOf(_startFocal.dy);
                    _view = _view.copyWith(
                      sx: sx,
                      sy: sy,
                      center: Offset(
                        u - (d.localFocalPoint.dx - s.size.width / 2) / sx,
                        v + (d.localFocalPoint.dy - s.size.height / 2) / sy,
                      ),
                    );
                  });
                },
                onScaleEnd: (_) => _schedulePoi(),
                onTapUp: (d) => _onTap(d.localPosition),
                onDoubleTapDown: (d) => _zoom(2, d.localPosition),
                child: Semantics(
                  label: _summary(),
                  child: CustomPaint(
                    key: TourKeys.graphCanvas,
                    size: Size.infinite,
                    painter: GraphPainter(
                      view: _view,
                      grid: _grid,
                      plots: _plots(scheme.onSurface),
                      poi: _poi,
                      trace: ty == null
                          ? null
                          : (Offset(_trace!.$2, ty), traceColor!),
                      paper: scheme.surface,
                      ink: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: _PlotButton(
                key: const Key('graph-back'),
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            if (ty != null)
              Positioned(
                left: 60,
                top: 14,
                child: _Label(
                  key: const Key('graph-trace'),
                  color: traceColor!,
                  text: '(${_fmt(_trace!.$2)}, ${_fmt(ty)})',
                ),
              ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _PlotButton(
                    key: const Key('graph-settings'),
                    icon: Icons.build_outlined,
                    tooltip: 'Graph settings',
                    selected: _settings,
                    onTap: () => setState(() => _settings = !_settings),
                  ),
                  const SizedBox(height: 8),
                  _PlotButton(
                    key: const Key('graph-home'),
                    icon: Icons.home_outlined,
                    tooltip: 'Default view',
                    onTap: _home,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                children: [
                  _PlotButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () => _zoom(1.5),
                  ),
                  const SizedBox(height: 8),
                  _PlotButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () => _zoom(1 / 1.5),
                  ),
                  if (_collapsed) ...[
                    const SizedBox(height: 8),
                    _PlotButton(
                      key: const Key('graph-expand'),
                      icon: Icons.keyboard_double_arrow_up,
                      tooltip: 'Show expressions',
                      onTap: () => setState(() => _collapsed = false),
                    ),
                  ],
                ],
              ),
            ),
            if (_settings)
              Positioned(
                right: 60,
                top: 10,
                child: _SettingsPanel(
                  key: const Key('graph-settings-panel'),
                  grid: _grid,
                  view: _view,
                  degrees: _env.degrees,
                  onGrid: (g) {
                    _remember();
                    setState(() => _grid = g);
                    _save();
                  },
                  onView: (v) {
                    setState(() => _view = v);
                    _save();
                    _schedulePoi();
                  },
                  onLog: (x, y) {
                    _remember();
                    setState(() {
                      _view = _view.copyWith(xLog: x, yLog: y);
                    });
                    _home();
                    _save();
                  },
                  onDegrees: _setAngle,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _panel(
    BuildContext context,
    ColorScheme scheme, {
    required bool wide,
  }) {
    final h = MediaQuery.sizeOf(context).height;
    final keypad = _focus != null;
    final defined = _defined;
    final list = ListView.builder(
      key: const Key('graph-list'),
      controller: _listScroll,
      padding: EdgeInsets.zero,
      itemCount: _exprs.length + 1 + (_points.isEmpty ? 0 : 1),
      itemBuilder: (context, i) {
        if (_points.isNotEmpty) {
          if (i == 0) {
            return _DataRow(
              count: _points.length,
              color: _exprs.isEmpty
                  ? scheme.onSurface
                  : _palette[_exprs.first.color],
              hidden: _pointsHidden,
              onToggle: () => setState(() => _pointsHidden = !_pointsHidden),
            );
          }
          i--;
        }
        if (i == _exprs.length) {
          return _NewRow(number: i + 1, onTap: _newRow);
        }
        final e = _exprs[i];
        return _ExprRow(
          key: ObjectKey(e),
          index: i,
          expr: e,
          color: _palette[e.color % _palette.length],
          focused: _focus == i,
          editMode: _editMode,
          blink: _blink,
          free: e.external == null ? e.st.free(defined) : const {},
          sliderText: e.st.shape == GxShape.slider
              ? _sliderText(e, e.st.number!)
              : null,
          valueText: e.value == null ? null : _fmt(e.value!),
          onCaret: (c) => _focusRow(i, at: c),
          onFocus: () => _focusRow(i),
          onRemove: () => _remove(e),
          onToggle: () {
            _remember();
            setState(() => e.hidden = !e.hidden);
            _save();
            _schedulePoi();
          },
          onColor: () => _pickColor(e),
          onSlide: (v, end) => setState(() => _setSlider(e, v)),
          onPlay: () => _togglePlay(e),
          onLoop: () => setState(() => e.loop = !e.loop),
          onRange: (lo, hi, step) {
            _remember();
            setState(() {
              e
                ..min = lo
                ..max = hi
                ..step = step;
            });
            _save();
          },
          onAddSliders: (names) => _addSliders(e, names),
          onTable: () => _showTable(e),
          onDuplicate: () => _duplicate(e),
        );
      },
    );
    final toolbar = _Toolbar(
      editMode: _editMode,
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
      onAdd: _newRow,
      onUndo: () => _undoRedo(true),
      onRedo: () => _undoRedo(false),
      onEdit: () => setState(() {
        _editMode = !_editMode;
        _focus = null;
      }),
      onDeleteAll: _deleteAll,
      onCollapse: () => setState(() {
        _collapsed = true;
        _focus = null;
      }),
    );
    final body = Material(
      key: TourKeys.graphList,
      color: scheme.surface,
      elevation: 8,
      child: Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          toolbar,
          Divider(height: 1, color: scheme.outlineVariant),
          if (wide)
            Expanded(child: list)
          else
            SizedBox(height: keypad ? h * 0.2 : h * 0.36, child: list),
          if (keypad) GxKeypad(onEdit: _edit, onEnter: _enter),
        ],
      ),
    );
    return body;
  }

  void _pickColor(_Expr e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final (i, c) in _palette.indexed)
                InkResponse(
                  key: Key('graph-color-$i'),
                  onTap: () {
                    _remember();
                    setState(() => e.color = i);
                    _save();
                    Navigator.pop(sheet);
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: c,
                    child: e.color == i
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── widgets ─────────────────────────────────────────────────────────────

class _PlotButton extends StatelessWidget {
  const _PlotButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.editMode,
    required this.canUndo,
    required this.canRedo,
    required this.onAdd,
    required this.onUndo,
    required this.onRedo,
    required this.onEdit,
    required this.onDeleteAll,
    required this.onCollapse,
  });

  final bool editMode;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onAdd;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onEdit;
  final VoidCallback onDeleteAll;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          if (editMode)
            FilledButton(
              key: const Key('graph-delete-all'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onDeleteAll,
              child: const Text('Delete all'),
            )
          else
            IconButton(
              key: const Key('graph-add'),
              tooltip: 'Add expression',
              icon: const Icon(Icons.add, size: 28),
              onPressed: onAdd,
            ),
          const Spacer(),
          IconButton(
            key: const Key('graph-undo'),
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            key: const Key('graph-redo'),
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: canRedo ? onRedo : null,
          ),
          const Spacer(),
          if (editMode)
            FilledButton(
              key: const Key('graph-edit-done'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onEdit,
              child: const Text('Done'),
            )
          else ...[
            IconButton(
              key: const Key('graph-edit'),
              tooltip: 'Edit list',
              icon: const Icon(Icons.settings_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              key: const Key('graph-collapse'),
              tooltip: 'Hide expressions',
              icon: const Icon(Icons.keyboard_double_arrow_down),
              onPressed: onCollapse,
            ),
          ],
        ],
      ),
    );
  }
}

/// Left column of a row: its number, and the colour / play button.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.number,
    required this.focused,
    required this.child,
  });

  final int number;
  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      color: focused ? scheme.primary : scheme.surfaceContainerHighest,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 2,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                color: focused ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

/// The coloured curve icon (hollow when hidden).
class _CurveIcon extends StatelessWidget {
  const _CurveIcon({required this.color, required this.hidden});

  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 36),
      painter: _CurveIconPainter(color, hidden),
    );
  }
}

class _CurveIconPainter extends CustomPainter {
  _CurveIconPainter(this.color, this.hidden);

  final Color color;
  final bool hidden;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..color = hidden ? Colors.white : color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (hidden) return;
    final w = r * 1.1;
    final path = Path()..moveTo(c.dx - w / 2, c.dy + r * 0.15);
    for (var k = 1; k <= 20; k++) {
      final t = k / 20;
      path.lineTo(
        c.dx - w / 2 + w * t,
        c.dy - math.sin(t * 2 * math.pi) * r * 0.32,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CurveIconPainter old) =>
      old.color != color || old.hidden != hidden;
}

class _ExprRow extends StatelessWidget {
  const _ExprRow({
    super.key,
    required this.index,
    required this.expr,
    required this.color,
    required this.focused,
    required this.editMode,
    required this.blink,
    required this.free,
    required this.sliderText,
    required this.valueText,
    required this.onCaret,
    required this.onFocus,
    required this.onRemove,
    required this.onToggle,
    required this.onColor,
    required this.onSlide,
    required this.onPlay,
    required this.onLoop,
    required this.onRange,
    required this.onAddSliders,
    required this.onTable,
    required this.onDuplicate,
  });

  final int index;
  final _Expr expr;
  final Color color;
  final bool focused;
  final bool editMode;
  final ValueNotifier<bool> blink;
  final Set<String> free;
  final String? sliderText;
  final String? valueText;
  final ValueChanged<GxCursor> onCaret;
  final VoidCallback onFocus;
  final VoidCallback onRemove;
  final VoidCallback onToggle;
  final VoidCallback onColor;
  final void Function(double v, bool end) onSlide;
  final VoidCallback onPlay;
  final VoidCallback onLoop;
  final void Function(double lo, double hi, double step) onRange;
  final ValueChanged<Iterable<String>> onAddSliders;
  final VoidCallback onTable;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = expr.st;
    final shape = expr.external != null ? GxShape.function : st.shape;
    final slider = shape == GxShape.slider;
    final plotted =
        expr.external != null ||
        st.isPlot ||
        (shape == GxShape.userFunction && expr.fn != null);
    final error = shape == GxShape.error;

    final Widget icon;
    if (error) {
      icon = Tooltip(
        message: st.error ?? '',
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 28),
      );
    } else if (slider) {
      icon = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('graph-play-$index'),
            tooltip: expr.playing ? 'Pause' : 'Play',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              expr.playing
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 30,
            ),
            onPressed: onPlay,
          ),
          InkResponse(
            onTap: onLoop,
            child: Icon(
              expr.loop ? Icons.repeat : Icons.sync_alt,
              size: 16,
              semanticLabel: expr.loop ? 'Loop' : 'Back and forth',
            ),
          ),
        ],
      );
    } else if (plotted) {
      icon = GestureDetector(
        key: Key('graph-toggle-$index'),
        onTap: editMode ? onColor : onToggle,
        child: Semantics(
          button: true,
          label: expr.hidden ? 'Show' : 'Hide',
          child: _CurveIcon(color: color, hidden: expr.hidden),
        ),
      );
    } else {
      icon = const SizedBox.shrink();
    }

    final mathView = GxMathView(
      key: Key('graph-expr-$index'),
      row: expr.row,
      size: 21,
      color: scheme.onSurface,
      cursor: focused ? expr.editor.cursor : null,
      blink: focused ? blink : null,
      onCaret: onCaret,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFocus,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant),
            left: BorderSide(
              color: focused ? scheme.primary : Colors.transparent,
              width: 0,
            ),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 64),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Gutter(number: index + 1, focused: focused, child: icon),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: mathView,
                      ),
                      if (valueText != null && shape == GxShape.value && !error)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '= $valueText',
                              key: Key('graph-value-$index'),
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'serif',
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      if (slider && editMode)
                        _RangeFields(expr: expr, onRange: onRange)
                      else if (slider)
                        _SliderLine(index: index, expr: expr, onSlide: onSlide),
                      if (free.isNotEmpty && !slider)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'add slider:',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              for (final n in free)
                                ActionChip(
                                  key: Key('graph-slider-add-$n'),
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    n.replaceAll('_', ''),
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  onPressed: () => onAddSliders([n]),
                                ),
                              if (free.length > 1)
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text('all'),
                                  onPressed: () => onAddSliders(free),
                                ),
                            ],
                          ),
                        ),
                      if (error && focused)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            st.error ?? '',
                            key: Key('graph-error-$index'),
                            style: TextStyle(color: scheme.error, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (editMode) ...[
                if (expr.fn != null)
                  IconButton(
                    key: Key('graph-table-$index'),
                    tooltip: 'Table of values',
                    icon: const Icon(Icons.table_chart_outlined),
                    onPressed: onTable,
                  ),
                IconButton(
                  tooltip: 'Duplicate',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: onDuplicate,
                ),
              ],
              IconButton(
                key: Key('graph-remove-$index'),
                tooltip: 'Remove',
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderLine extends StatelessWidget {
  const _SliderLine({
    required this.index,
    required this.expr,
    required this.onSlide,
  });

  final int index;
  final _Expr expr;
  final void Function(double v, bool end) onSlide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lo = math.min(expr.min, expr.max), hi = math.max(expr.min, expr.max);
    final v = (expr.st.number ?? 0).clamp(lo, hi).toDouble();
    String f(double x) => _GraphPageState._fmt(x);
    final small = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Row(
      children: [
        Text(f(lo), style: small),
        Expanded(
          child: Slider(
            key: Key('graph-slider-$index'),
            value: v,
            min: lo,
            max: hi == lo ? lo + 1 : hi,
            divisions: expr.step > 0 && (hi - lo) / expr.step <= 1000
                ? math.max(1, ((hi - lo) / expr.step).round())
                : null,
            onChanged: (x) => onSlide(x, false),
            onChangeEnd: (x) => onSlide(x, true),
          ),
        ),
        Text(f(hi), style: small),
      ],
    );
  }
}

class _RangeFields extends StatelessWidget {
  const _RangeFields({required this.expr, required this.onRange});

  final _Expr expr;
  final void Function(double lo, double hi, double step) onRange;

  @override
  Widget build(BuildContext context) {
    final name = expr.st.name ?? '';
    Widget field(
      String label,
      double value,
      ValueChanged<double> set, {
      String? hint,
    }) {
      return SizedBox(
        width: 64,
        child: TextFormField(
          key: Key('graph-range-$label-${expr.id}'),
          initialValue: value == 0 && hint != null
              ? ''
              : _GraphPageState._fmt(value).replaceAll('−', '-'),
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: InputDecoration(isDense: true, hintText: hint),
          onFieldSubmitted: (t) {
            final v = double.tryParse(t.trim().replaceAll('−', '-'));
            if (v != null) set(v);
            if (t.trim().isEmpty && hint != null) set(0);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 6,
        children: [
          field('min', expr.min, (v) => onRange(v, expr.max, expr.step)),
          Text(
            '≤ ${name.replaceAll('_', '')} ≤',
            style: const TextStyle(fontFamily: 'serif', fontSize: 16),
          ),
          field('max', expr.max, (v) => onRange(expr.min, v, expr.step)),
          const SizedBox(width: 10),
          const Text('Step:'),
          field(
            'step',
            expr.step,
            (v) => onRange(expr.min, expr.max, v.abs()),
            hint: 'any',
          ),
        ],
      ),
    );
  }
}

class _NewRow extends StatelessWidget {
  const _NewRow({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const Key('graph-new-row'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Gutter(number: number, focused: false, child: const SizedBox()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap to add an expression',
                    style: TextStyle(color: scheme.outline),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.count,
    required this.color,
    required this.hidden,
    required this.onToggle,
  });

  final int count;
  final Color color;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Gutter(
            number: 0,
            focused: false,
            child: IconButton(
              key: const Key('graph-data-toggle'),
              tooltip: hidden ? 'Show data' : 'Hide data',
              icon: Icon(
                hidden ? Icons.circle_outlined : Icons.scatter_plot,
                color: color,
              ),
              onPressed: onToggle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Data: $count points'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wrench panel: grid, axis numbers, ranges, log axes, angle unit.
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    super.key,
    required this.grid,
    required this.view,
    required this.degrees,
    required this.onGrid,
    required this.onView,
    required this.onLog,
    required this.onDegrees,
  });

  final GridOptions grid;
  final GraphView view;
  final bool degrees;
  final ValueChanged<GridOptions> onGrid;
  final ValueChanged<GraphView> onView;
  final void Function(bool xLog, bool yLog) onLog;
  final ValueChanged<bool> onDegrees;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.6;
    Widget check(String label, bool v, ValueChanged<bool> set, String key) =>
        InkWell(
          key: Key('graph-opt-$key'),
          onTap: () => set(!v),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(value: v, onChanged: (x) => set(x ?? false)),
              Text(label),
              const SizedBox(width: 8),
            ],
          ),
        );

    Widget range(
      String axis,
      double lo,
      double hi,
      void Function(double, double) set,
    ) {
      Widget box(double v, ValueChanged<double> s, String k) => SizedBox(
        width: 84,
        child: TextFormField(
          key: Key('graph-$axis-$k'),
          initialValue: _GraphPageState._fmt(v).replaceAll('−', '-'),
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: const InputDecoration(isDense: true),
          onFieldSubmitted: (t) {
            final x = double.tryParse(t.trim().replaceAll('−', '-'));
            if (x != null) s(x);
          },
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          box(lo, (v) => set(v, hi), 'min'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '≤ $axis ≤',
              style: const TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ),
          box(hi, (v) => set(lo, v), 'max'),
        ],
      );
    }

    Widget seg<T>(
      T value,
      List<(T, String)> options,
      ValueChanged<T> set,
      String key,
    ) => SegmentedButton<T>(
      key: Key(key),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final (v, l) in options) ButtonSegment(value: v, label: Text(l)),
      ],
      selected: {value},
      onSelectionChanged: (s) => set(s.first),
    );

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 330, maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                children: [
                  check(
                    'Grid',
                    grid.grid,
                    (v) => onGrid(grid.copyWith(grid: v)),
                    'grid',
                  ),
                  check(
                    'Axis numbers',
                    grid.numbers,
                    (v) => onGrid(grid.copyWith(numbers: v)),
                    'numbers',
                  ),
                  check(
                    'Minor gridlines',
                    grid.minor,
                    (v) => onGrid(grid.copyWith(minor: v)),
                    'minor',
                  ),
                ],
              ),
              const Divider(),
              check(
                'x-axis',
                grid.xAxis,
                (v) => onGrid(grid.copyWith(xAxis: v)),
                'xaxis',
              ),
              range(
                'x',
                view.xMin,
                view.xMax,
                (lo, hi) => onView(view.framing(lo, hi, view.yMin, view.yMax)),
              ),
              const SizedBox(height: 8),
              check(
                'y-axis',
                grid.yAxis,
                (v) => onGrid(grid.copyWith(yAxis: v)),
                'yaxis',
              ),
              range(
                'y',
                view.yMin,
                view.yMax,
                (lo, hi) => onView(view.framing(view.xMin, view.xMax, lo, hi)),
              ),
              const Divider(height: 24),
              const Text('x-axis scale'),
              const SizedBox(height: 4),
              seg(
                view.xLog,
                const [(false, 'Linear'), (true, 'Logarithmic')],
                (v) => onLog(v, view.yLog),
                'graph-xlog',
              ),
              const SizedBox(height: 8),
              const Text('y-axis scale'),
              const SizedBox(height: 4),
              seg(
                view.yLog,
                const [(false, 'Linear'), (true, 'Logarithmic')],
                (v) => onLog(view.xLog, v),
                'graph-ylog',
              ),
              const Divider(height: 24),
              seg(
                degrees,
                const [(false, 'Radians'), (true, 'Degrees')],
                onDegrees,
                'graph-angle',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
