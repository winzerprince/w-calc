import 'package:flutter/services.dart';

/// Android: VIRTUAL_KEY feedback, the same short buzz as the system keyboard.
void keyVibration() => HapticFeedback.lightImpact();
