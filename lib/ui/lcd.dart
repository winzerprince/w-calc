import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'keypad_layout.dart';

/// Two-line LCD. Interim rendering; dot-matrix / 7-segment painters come in the UI milestone.
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

  static const _ink = TextStyle(
    color: WCalcColors.lcdInk,
    fontFamily: 'monospace',
  );

  @override
  Widget build(BuildContext context) {
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
              style: _ink.copyWith(fontSize: 11),
            ),
          ),
          _UpperLine(display: display),
          SizedBox(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display.lower,
                    key: const Key('lcd-lower'),
                    style: _ink.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (display.exponent != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 2),
                      child: Text(
                        display.exponent!,
                        key: const Key('lcd-exponent'),
                        style: _ink.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperLine extends StatelessWidget {
  const _UpperLine({required this.display});

  final DisplayState display;

  @override
  Widget build(BuildContext context) {
    final style = Lcd._ink.copyWith(fontSize: 22);
    final text = display.upper;
    final cursor = display.cursor;
    // Plain text for tests / semantics; cursor drawn as decoration on one character.
    final spans = <InlineSpan>[];
    for (var i = 0; i < text.length; i++) {
      spans.add(
        TextSpan(
          text: text[i],
          style: i == cursor ? _cursorStyle(style) : null,
        ),
      );
    }
    if (cursor != null && cursor >= text.length) {
      spans.add(
        TextSpan(text: display.cursorStyle == CursorStyle.block ? '■' : '_'),
      );
    }
    return Stack(
      children: [
        Offstage(child: Text(text, key: const Key('lcd-upper'))),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(style: style, children: spans),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  TextStyle _cursorStyle(TextStyle base) => switch (display.cursorStyle) {
    CursorStyle.insert => base.copyWith(
      backgroundColor: WCalcColors.lcdInk.withValues(alpha: 0.25),
    ),
    CursorStyle.block => base.copyWith(
      color: WCalcColors.lcd,
      backgroundColor: WCalcColors.lcdInk,
    ),
    CursorStyle.underscore => base.copyWith(
      decoration: TextDecoration.underline,
      decorationThickness: 2,
    ),
  };
}
