/// Structured input for the graph screen's expression list: rows of
/// symbols and boxes (fractions, powers, roots, …) edited with a cursor,
/// stored as a short LaTeX-like text.
library;

/// Two-dimensional structures. Slots are visited in this order.
enum GxKind {
  /// numerator, denominator
  frac(2),

  /// exponent of the item before it
  pow(1),

  /// subscript of the letter before it (a₁) or the base of log
  sub(1),

  /// radicand
  sqrt(1),

  /// index, radicand
  root(2),

  /// argument
  abs(1),

  /// `n=1`, upper limit, body
  sum(3),

  /// `n=1`, upper limit, body
  prod(3),

  /// lower, upper, body, variable
  integral(4),

  /// body (d/dx of it)
  deriv(1);

  const GxKind(this.slots);

  final int slots;
}

/// Function names typed as words (shown upright).
const gxWords = {
  'sin', 'cos', 'tan', 'csc', 'sec', 'cot', //
  'arcsin', 'arccos', 'arctan', 'arccsc', 'arcsec', 'arccot',
  'sinh', 'cosh', 'tanh', 'csch', 'sech', 'coth',
  'arcsinh', 'arccosh', 'arctanh',
  'ln', 'log', 'exp', 'floor', 'ceil', 'round', 'sign', 'mod', 'min', 'max',
};

/// Typed letter runs that become a symbol or a box.
const _specialWords = {'pi': 'π', 'theta': 'θ', 'sqrt': '√'};

/// One element of a [GxRow].
sealed class GxNode {
  const GxNode();

  GxNode copy();
}

/// A digit, letter, operator, bracket or function word.
final class GxSym extends GxNode {
  const GxSym(this.text);

  final String text;

  bool get isWord => text.length > 1;
  bool get isDigit => text.length == 1 && '0123456789'.contains(text);
  bool get isLetter =>
      text.length == 1 && RegExp(r'^[A-Za-zθ]$').hasMatch(text);

  @override
  GxSym copy() => this;

  @override
  bool operator ==(Object other) => other is GxSym && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}

/// A structure with [GxKind.slots] rows.
final class GxBox extends GxNode {
  GxBox(this.kind, [List<GxRow>? slots])
    : slots = slots ?? [for (var i = 0; i < kind.slots; i++) GxRow()];

  final GxKind kind;
  final List<GxRow> slots;

  @override
  GxBox copy() => GxBox(kind, [for (final s in slots) s.copy()]);

  @override
  String toString() => '${kind.name}{${slots.join('|')}}';
}

/// A horizontal run of items.
final class GxRow {
  GxRow([List<GxNode>? items]) : items = items ?? [];

  /// Reads [text] in the saved form ([toText]) or as plain formula text
  /// (`x^2-1`, `sqrt(x)/2`, `y = sin(x)`).
  factory GxRow.parse(String text) => _Reader(text).read();

  final List<GxNode> items;

  bool get isEmpty => items.isEmpty;

  GxRow copy() => GxRow([for (final i in items) i.copy()]);

  /// Lossless text form, read back by [GxRow.parse].
  String toText() {
    final b = StringBuffer();
    for (final i in items) {
      switch (i) {
        case GxSym(:final text):
          b.write(switch (text) {
            '×' => r'\cdot ',
            '÷' => r'\div ',
            '≤' => r'\le ',
            '≥' => r'\ge ',
            'π' => r'\pi ',
            'θ' => r'\theta ',
            _ when i.isWord => '\\$text ',
            _ => text,
          });
        case GxBox(:final kind, :final slots):
          final s = [for (final r in slots) '{${r.toText()}}'].join();
          b.write(switch (kind) {
            GxKind.pow => '^$s',
            GxKind.sub => '_$s',
            _ => '\\${kind.name}$s',
          });
      }
    }
    return b.toString();
  }

