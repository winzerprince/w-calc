import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'keypad_layout.dart';

/// Two-line LCD. Skeleton rendering; dot-matrix / 7-segment painters come in the UI milestone.
class Lcd extends StatelessWidget {
  const Lcd({super.key, required this.display});

  final DisplayState display;

  static const _indicatorText = {
    Indicator.shift: 'S',
    Indicator.alpha: 'A',
    Indicator.hyp: 'hyp',
    Indicator.memory: 'M',
    Indicator.sto: 'STO',
    Indicator.rcl: 'RCL',
    Indicator.deg: 'D',
    Indicator.rad: 'R',
    Indicator.gra: 'G',
  };

  @override
  Widget build(BuildContext context) {
    const ink = TextStyle(color: WCalcColors.lcdInk, fontFamily: 'monospace');
    final indicators = display.indicators
        .map((i) => _indicatorText[i] ?? i.name.toUpperCase())
        .join('  ');
    return Container(
      key: const Key('lcd'),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: WCalcColors.lcd,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 14,
            child: Text(
              indicators,
              key: const Key('lcd-indicators'),
              style: ink.copyWith(fontSize: 11),
            ),
          ),
          Text(
            display.upper,
            key: const Key('lcd-upper'),
            style: ink.copyWith(fontSize: 22),
            maxLines: 1,
          ),
          Text(
            display.lower,
            key: const Key('lcd-lower'),
            textAlign: TextAlign.right,
            style: ink.copyWith(fontSize: 34, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
