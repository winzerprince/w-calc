import 'package:flutter/services.dart';

Future<void> setFullscreen(bool on) => SystemChrome.setEnabledSystemUIMode(
  on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
);
