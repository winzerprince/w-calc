import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Physical keyboard → calculator keys (web/desktop convenience).
///
/// Digits . + - * / ( ) ^ map directly; Enter/= is =, Backspace is DEL,
/// Escape/Delete is AC, arrows move the cursor, `s` SHIFT, `a` ALPHA,
/// `n` (−), `e` EXP.
List<CalcKey>? keysForKeyboard(KeyEvent event) {
  final logical = event.logicalKey;
  final special = <LogicalKeyboardKey, CalcKey>{
    LogicalKeyboardKey.enter: CalcKey.equals,
    LogicalKeyboardKey.numpadEnter: CalcKey.equals,
    LogicalKeyboardKey.backspace: CalcKey.del,
    LogicalKeyboardKey.escape: CalcKey.ac,
    LogicalKeyboardKey.delete: CalcKey.ac,
    LogicalKeyboardKey.arrowLeft: CalcKey.left,
    LogicalKeyboardKey.arrowRight: CalcKey.right,
    LogicalKeyboardKey.arrowUp: CalcKey.up,
    LogicalKeyboardKey.arrowDown: CalcKey.down,
  }[logical];
  if (special != null) return [special];

  final ch = event.character;
  if (ch == null || ch.isEmpty) return null;
  final digit = int.tryParse(ch);
  if (digit != null && ch.length == 1) {
    return [
      [
        CalcKey.d0,
        CalcKey.d1,
        CalcKey.d2,
        CalcKey.d3,
        CalcKey.d4,
        CalcKey.d5,
        CalcKey.d6,
        CalcKey.d7,
        CalcKey.d8,
        CalcKey.d9,
      ][digit],
    ];
  }
  final key = switch (ch) {
    '.' || ',' => CalcKey.dot,
    '+' => CalcKey.add,
    '-' => CalcKey.subtract,
    '*' || 'x' || '×' => CalcKey.multiply,
    '/' || '÷' => CalcKey.divide,
    '(' => CalcKey.openParen,
    ')' => CalcKey.closeParen,
    '^' => CalcKey.power,
    '=' => CalcKey.equals,
    's' => CalcKey.shift,
    'a' => CalcKey.alpha,
    'n' => CalcKey.negative,
    'e' => CalcKey.exp,
    'h' => CalcKey.hyp,
    'm' => CalcKey.mode,
    _ => null,
  };
  return key == null ? null : [key];
}
