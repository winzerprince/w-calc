import 'calc_key.dart';

/// Parses a test-vector key sequence (e.g. `56 × ( (-) 12 ) =`) into keys.
///
/// Words are separated by spaces. A word of only digits/points expands to one
/// key per character (`56` → 5, 6; `2.5` → 2, ., 5). Other words are key names
/// as written in the manual/test vectors, e.g. `(-)`, `EXP`, `SHIFT`, `<`.
List<CalcKey> parseKeySequence(String sequence) {
  final out = <CalcKey>[];
  for (final word in sequence.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (RegExp(r'^[0-9.]+$').hasMatch(word)) {
      for (final c in word.split('')) {
        out.add(c == '.' ? CalcKey.dot : _digits[int.parse(c)]);
      }
      continue;
    }
    final mapped = _names[word];
    if (mapped == null) throw FormatException('Unknown key name', word);
    out.addAll(mapped);
  }
  return out;
}

const _digits = [
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
];

const _names = <String, List<CalcKey>>{
  '+': [CalcKey.add],
  'plus': [CalcKey.add],
  'minus': [CalcKey.subtract],
  'times': [CalcKey.multiply],
  'div': [CalcKey.divide],
  'neg': [CalcKey.negative],
  '-': [CalcKey.subtract],
  '×': [CalcKey.multiply],
  '*': [CalcKey.multiply],
  '÷': [CalcKey.divide],
  '/': [CalcKey.divide],
  '(': [CalcKey.openParen],
  ')': [CalcKey.closeParen],
  '(-)': [CalcKey.negative],
  'EXP': [CalcKey.exp],
  'Ans': [CalcKey.ans],
  '=': [CalcKey.equals],
  'AC': [CalcKey.ac],
  'DEL': [CalcKey.del],
  'INS': [CalcKey.shift, CalcKey.del],
  'SHIFT': [CalcKey.shift],
  'ALPHA': [CalcKey.alpha],
  '<': [CalcKey.left],
  '>': [CalcKey.right],
  'up': [CalcKey.up],
  'down': [CalcKey.down],
  '▲': [CalcKey.up],
  '▼': [CalcKey.down],
  '◀': [CalcKey.left],
  '▶': [CalcKey.right],
  'MODE': [CalcKey.mode],
  'hyp': [CalcKey.hyp],
  'tan': [CalcKey.tan],
  'log': [CalcKey.log],
  'ln': [CalcKey.ln],
  '√': [CalcKey.sqrt],
  'sqrt': [CalcKey.sqrt],
  'x²': [CalcKey.square],
  'x2': [CalcKey.square],
  '^': [CalcKey.power],
  'pow': [CalcKey.power],
  'x⁻¹': [CalcKey.reciprocal],
  'x-1': [CalcKey.reciprocal],
  '°′″': [CalcKey.degMinSec],
  'dms': [CalcKey.degMinSec],
  'ENG': [CalcKey.eng],
  'RCL': [CalcKey.rcl],
  'M+': [CalcKey.mPlus],
  'CALC': [CalcKey.calc],
  '∫dx': [CalcKey.integrate],
  'CONST': [CalcKey.constant],
  'ab/c': [CalcKey.fraction],
  ',': [CalcKey.comma],
  // Shortcuts for SHIFT / ALPHA functions.
  'sin⁻¹': [CalcKey.shift, CalcKey.sin],
  'cos⁻¹': [CalcKey.shift, CalcKey.cos],
  'tan⁻¹': [CalcKey.shift, CalcKey.tan],
  'asin': [CalcKey.shift, CalcKey.sin],
  'acos': [CalcKey.shift, CalcKey.cos],
  'atan': [CalcKey.shift, CalcKey.tan],
  '10^': [CalcKey.shift, CalcKey.log],
  'e^': [CalcKey.shift, CalcKey.ln],
  'e': [CalcKey.alpha, CalcKey.ln],
  '³√': [CalcKey.shift, CalcKey.sqrt],
  'cbrt': [CalcKey.shift, CalcKey.sqrt],
  'x³': [CalcKey.shift, CalcKey.square],
  'x3': [CalcKey.shift, CalcKey.square],
  'ˣ√': [CalcKey.shift, CalcKey.power],
  'xroot': [CalcKey.shift, CalcKey.power],
  'x!': [CalcKey.shift, CalcKey.reciprocal],
  'fact': [CalcKey.shift, CalcKey.reciprocal],
  'nPr': [CalcKey.shift, CalcKey.multiply],
  'nCr': [CalcKey.shift, CalcKey.divide],
  'π': [CalcKey.shift, CalcKey.exp],
  'pi': [CalcKey.shift, CalcKey.exp],
  'Ran#': [CalcKey.shift, CalcKey.dot],
  'Rnd': [CalcKey.shift, CalcKey.d0],
  'DRG': [CalcKey.shift, CalcKey.ans],
  'STO': [CalcKey.shift, CalcKey.rcl],
  'M-': [CalcKey.shift, CalcKey.mPlus],
  'CLR': [CalcKey.shift, CalcKey.mode],
  'COPY': [CalcKey.shift, CalcKey.up],
  ':': [CalcKey.alpha, CalcKey.integrate],
  // Variable keys (after STO / RCL, or with ALPHA to type the name).
  'kA': [CalcKey.negative],
  'kB': [CalcKey.degMinSec],
  'kC': [CalcKey.hyp],
  'kD': [CalcKey.sin],
  'kE': [CalcKey.cos],
  'kF': [CalcKey.tan],
  'kM': [CalcKey.mPlus],
  'kX': [CalcKey.closeParen],
  'kY': [CalcKey.comma],
  'A': [CalcKey.alpha, CalcKey.negative],
  'B': [CalcKey.alpha, CalcKey.degMinSec],
  'C': [CalcKey.alpha, CalcKey.hyp],
  'D': [CalcKey.alpha, CalcKey.sin],
  'E': [CalcKey.alpha, CalcKey.cos],
  'F': [CalcKey.alpha, CalcKey.tan],
  'M': [CalcKey.alpha, CalcKey.mPlus],
  'X': [CalcKey.alpha, CalcKey.closeParen],
  'Y': [CalcKey.alpha, CalcKey.comma],
  'ON': [CalcKey.on],
  'sin': [CalcKey.sin],
  'cos': [CalcKey.cos],
};
