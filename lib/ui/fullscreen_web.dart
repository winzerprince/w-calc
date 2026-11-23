import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> setFullscreen(bool on) async {
  try {
    if (on) {
      await web.document.documentElement?.requestFullscreen().toDart;
    } else if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {
    // Fullscreen refused (no user gesture, iOS Safari): keep the page as is.
  }
}
