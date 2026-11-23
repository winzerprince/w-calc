import '../input/token.dart';

/// Two-dimensional input structures of the textbook display. Each has a
/// fixed number of slots; the cursor visits them in [slots] order.
enum MathTemplate {
  /// numerator, denominator
  fraction(2),

  /// whole, numerator, denominator
  mixed(3),

  /// radicand
  sqrt(1),

  /// radicand
  cbrt(1),

  /// index, radicand
  root(2),

  /// exponent (attached to the item before it)
  power(1),

  /// exponent
  tenPow(1),

  /// exponent
  ePow(1),

  /// base, argument
  logBase(2),

  /// argument
  abs(1),

  /// f(X), lower limit, upper limit
  integral(3),

  /// f(X), x = a
  derivative(2),

  /// f(X), first x, last x
  sum(3);

  const MathTemplate(this.slots);

  final int slots;

  /// Input memory used by the template itself (the device counts several
  /// bytes for structured functions).
  int get bytes => switch (this) {
    fraction || power || sqrt || cbrt || abs || tenPow || ePow => 2,
    mixed || root || logBase => 3,
    integral || sum => 4,
    derivative => 3,
  };
}

/// One element of a [MathRow].
sealed class MathItem {
  MathItem copy();
}

/// A single key's input: a digit, operator, variable or a function name.
/// [paren] functions (sin(, log(, Pol( …) show and evaluate with an
/// opening parenthesis that the user closes with `)`.
final class TokItem extends MathItem {
  TokItem(this.tok, {this.paren = false});

  final Tok tok;
  final bool paren;

  @override
  TokItem copy() => TokItem(tok, paren: paren);

  @override
  String toString() {
    final t = tok == Tok.fracSep ? '⌟' : tok.text;
    return paren ? '${t.trimRight()}(' : t;
  }
}

/// A template with its slots.
final class TemplateItem extends MathItem {
  TemplateItem(this.kind, [List<MathRow>? slots])
    : slots = slots ?? [for (var i = 0; i < kind.slots; i++) MathRow()];

  final MathTemplate kind;
  final List<MathRow> slots;

  @override
  TemplateItem copy() => TemplateItem(kind, [for (final s in slots) s.copy()]);

  @override
  String toString() => '${kind.name}{${slots.join('|')}}';
}

/// A horizontal run of items: the whole input, or one slot of a template.
final class MathRow {
  MathRow([List<MathItem>? items]) : items = items ?? [];

  final List<MathItem> items;

  bool get isEmpty => items.isEmpty;

  MathRow copy() => MathRow([for (final i in items) i.copy()]);

  /// One-line text (`(1+√(5))/2`, `x^(2)`), for history lists.
  String plainText() {
    String slot(MathRow r) =>
        r.items.length == 1 ? r.plainText() : '(${r.plainText()})';
    final b = StringBuffer();
    for (final i in items) {
      switch (i) {
        case TokItem(:final tok, :final paren):
          final t = switch (tok) {
            Tok.fracSep => '/',
            Tok.negative => '−',
            Tok.subtract => '−',
            _ => tok.text.trim(),
          };
          b.write(paren && tok.kind != TokKind.function ? '$t(' : t);
        case TemplateItem(:final kind, :final slots):
          b.write(switch (kind) {
            MathTemplate.fraction => '${slot(slots[0])}/${slot(slots[1])}',
            MathTemplate.mixed =>
              '${slots[0].plainText()} ${slot(slots[1])}/${slot(slots[2])}',
            MathTemplate.sqrt => '√${slot(slots[0])}',
            MathTemplate.cbrt => '∛${slot(slots[0])}',
            MathTemplate.root => '${slot(slots[0])}√${slot(slots[1])}',
            MathTemplate.power => '^${slot(slots[0])}',
            MathTemplate.tenPow => '10^${slot(slots[0])}',
            MathTemplate.ePow => 'e^${slot(slots[0])}',
            MathTemplate.abs => '|${slots[0].plainText()}|',
            MathTemplate.logBase =>
              'log_${slot(slots[0])}(${slots[1].plainText()})',
            MathTemplate.integral =>
              '∫(${slots[0].plainText()}, ${slots[1].plainText()}, ${slots[2].plainText()})',
            MathTemplate.derivative =>
              'd/dx(${slots[0].plainText()}, ${slots[1].plainText()})',
            MathTemplate.sum =>
              'Σ(${slots[0].plainText()}, ${slots[1].plainText()}, ${slots[2].plainText()})',
          });
      }
    }
    return b.toString();
  }

