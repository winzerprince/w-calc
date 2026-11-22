import '../input/token.dart';
import '../number/dec.dart';

/// Priority levels from the device's "calculation priority sequence".
/// Lower number = binds tighter. Equal levels evaluate left to right.
abstract final class Priority {
  /// Implied multiplication before π, e, memory or variable names (2π, 3A, 2Ans).
  static const impliedOperand = 5;

  /// Type B functions: (−), √, sin, log, ...
  static const prefix = 6;

  /// Implied multiplication before Type B functions and parentheses (2√3, 2(3)).
  /// TODO(device): parentheses assumed here (6÷2(1+2) = 1); see behaviour-notes #5.
  static const impliedFunction = 7;

  static const multiplyDivide = 10;
  static const addSubtract = 11;
}

/// Numeric stack depth.
const int numericStackSize = 10;

/// Command (operator) stack depth.
const int commandStackSize = 24;

/// Evaluates one expression. Throws [CalcError] (with token position).
Dec evaluate(List<Tok> tokens, {required Dec ans}) =>
    _Evaluator(tokens, ans).run();

enum _OpType { paren, binary, prefix }

class _Op {
  const _Op(this.type, this.priority, this.pos, [this.apply2, this.apply1]);

  final _OpType type;
  final int priority;
  final int pos;
  final Dec Function(Dec, Dec)? apply2;
  final Dec Function(Dec)? apply1;
}

Dec _mul(Dec a, Dec b) => a * b;

class _Evaluator {
  _Evaluator(this.tokens, this.ans);

  final List<Tok> tokens;
  final Dec ans;
  final List<Dec> values = [];
  final List<_Op> ops = [];

  Never _syntax(int pos) => throw CalcError(CalcErrorKind.syntax, pos);

  Dec run() {
    var expectOperand = true;
    var i = 0;
    while (i < tokens.length) {
      final tok = tokens[i];
      switch (tok.kind) {
        case TokKind.digit || TokKind.point || TokKind.exp:
          if (!expectOperand) _syntax(i);
          i = _literal(i);
          expectOperand = false;
          continue;
        case TokKind.operand:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedOperand, i, _mul));
          }
          _pushValue(ans, i);
          expectOperand = false;
        case TokKind.openParen:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          _pushOp(_Op(_OpType.paren, 0, i));
          expectOperand = true;
        case TokKind.prefix:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          _pushOp(
            _Op(_OpType.prefix, Priority.prefix, i, null, _prefixFn(tok)),
          );
          expectOperand = true;
        case TokKind.binary:
          if (expectOperand) _syntax(i);
          _pushBinary(_binaryOp(tok, i));
          expectOperand = true;
        case TokKind.closeParen:
          if (expectOperand) _syntax(i);
          while (ops.isNotEmpty && ops.last.type != _OpType.paren) {
            _apply(ops.removeLast());
          }
          if (ops.isEmpty) _syntax(i);
          ops.removeLast();
          expectOperand = false;
        case TokKind.postfix:
          _syntax(i); // No postfix tokens yet (M3).
      }
      i++;
    }
    if (expectOperand) _syntax(tokens.length);
    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op.type != _OpType.paren) {
        _apply(op); // Missing ")" at the end is allowed.
      }
    }
    return values.single;
  }

  /// Parses a number literal starting at [start]; returns index after it.
  int _literal(int start) {
    final mantissa = StringBuffer();
    var i = start;
    var sawPoint = false;
    while (i < tokens.length &&
        (tokens[i].kind == TokKind.digit || tokens[i] == Tok.point)) {
      if (tokens[i] == Tok.point) {
        if (sawPoint) _syntax(i);
        sawPoint = true;
      }
      mantissa.write(tokens[i].text);
      i++;
    }
    var exponent = '';
    if (i < tokens.length && tokens[i] == Tok.exp) {
      i++;
      if (i < tokens.length && tokens[i] == Tok.negative) {
        exponent = '-';
        i++;
      }
      var count = 0;
      while (i < tokens.length && tokens[i].kind == TokKind.digit) {
        if (++count > 2) _syntax(i);
        exponent += tokens[i].text;
        i++;
      }
      if (count == 0) _syntax(i);
      if (i < tokens.length && tokens[i] == Tok.point) _syntax(i);
    }
    var m = mantissa.toString();
    if (m.isEmpty) m = '1'; // EXP pressed first: 1E…
    if (m == '.') _syntax(start);
    try {
      _pushValue(Dec.parse(exponent.isEmpty ? m : '${m}e$exponent'), start);
    } on CalcError catch (e) {
      throw e.at(start);
    }
    return i;
  }

  void _pushValue(Dec v, int pos) {
    if (values.length >= numericStackSize) {
      throw CalcError(CalcErrorKind.stack, pos);
    }
    values.add(v);
  }

  void _pushOp(_Op op) {
    if (ops.length >= commandStackSize) {
      throw CalcError(CalcErrorKind.stack, op.pos);
    }
    ops.add(op);
  }

  void _pushBinary(_Op op) {
    while (ops.isNotEmpty &&
        ops.last.type != _OpType.paren &&
        ops.last.priority <= op.priority) {
      _apply(ops.removeLast());
    }
    _pushOp(op);
  }

  void _apply(_Op op) {
    try {
      if (op.type == _OpType.prefix) {
        values.add(op.apply1!(values.removeLast()));
      } else {
        final b = values.removeLast();
        final a = values.removeLast();
        values.add(op.apply2!(a, b));
      }
    } on CalcError catch (e) {
      throw e.at(op.pos);
    }
  }

  static Dec Function(Dec) _prefixFn(Tok tok) => switch (tok) {
    Tok.negative => (a) => -a,
    _ => throw ArgumentError('not a prefix token: $tok'),
  };

  static _Op _binaryOp(Tok tok, int pos) => switch (tok) {
    Tok.add => _Op(_OpType.binary, Priority.addSubtract, pos, (a, b) => a + b),
    Tok.subtract => _Op(
      _OpType.binary,
      Priority.addSubtract,
      pos,
      (a, b) => a - b,
    ),
    Tok.multiply => _Op(_OpType.binary, Priority.multiplyDivide, pos, _mul),
    Tok.divide => _Op(
      _OpType.binary,
      Priority.multiplyDivide,
      pos,
      (a, b) => a / b,
    ),
    _ => throw ArgumentError('not a binary token: $tok'),
  };
}
