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
  const CalcError(this.kind);

  final CalcErrorKind kind;

  @override
  String toString() => 'CalcError(${kind.message})';
}
