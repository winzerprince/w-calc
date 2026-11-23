import 'fullscreen_native.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart'
    as impl;

/// Focus mode: the calculator fills the whole screen (system bars hidden on
/// phones, browser fullscreen on the web).
Future<void> setFullscreen(bool on) => impl.setFullscreen(on);