  int get bytes => items.fold(
    0,
    (sum, i) =>
        sum +
        switch (i) {
          TokItem() => 1,
          TemplateItem(:final kind, :final slots) =>
            kind.bytes + slots.fold(0, (s, r) => s + r.bytes),
        },
  );

  @override
  String toString() => items.join();
}

/// Cursor location: the chain of (item index, slot index) from the root
/// row to the current row, and the insertion point within that row.
final class MathCursor {
  const MathCursor(this.path, this.pos);

  static const MathCursor start = MathCursor([], 0);

  final List<(int, int)> path;
  final int pos;

  @override
  bool operator ==(Object other) =>
      other is MathCursor &&
      other.pos == pos &&
      other.path.length == path.length &&
      [for (var i = 0; i < path.length; i++) other.path[i] == path[i]]
          .every((b) => b);

  @override
  int get hashCode => Object.hash(Object.hashAll(path), pos);

  @override
  String toString() => 'MathCursor($path, $pos)';
}

/// Token stream for the evaluator plus, for every token, where it came from
/// (so an error can put the cursor back at the problem).
final class LinearForm {
  LinearForm(this.tokens, this.origins);

  final List<Tok> tokens;
  final List<MathCursor> origins;

  /// Cursor for an error at token [index] (end of input when past the end).
  MathCursor cursorFor(int index, MathCursor end) =>
      index < origins.length ? origins[index] : end;
}

/// Editable textbook-style expression: insert, delete and cursor movement
/// following the device's rules (always insert mode).
final class MathEditor {
  MathEditor([MathRow? root]) : root = root ?? MathRow();

  final MathRow root;
  MathCursor cursor = MathCursor.start;

  /// Maximum input size, like the device's 99 bytes.
  static const maxBytes = 99;

  int get bytes => root.bytes;

  bool get isEmpty => root.isEmpty;

  /// The row the cursor is in.
  MathRow get row => _rowAt(cursor.path);

  MathRow _rowAt(List<(int, int)> path) {
    var r = root;
    for (final (item, slot) in path) {
      r = (r.items[item] as TemplateItem).slots[slot];
    }
    return r;
  }

  void clear() {
    root.items.clear();
    cursor = MathCursor.start;
  }

  /// Replaces the content (e.g. recalling history) with the cursor at the end.
  void load(MathRow content) {
    root.items
      ..clear()
      ..addAll(content.copy().items);
    cursor = MathCursor(const [], root.items.length);
  }

  bool _fits(int extra) => bytes + extra <= maxBytes;

  /// Inserts one key's token. Returns false when memory is full.
  bool insertTok(Tok tok, {bool paren = false}) {
    if (!_fits(1)) return false;
    row.items.insert(cursor.pos, TokItem(tok, paren: paren));
    cursor = MathCursor(cursor.path, cursor.pos + 1);
    return true;
  }

  /// Inserts a template and moves into its first empty slot. A fraction
  /// typed right after a number takes that number as its numerator.
  bool insertTemplate(MathTemplate kind, {bool wrap = false}) {
    if (!_fits(kind.bytes)) return false;
    final r = row;
    final t = TemplateItem(kind);
    var at = cursor.pos;
    var slot = 0;
    if (wrap) {
      // INS: what follows the cursor, up to the next function or bracket,
      // becomes the argument.
      var end = at;
      while (end < r.items.length) {
        final i = r.items[end];
        if (i is TokItem &&
            (i.paren ||
                i.tok.kind == TokKind.function ||
                i.tok == Tok.openParen ||
                i.tok == Tok.closeParen)) {
          break;
        }
        end++;
      }
      final taken = r.items.sublist(at, end);
      r.items.removeRange(at, end);
      final target = switch (kind) {
        MathTemplate.root || MathTemplate.logBase => 1,
        _ => 0,
      };
      t.slots[target].items.addAll(taken);
      r.items.insert(at, t);
      // Cursor goes to the next empty slot, else after the argument.
      final next = target + 1 < t.slots.length ? target + 1 : target;
      final into = next != target && t.slots[next].isEmpty ? next : target;
      cursor = MathCursor([
        ...cursor.path,
        (at, into),
      ], t.slots[into].items.length);
      return true;
    }
    if (kind == MathTemplate.fraction) {
      var from = at;
      while (from > 0 && _isNumberPart(r.items[from - 1])) {
        from--;
      }
      if (from < at) {
        t.slots[0].items.addAll(r.items.sublist(from, at));
        r.items.removeRange(from, at);
        at = from;
        slot = 1;
      }
    }
    r.items.insert(at, t);
    cursor = MathCursor([...cursor.path, (at, slot)], 0);
    return true;
  }