  /// Plain one-line text (`x^(2)+1`), for labels and screen readers.
  String plain() {
    final b = StringBuffer();
    for (final i in items) {
      switch (i) {
        case GxSym(:final text):
          b.write(text);
        case GxBox(:final kind, :final slots):
          final s = [for (final r in slots) r.plain()];
          b.write(switch (kind) {
            GxKind.frac => '(${s[0]})/(${s[1]})',
            GxKind.pow => '^(${s[0]})',
            GxKind.sub => '_${s[0]}',
            GxKind.sqrt => '√(${s[0]})',
            GxKind.root => 'root ${s[0]}(${s[1]})',
            GxKind.abs => '|${s[0]}|',
            GxKind.sum => 'Σ(${s[0]}..${s[1]}) ${s[2]}',
            GxKind.prod => 'Π(${s[0]}..${s[1]}) ${s[2]}',
            GxKind.integral => '∫(${s[0]}..${s[1]}) ${s[2]} d${s[3]}',
            GxKind.deriv => 'd/dx(${s[0]})',
          });
      }
    }
    return b.toString();
  }

  @override
  String toString() => items.join();
}

/// Where the cursor is: the boxes entered as (item index, slot) pairs from
/// the top row, and the position in the innermost row.
final class GxCursor {
  const GxCursor(this.path, this.pos);

  final List<(int, int)> path;
  final int pos;

  @override
  bool operator ==(Object other) =>
      other is GxCursor &&
      other.pos == pos &&
      other.path.length == path.length &&
      [for (var i = 0; i < path.length; i++) other.path[i] == path[i]]
          .every((b) => b);

  @override
  int get hashCode => Object.hash(pos, Object.hashAll(path));

  @override
  String toString() => 'GxCursor($path, $pos)';
}

const _operators = {'+', '-', '×', '÷', '=', '<', '>', '≤', '≥', ','};

/// Edits a [GxRow] like a textbook display: boxes are entered and left
/// with the arrows; `/` takes the term before it as the numerator.
final class GxEditor {
  GxEditor([GxRow? row]) : root = row ?? GxRow() {
    cursor = GxCursor(const [], root.items.length);
  }

  final GxRow root;
  late GxCursor cursor;

  bool get isEmpty => root.isEmpty;

  /// The row at [path].
  GxRow rowAt(List<(int, int)> path) {
    var r = root;
    for (final (i, s) in path) {
      r = (r.items[i] as GxBox).slots[s];
    }
    return r;
  }

  GxRow get _row => rowAt(cursor.path);

  void _go(List<(int, int)> path, int pos) =>
      cursor = GxCursor(List.unmodifiable(path), pos);

  /// Moves the cursor (taps on the expression).
  void moveTo(GxCursor c) => _go(c.path, c.pos);

  /// Cursor to the end of the top row.
  void end() => _go(const [], root.items.length);

  /// Types one key: a digit, letter, operator or bracket. `/`, `^` and `_`
  /// make a fraction, power or subscript.
  void type(String key) {
    final r = _row, p = cursor.pos;
    switch (key) {
      case '/':
        return box(GxKind.frac);
      case '^':
        return box(GxKind.pow);
      case '_':
        return box(GxKind.sub);
      case '*':
        key = '×';
      case '−':
        key = '-';
      case ')':
        if (p < r.items.length && r.items[p] == const GxSym(')')) {
          return _go(cursor.path, p + 1);
        }
      case '(':
        final next = p < r.items.length ? r.items[p] : null;
        final close =
            next == null ||
            next is GxSym &&
                (_operators.contains(next.text) || next.text == ')');
        r.items.insert(p, const GxSym('('));
        if (close) r.items.insert(p + 1, const GxSym(')'));
        return _go(cursor.path, p + 1);
    }
    r.items.insert(p, GxSym(key));
    _go(cursor.path, p + 1);
    if (GxSym(key).isLetter) _mergeWord();
  }

  /// Inserts a function word with brackets: `sin(|)`.
  void word(String w) {
    if (w == 'sqrt') return box(GxKind.sqrt);
    final r = _row, p = cursor.pos;
    r.items.insertAll(p, [GxSym(w), const GxSym('('), const GxSym(')')]);
    _go(cursor.path, p + 2);
  }

