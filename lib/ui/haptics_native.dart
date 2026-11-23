import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _channel = MethodChannel('wcalc/haptics');

/// Android: a short tick from the Vibrator service (works even when the
/// system "touch feedback" setting is off). Elsewhere, or if that fails,
/// Flutter's light haptic.
void keyVibration() {
  if (Platform.isAndroid) {
    _channel
        .invokeMethod<bool>('tick')
        .then((ok) {
          if (ok != true) HapticFeedback.lightImpact();
        })
        .catchError((Object _) {
          HapticFeedback.lightImpact();
        });
    return;
  }
  HapticFeedback.lightImpact();
}