  static bool _isNumberPart(MathItem i) =>
      i is TokItem &&
      (i.tok.kind == TokKind.digit ||
          i.tok.kind == TokKind.point ||
          i.tok == Tok.ans);

  /// DEL: removes the item left of the cursor. At the start of a template's
  /// first slot it removes the template and keeps the slot contents.
  void delete() {
    final r = row;
    if (cursor.pos > 0) {
      final prev = r.items[cursor.pos - 1];
      if (prev is TemplateItem) {
        _unwrap(cursor.path, cursor.pos - 1);
        return;
      }
      r.items.removeAt(cursor.pos - 1);
      cursor = MathCursor(cursor.path, cursor.pos - 1);
      return;
    }
    if (cursor.path.isEmpty) return;
    final (item, slot) = cursor.path.last;
    final parentPath = cursor.path.sublist(0, cursor.path.length - 1);
    if (slot == 0) {
      _unwrap(parentPath, item);
    } else {
      // Start of a later slot: step back into the previous slot's end.
      final t = _rowAt(parentPath).items[item] as TemplateItem;
      cursor = MathCursor([
        ...parentPath,
        (item, slot - 1),
      ], t.slots[slot - 1].items.length);
    }
  }

  /// Replaces the template at [index] of the row at [path] by its slot
  /// contents (in slot order); the cursor lands where the template began.
  void _unwrap(List<(int, int)> path, int index) {
    final r = _rowAt(path);
    final t = r.items[index] as TemplateItem;
    final contents = [for (final s in t.slots) ...s.items];
    r.items
      ..removeAt(index)
      ..insertAll(index, contents);
    cursor = MathCursor(path, index);
  }

  /// ▶: into the next template, to the next slot, out of a template, or
  /// from the very end round to the start.
  void right() {
    final r = row;
    if (cursor.pos < r.items.length) {
      final next = r.items[cursor.pos];
      if (next is TemplateItem) {
        cursor = MathCursor([...cursor.path, (cursor.pos, 0)], 0);
      } else {
        cursor = MathCursor(cursor.path, cursor.pos + 1);
      }
      return;
    }
    if (cursor.path.isEmpty) {
      cursor = MathCursor.start;
      return;
    }
    final (item, slot) = cursor.path.last;
    final parentPath = cursor.path.sublist(0, cursor.path.length - 1);
    final t = _rowAt(parentPath).items[item] as TemplateItem;
    cursor = slot + 1 < t.slots.length
        ? MathCursor([...parentPath, (item, slot + 1)], 0)
        : MathCursor(parentPath, item + 1);
  }

  /// ◀: mirror of [right].
  void left() {
    final r = row;
    if (cursor.pos > 0) {
      final prev = r.items[cursor.pos - 1];
      if (prev is TemplateItem) {
        final last = prev.slots.length - 1;
        cursor = MathCursor([
          ...cursor.path,
          (cursor.pos - 1, last),
        ], prev.slots[last].items.length);
      } else {
        cursor = MathCursor(cursor.path, cursor.pos - 1);
      }
      return;
    }
    if (cursor.path.isEmpty) {
      cursor = MathCursor(const [], root.items.length);
      return;
    }
    final (item, slot) = cursor.path.last;
    final parentPath = cursor.path.sublist(0, cursor.path.length - 1);
    final t = _rowAt(parentPath).items[item] as TemplateItem;
    cursor = slot > 0
        ? MathCursor([
            ...parentPath,
            (item, slot - 1),
          ], t.slots[slot - 1].items.length)
        : MathCursor(parentPath, item);
  }