  /// Letters typed one by one become a function word when they spell one
  /// (`s`,`i`,`n` → sin; `sin`,`h` → sinh; `p`,`i` → π).
  void _mergeWord() {
    final r = _row, p = cursor.pos;
    var k = p;
    while (k > 0) {
      final it = r.items[k - 1];
      if (it is GxSym && (it.isLetter || it.isWord) && p - k < 7) {
        k--;
      } else {
        break;
      }
    }
    for (var from = k; from < p; from++) {
      final text = r.items.sublist(from, p).map((e) => '$e').join();
      final special = _specialWords[text];
      if (!gxWords.contains(text) && special == null) continue;
      r.items.removeRange(from, p);
      _go(cursor.path, from);
      if (special == '√') return box(GxKind.sqrt);
      r.items.insert(from, GxSym(special ?? text));
      return _go(cursor.path, from + 1);
    }
  }

  /// Inserts a structure. A fraction takes the term before the cursor as
  /// its numerator; Σ and Π start with `n=`.
  void box(GxKind kind) {
    final r = _row, p = cursor.pos;
    final b = GxBox(kind);
    if (kind == GxKind.frac) {
      var from = p, depth = 0;
      while (from > 0) {
        final it = r.items[from - 1];
        if (it is GxSym) {
          if (it.text == ')') depth++;
          if (it.text == '(') {
            if (depth == 0) break;
            depth--;
          }
          if (depth == 0 && _operators.contains(it.text)) break;
        }
        from--;
      }
      final num = r.items.sublist(from, p);
      r.items.removeRange(from, p);
      // (a+b)/ → a+b over the bar.
      if (num.length > 2 &&
          num.first == const GxSym('(') &&
          num.last == const GxSym(')') &&
          _matching(num, 0) == num.length - 1) {
        num
          ..removeLast()
          ..removeAt(0);
      }
      b.slots[0].items.addAll(num);
      r.items.insert(from, b);
      return _go([...cursor.path, (from, num.isEmpty ? 0 : 1)], 0);
    }
    r.items.insert(p, b);
    switch (kind) {
      case GxKind.sum || GxKind.prod:
        b.slots[0].items.addAll([const GxSym('n'), const GxSym('=')]);
        return _go([...cursor.path, (p, 0)], 2);
      case GxKind.integral:
        b.slots[3].items.add(const GxSym('x'));
      default:
    }
    _go([...cursor.path, (p, 0)], 0);
  }

  static int _matching(List<GxNode> items, int open) {
    var depth = 0;
    for (var i = open; i < items.length; i++) {
      if (items[i] == const GxSym('(')) depth++;
      if (items[i] == const GxSym(')') && --depth == 0) return i;
    }
    return -1;
  }

  /// The box holding the cursor and the path to its row.
  (GxBox, List<(int, int)>, int, int) _outer() {
    final path = cursor.path;
    final parent = path.sublist(0, path.length - 1);
    final (bi, s) = path.last;
    return (rowAt(parent).items[bi] as GxBox, parent, bi, s);
  }

  void right() {
    final r = _row, p = cursor.pos;
    if (p < r.items.length) {
      final it = r.items[p];
      if (it is GxBox) return _go([...cursor.path, (p, 0)], 0);
      return _go(cursor.path, p + 1);
    }
    if (cursor.path.isEmpty) return;
    final (b, parent, bi, s) = _outer();
    if (s + 1 < b.slots.length) return _go([...parent, (bi, s + 1)], 0);
    _go(parent, bi + 1);
  }

  void left() {
    final r = _row, p = cursor.pos;
    if (p > 0) {
      final it = r.items[p - 1];
      if (it is GxBox) {
        final last = it.slots.length - 1;
        return _go([
          ...cursor.path,
          (p - 1, last),
        ], it.slots[last].items.length);
      }
      return _go(cursor.path, p - 1);
    }
    if (cursor.path.isEmpty) return;
    final (b, parent, bi, s) = _outer();
    if (s > 0) {
      return _go([...parent, (bi, s - 1)], b.slots[s - 1].items.length);
    }
    _go(parent, bi);
  }

