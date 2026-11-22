/// Error kinds shown by the calculator ("Math ERROR", "Syntax ERROR", ...).
enum CalcErrorKind {
  math('Math ERROR'),
  stack('Stack ERROR'),
  syntax('Syntax ERROR'),
  arg('Arg ERROR'),
  dim('Dim ERROR'),
  cantSolve("Can't Solve");

  const CalcErrorKind(this.message);

  /// Text shown on the upper display line.
  final String message;
}

/// Thrown by the engine; the calculator turns it into an error screen.
class CalcError implements Exception {
  const CalcError(this.kind, [this.position]);

  final CalcErrorKind kind;

  /// Token index where the error was detected (cursor goes there on ◀/▶).
  final int? position;

  CalcError at(int pos) => CalcError(kind, position ?? pos);

  @override
  String toString() => 'CalcError(${kind.message})';
}
