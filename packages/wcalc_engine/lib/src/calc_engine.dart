import 'angle_unit.dart';
import 'calc_key.dart';
import 'graph/graph_math.dart';
import 'input/token.dart';

/// What the app needs from any calculator model's engine.
abstract interface class CalcEngine {
  void press(CalcKey key);

  /// Keys that may compute for a long time (the app shows a busy screen).
  bool isSlowKey(CalcKey key);

  /// CLR All: memories, data and setup back to defaults.
  void resetAll();

  Map<String, Object?> saveState();
  void restoreState(Map<String, Object?> state);

  /// The shown result as plain text for the clipboard, or null.
  String? get copyText;

  /// The current or last calculation when it can be drawn as y = f(X)
  /// (it uses X; a leading `Y =` is dropped), else null.
  List<Tok>? get graphTokens;

  /// Angle unit in use (graphs follow it).
  AngleUnit get angleUnit;

  /// Earlier calculations, oldest first: what was typed and its answer.
  List<({String input, String result})> get historyEntries;

  /// Something worth drawing right now (a function of X, an equation's
  /// polynomial, paired statistics data), or null.
  GraphSpec? get graphSpec;
}

/// Shared rule for [CalcEngine.graphTokens].
List<Tok>? graphableTokens(List<Tok> tokens) {
  var t = tokens;
  if (t.length > 2 && t[0] == Tok.varY && t[1] == Tok.eqSign) t = t.sublist(2);
  if (!t.contains(Tok.varX)) return null;
  if (t.any((k) => k == Tok.eqSign || k == Tok.colon)) return null;
  return List.unmodifiable(t);
}

/// Graph spec for a plain function of X.
GraphSpec? functionSpec(List<Tok>? tokens, AngleUnit angle) => tokens == null
    ? null
    : GraphSpec(
        curves: [(formulaText(tokens), GraphFunction(tokens, angle: angle))],
      );