  /// Backspace: deletes the item before the cursor, steps into a box
  /// before it, or at the start of a box removes the box and keeps its
  /// contents.
  void backspace() {
    final r = _row, p = cursor.pos;
    if (p > 0) {
      final it = r.items[p - 1];
      if (it is GxBox) return left();
      final pair =
          it == const GxSym('(') &&
          p < r.items.length &&
          r.items[p] == const GxSym(')');
      r.items.removeRange(p - 1, pair ? p + 1 : p);
      return _go(cursor.path, p - 1);
    }
    if (cursor.path.isEmpty) return;
    final (b, parent, bi, s) = _outer();
    if (s > 0 && b.slots[s].items.isNotEmpty) {
      return _go([...parent, (bi, s - 1)], b.slots[s - 1].items.length);
    }
    final kept = switch (b.kind) {
      GxKind.frac => [
        ...b.slots[0].items,
        if (b.slots[0].items.isNotEmpty && b.slots[1].items.isNotEmpty)
          const GxSym('÷'),
        ...b.slots[1].items,
      ],
      GxKind.root => b.slots[1].items,
      GxKind.sum || GxKind.prod || GxKind.integral => b.slots[2].items,
      _ => b.slots[0].items,
    };
    final pr = rowAt(parent);
    pr.items
      ..removeAt(bi)
      ..insertAll(bi, kept);
    _go(parent, bi);
  }

  /// Every cursor position, in reading order (for tap hit-testing).
  List<GxCursor> allPositions() {
    final out = <GxCursor>[];
    void walk(GxRow r, List<(int, int)> path) {
      for (var i = 0; i <= r.items.length; i++) {
        out.add(GxCursor(path, i));
        if (r.items.elementAtOrNull(i) case final GxBox b) {
          for (var s = 0; s < b.slots.length; s++) {
            walk(b.slots[s], [...path, (i, s)]);
          }
        }
      }
    }

    walk(root, const []);
    return out;
  }
}

/// Reads saved text and plain formulas.
class _Reader {
  _Reader(this.s);

  final String s;
  int i = 0;

  static const _aliases = {
    'asin': 'arcsin',
    'acos': 'arccos',
    'atan': 'arctan',
    'asinh': 'arcsinh',
    'acosh': 'arccosh',
    'atanh': 'arctanh',
  };

  static final _words = (<String>{
    ...gxWords,
    ..._aliases.keys,
    'pi',
    'theta',
    'sqrt',
    'cbrt',
    'abs',
  }.toList()..sort((a, b) => b.length - a.length));

  GxRow read({bool group = false}) {
    final out = <GxNode>[];
    while (i < s.length) {
      final c = s[i];
      if (group && c == '}') {
        i++;
        break;
      }
      if (c.trim().isEmpty) {
        i++;
        continue;
      }
      switch (c) {
        case '\\':
          _command(out);
          continue;
        case '^' || '_':
          i++;
          out.add(GxBox(c == '^' ? GxKind.pow : GxKind.sub, [_operand()]));
          continue;
        case '²' || '³':
          i++;
          out.add(GxBox(GxKind.pow, [GxRow.parse(c == '²' ? '2' : '3')]));
          continue;
        case '/':
          i++;
          out.add(GxBox(GxKind.frac, [GxRow(_takeOperand(out)), _operand()]));
          continue;
        case '√':
          i++;
          out.add(GxBox(GxKind.sqrt, [_operand()]));
          continue;
        case '|':
          final close = s.indexOf('|', i + 1);
          if (close > i) {
            out.add(
              GxBox(GxKind.abs, [GxRow.parse(s.substring(i + 1, close))]),
            );
            i = close + 1;
            continue;
          }
      }
      if (s.startsWith('<=', i) || s.startsWith('>=', i)) {
        out.add(GxSym(c == '<' ? '≤' : '≥'));
        i += 2;
        continue;
      }
      final lower = s.substring(i).toLowerCase();
      final w = _words.where(lower.startsWith).firstOrNull;
      if (w != null) {
        i += w.length;
        _word(_aliases[w] ?? w, out);
        continue;
      }
      out.add(
        GxSym(switch (c) {
          '*' || '·' => '×',
          '−' => '-',
          _ => c,
        }),
      );
      i++;
    }
    return GxRow(out);
  }

