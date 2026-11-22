import 'haptics_native.dart'
    if (dart.library.js_interop) 'haptics_web.dart'
    as impl;

/// Brief vibration for a key press: native haptics on Android/iOS,
/// `navigator.vibrate` in browsers that support it (Android Chrome).
void keyVibration() => impl.keyVibration();
