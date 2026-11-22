import 'package:wcalc_engine/wcalc_engine.dart';

/// Parses a test-vector key sequence into keys.
///
/// Words are separated by spaces. A word of only digits/points expands to one
/// key per character (`56` → 5, 6; `2.5` → 2, ., 5). Other words are key names
/// as written in the manual/test vectors, e.g. `(-)`, `EXP`, `SHIFT`, `<`.
List<CalcKey> keys(String sequence) {
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
    if (mapped == null) throw ArgumentError('Unknown key name "$word"');
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
  '^': [CalcKey.up],
  'v': [CalcKey.down],
  'ON': [CalcKey.on],
  'sin': [CalcKey.sin],
  'cos': [CalcKey.cos],
};
