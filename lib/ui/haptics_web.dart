import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browsers: a 15 ms vibration (ignored where unsupported, e.g. iOS Safari).
void keyVibration() {
  try {
    web.window.navigator.vibrate(15.toJS);
  } catch (_) {
    // Vibration API missing or blocked: silently skip.
  }
}
