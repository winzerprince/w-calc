import 'package:flutter/material.dart';

import '../app/calc_model.dart';
import 'keypad.dart';
import 'skin.dart';

/// Miniature of a calculator model: its real keypad and body in its own
/// colours, scaled down. Used where the user picks a model.
class ModelThumbnail extends StatelessWidget {
  const ModelThumbnail({
    super.key,
    required this.model,
    this.width = 64,
    this.skin,
  });

  final CalcModel model;
  final double width;

  /// Skin to draw with; defaults to the model's own (or Classic).
  final CalcSkin? skin;

  /// Logical size the miniature is laid out at before scaling.
  static const _w = 360.0, _h = 760.0;

  @override
  Widget build(BuildContext context) {
    final s = skin ?? CalcSkin.byId(model.skinId);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            width: width,
            height: width * _h / _w,
            child: FittedBox(
              child: SizedBox(
                width: _w,
                height: _h,
                child: ModelScope(
                  model: model,
                  child: SkinScope(
                    skin: s,
                    child: _Body(skin: s),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.skin});

  final CalcSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.bodyTop, skin.body],
        ),
        border: Border.all(color: Colors.black45, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(width: 96, height: 22, color: skin.solarStrip),
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: skin.bezel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: skin.lcd.glass,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: Keypad(onPress: (_) {})),
        ],
      ),
    );
  }
}
