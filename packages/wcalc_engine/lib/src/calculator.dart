import 'calc_key.dart';
import 'display_state.dart';

enum _Modifier { none, shift, alpha }

/// Key-driven calculator state machine.
///
/// Skeleton: digit entry, AC, SHIFT/ALPHA modifiers. Expression parsing and
/// evaluation arrive in later milestones (see docs/PLAN.md).
class Calculator {
  final StringBuffer _input = StringBuffer();
  _Modifier _modifier = _Modifier.none;

  DisplayState get display => DisplayState(
    upper: _input.toString(),
    lower: '0.',
    indicators: {
      if (_modifier == _Modifier.shift) Indicator.shift,
      if (_modifier == _Modifier.alpha) Indicator.alpha,
    },
  );

  void press(CalcKey key) {
    switch (key) {
      case CalcKey.shift:
        _modifier = _modifier == _Modifier.shift
            ? _Modifier.none
            : _Modifier.shift;
        return;
      case CalcKey.alpha:
        _modifier = _modifier == _Modifier.alpha
            ? _Modifier.none
            : _Modifier.alpha;
        return;
      default:
        break;
    }

    _modifier = _Modifier.none;

    if (key == CalcKey.ac) {
      _input.clear();
      return;
    }
    final digit = key.digit;
    if (digit != null) _input.write(digit);
  }
}