  void _word(String w, List<GxNode> out) {
    switch (w) {
      case 'pi':
        out.add(const GxSym('π'));
      case 'theta':
        out.add(const GxSym('θ'));
      case 'sqrt' || 'cbrt' || 'abs':
        final arg = _operand();
        out.add(switch (w) {
          'sqrt' => GxBox(GxKind.sqrt, [arg]),
          'abs' => GxBox(GxKind.abs, [arg]),
          _ => GxBox(GxKind.root, [GxRow.parse('3'), arg]),
        });
      default:
        out.add(GxSym(w));
    }
  }

  void _command(List<GxNode> out) {
    i++;
    final start = i;
    while (i < s.length && RegExp('[A-Za-z]').hasMatch(s[i])) {
      i++;
    }
    final name = s.substring(start, i);
    if (i < s.length && s[i] == ' ') i++;
    final kind = GxKind.values.where((k) => k.name == name).firstOrNull;
    if (kind != null) {
      out.add(GxBox(kind, [for (var k = 0; k < kind.slots; k++) _operand()]));
      return;
    }
    out.add(
      GxSym(switch (name) {
        'cdot' || 'times' => '×',
        'div' => '÷',
        'le' => '≤',
        'ge' => '≥',
        'pi' => 'π',
        'theta' => 'θ',
        _ => name,
      }),
    );
  }

  /// `{…}`, a bracketed group (brackets dropped), a number, a word with
  /// its argument, or one character.
  GxRow _operand() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i >= s.length) return GxRow();
    final c = s[i];
    if (c == '{') {
      i++;
      return read(group: true);
    }
    if (c == '(') {
      final close = _close(i);
      final inner = s.substring(i + 1, close < 0 ? s.length : close);
      i = close < 0 ? s.length : close + 1;
      return GxRow.parse(inner);
    }
    final start = i;
    if (c == '-' || c == '−') i++;
    if (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
      while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
        i++;
      }
    } else {
      final lower = s.substring(i).toLowerCase();
      final w = _words.where(lower.startsWith).firstOrNull;
      if (w != null && w != 'pi' && w != 'theta') {
        i += w.length;
        if (i < s.length && s[i] == '(') {
          final close = _close(i);
          i = close < 0 ? s.length : close + 1;
        }
      } else {
        i += w?.length ?? 1;
      }
    }
    return GxRow.parse(s.substring(start, i));
  }

  int _close(int open) {
    var depth = 0;
    for (var k = open; k < s.length; k++) {
      if (s[k] == '(') depth++;
      if (s[k] == ')' && --depth == 0) return k;
    }
    return -1;
  }

  /// The term just read (for `a/b`): a bracketed group or a run of
  /// letters, digits and boxes.
  static List<GxNode> _takeOperand(List<GxNode> out) {
    if (out.isEmpty) return [];
    if (out.last == const GxSym(')')) {
      var depth = 0;
      for (var k = out.length - 1; k >= 0; k--) {
        if (out[k] == const GxSym(')')) depth++;
        if (out[k] == const GxSym('(') && --depth == 0) {
          // A function's brackets stay with the function.
          final from =
              k > 0 && out[k - 1] is GxSym && (out[k - 1] as GxSym).isWord
              ? k - 1
              : k;
          final taken = out.sublist(from);
          out.removeRange(from, out.length);
          if (from == k) {
            return taken.sublist(1, taken.length - 1);
          }
          return taken;
        }
      }
    }
    var k = out.length;
    while (k > 0) {
      final it = out[k - 1];
      if (it is GxSym && (_operators.contains(it.text) || it.text == '(')) {
        break;
      }
      k--;
    }
    final taken = out.sublist(k);
    out.removeRange(k, out.length);
    return taken;
  }
}
