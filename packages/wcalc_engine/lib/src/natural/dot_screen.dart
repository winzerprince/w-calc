import '../display_state.dart';
import '../lcd/dot_bitmap.dart';
import 'math_render.dart';

/// What a full-dot LCD shows: the 96 × 31 dot area, the indicator row and
/// where the blinking cursor is (the app blinks it).
final class DotScreen {
  const DotScreen({
    required this.dots,
    this.indicators = const {},
    this.cursor,
    this.isOff = false,
    this.contrast = 0,
    this.text = '',
  });

  static const int width = 96;
  static const int height = 31;

  final DotBitmap dots;
  final Set<Indicator> indicators;
  final CursorRect? cursor;
  final bool isOff;
  final int contrast;

  /// Plain-text mirror of the screen for tests and screen readers.
  final String text;

  static final DotScreen off = DotScreen(
    dots: DotBitmap(width, height),
    isOff: true,
  );
}