  /// ▲ / ▼ inside a fraction: numerator ↔ denominator. Returns false when
  /// the cursor is not in a fraction (the calculator then scrolls history).
  bool vertical({required bool up}) {
    for (var depth = cursor.path.length - 1; depth >= 0; depth--) {
      final (item, slot) = cursor.path[depth];
      final parentPath = cursor.path.sublist(0, depth);
      final t = _rowAt(parentPath).items[item] as TemplateItem;
      final (from, to) = switch (t.kind) {
        MathTemplate.fraction => up ? (1, 0) : (0, 1),
        MathTemplate.mixed => up ? (2, 1) : (1, 2),
        _ => (-1, -1),
      };
      if (slot == from) {
        final target = [...parentPath, (item, to)];
        cursor = MathCursor(target, _rowAt(target).items.length);
        return true;
      }
    }
    return false;
  }

  /// Token stream for the evaluator.
  LinearForm linearize() {
    final tokens = <Tok>[];
    final origins = <MathCursor>[];
    void emit(Tok t, MathCursor at) {
      tokens.add(t);
      origins.add(at);
    }

    void rowTokens(MathRow r, List<(int, int)> path) {
      for (var i = 0; i < r.items.length; i++) {
        final at = MathCursor(path, i + 1);
        switch (r.items[i]) {
          case TokItem(:final tok, :final paren):
            emit(tok, at);
            if (paren && tok.kind != TokKind.function) {
              emit(Tok.openParen, at);
            }
          case TemplateItem(:final kind, :final slots):
            void slotTokens(int s) => rowTokens(slots[s], [...path, (i, s)]);
            MathCursor slotStart(int s) => MathCursor([...path, (i, s)], 0);
            MathCursor slotEnd(int s) =>
                MathCursor([...path, (i, s)], slots[s].items.length);
            // Brackets and commas belong to their slot, so an error in an
            // empty slot puts the cursor inside it.
            void group(int s) {
              emit(Tok.openParen, slotStart(s));
              slotTokens(s);
              emit(Tok.closeParen, slotEnd(s));
            }

            void call(Tok f, List<int> order) {
              emit(f, slotStart(order.first));
              for (var k = 0; k < order.length; k++) {
                if (k > 0) emit(Tok.comma, slotEnd(order[k - 1]));
                slotTokens(order[k]);
              }
              emit(Tok.closeParen, slotEnd(order.last));
            }

            switch (kind) {
              case MathTemplate.fraction:
                group(0);
                emit(Tok.fracDiv, at);
                group(1);
              case MathTemplate.mixed:
                emit(Tok.openParen, at);
                group(0);
                emit(Tok.add, at);
                group(1);
                emit(Tok.fracDiv, at);
                group(2);
                emit(Tok.closeParen, at);
              case MathTemplate.sqrt:
                emit(Tok.sqrt, at);
                group(0);
              case MathTemplate.cbrt:
                emit(Tok.cbrt, at);
                group(0);
              case MathTemplate.root:
                group(0);
                emit(Tok.xRoot, at);
                group(1);
              case MathTemplate.power:
                emit(Tok.power, at);
                group(0);
              case MathTemplate.tenPow:
                emit(Tok.tenPow, at);
                group(0);
              case MathTemplate.ePow:
                emit(Tok.ePow, at);
                group(0);
              case MathTemplate.abs:
                emit(Tok.cAbs, at);
                group(0);
              case MathTemplate.logBase:
                call(Tok.logBase, const [0, 1]);
              case MathTemplate.integral:
                call(Tok.integral, const [0, 1, 2]);
              case MathTemplate.derivative:
                call(Tok.derivative, const [0, 1]);
              case MathTemplate.sum:
                call(Tok.sigma, const [0, 1, 2]);
            }
        }
      }
    }

    rowTokens(root, const []);
    return LinearForm(tokens, origins);
  }

  /// Puts the cursor at [c] if it addresses a valid position.
  void moveTo(MathCursor c) {
    try {
      final r = _rowAt(c.path);
      if (c.pos >= 0 && c.pos <= r.items.length) cursor = c;
    } on Object {
      // Invalid path: keep the cursor.
    }
  }
}
