import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'lcd/lcd_painter.dart';
import 'skin.dart';

/// Two-line LCD: indicator row, 12-column dot-matrix line, seven-segment result line.
class Lcd extends StatefulWidget {
  const Lcd({super.key, required this.display});

  final DisplayState display;

  /// Cursor blink half-period.
  static const blinkInterval = Duration(milliseconds: 500);

  @override
  State<Lcd> createState() => _LcdState();
}

/// Screen-reader text for the private-use statistics symbols.
String _speakable(String text) => text
    .replaceAll('\uE000', 'x bar')
    .replaceAll('\uE001', 'y bar')
    .replaceAll('\uE002', 'x hat')
    .replaceAll('\uE003', 'y hat');

class _LcdState extends State<Lcd> {
  Timer? _blink;
  bool _cursorOn = true;

  @override
  void initState() {
    super.initState();
    _restartBlink();
  }

  @override
  void didUpdateWidget(Lcd old) {
    super.didUpdateWidget(old);
    // Any key press shows the cursor immediately, like the device.
    _restartBlink();
  }

  void _restartBlink() {
    _blink?.cancel();
    _cursorOn = true;
    if (widget.display.cursor == null) return;
    _blink = Timer.periodic(Lcd.blinkInterval, (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.display;
    final spoken = [
      _speakable(d.upper),
      d.lower,
      if (d.exponent != null) 'times ten to the ${d.exponent}',
    ].where((s) => s.isNotEmpty).join(', ');
    return Semantics(
      key: const Key('lcd'),
      label: spoken,
      liveRegion: true,
      child: Stack(
        children: [
          // Plain-text mirror of the display for tests and accessibility tooling.
          Offstage(
            child: Column(
              children: [
                Text(d.upper, key: const Key('lcd-upper')),
                Text(d.lower, key: const Key('lcd-lower')),
                if (d.exponent != null)
                  Text(d.exponent!, key: const Key('lcd-exponent')),
                Text(
                  d.indicators.map((i) => i.name).join(' '),
                  key: const Key('lcd-indicators'),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: LcdPainter.aspectRatio,
            child: CustomPaint(
              painter: LcdPainter(
                display: d,
                cursorVisible: _cursorOn,
                palette: CalcSkin.of(context).lcd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
