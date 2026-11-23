import 'package:flutter/material.dart';

import 'skin.dart';

/// Surface material of the body and keys. Skins set the colours; the finish
/// sets how light falls on them.
enum CalcFinish {
  classic('Classic', 'The original W-Calc look: soft gradient keys'),
  glossy('Glossy plastic', 'Bright highlights and deep shadows'),
  matte('Soft-touch matte', 'Even, low-sheen surfaces'),
  rubber('Rubber keys', 'Soft, rounded keys with a satin body'),
  metallic('Metallic', 'Brushed metal body and keys'),
  flat('Flat', 'Plain colours, thin outlines, no shadows'),
  raised('Raised', 'Chunky keys standing on a solid edge'),
  soft('Soft', 'Keys pressed gently out of the body');

  const CalcFinish(this.label, this.description);

  final String label;
  final String description;

  static CalcFinish byId(String? id) => CalcFinish.values.firstWhere(
    (f) => f.name == id,
    orElse: () => CalcFinish.classic,
  );

  static CalcFinish of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FinishScope>()?.finish ??
      CalcFinish.classic;

  Color _l(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  Color _d(Color c, double t) => Color.lerp(c, Colors.black, t)!;

  /// Key cap fill.
  Gradient keyGradient(Color base, {required bool down}) {
    final c = down ? _d(base, 0.22) : base;
    return switch (this) {
      classic => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_l(c, 0.10), c],
      ),
      flat => LinearGradient(colors: [c, c]),
      raised => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_l(c, 0.14), c],
      ),
      soft => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_l(c, 0.08), _d(c, 0.06)],
      ),
      glossy => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_l(c, 0.30), _l(c, 0.06), c, _d(c, 0.16)],
        stops: const [0, 0.45, 0.55, 1],
      ),
      matte => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_l(c, 0.05), c],
      ),
      rubber => RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 1.1,
        colors: [_l(c, 0.08), _d(c, 0.10)],
      ),
      metallic => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_l(c, 0.38), c, _d(c, 0.18), _l(c, 0.14), _d(c, 0.08)],
        stops: const [0, 0.35, 0.55, 0.75, 1],
      ),
    };
  }

  /// Specular sheen drawn over a key (null: none).
  Gradient? keySheen() => switch (this) {
    glossy => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
    ),
    metallic => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment(0.2, 0.2),
      colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
    ),
    _ => null,
  };

  /// Rim around a key (rubber keys have a soft dark edge).
  Border? keyBorder(Color base) => switch (this) {
    rubber => Border.all(color: _d(base, 0.35), width: 1.2),
    metallic => Border.all(color: _l(base, 0.35), width: 0.8),
    glossy => Border.all(color: _d(base, 0.25), width: 0.6),
    flat => Border.all(color: _d(base, 0.30), width: 1),
    matte || classic || raised || soft => null,
  };

  List<BoxShadow> keyShadow({required bool down}) {
    if (down) {
      // Raised keys keep a thin edge when pressed.
      return this == raised
          ? const [BoxShadow(color: Color(0xCC000000), offset: Offset(0, 1))]
          : const [];
    }
    return switch (this) {
      classic => const [
        BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 2)),
      ],
      flat => const [],
      raised => const [
        BoxShadow(color: Color(0xCC000000), offset: Offset(0, 4)),
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 3,
          offset: Offset(0, 5),
        ),
      ],
      soft => const [
        BoxShadow(
          color: Color(0x33FFFFFF),
          blurRadius: 4,
          offset: Offset(-2, -2),
        ),
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 5,
          offset: Offset(2, 3),
        ),
      ],
      glossy => const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 2,
          offset: Offset(0, 2.5),
        ),
      ],
      matte => const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 1.5,
          offset: Offset(0, 1.5),
        ),
      ],
      rubber => const [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
      metallic => const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 1.5,
          offset: Offset(0, 2),
        ),
      ],
    };
  }

  /// Extra roundness for keys (rubber keys are softer).
  double keyRadius(double base) => switch (this) {
    rubber => base + 4,
    soft => base + 3,
    flat => base - 2,
    _ => base,
  };

  /// Whether the body keeps the original single-piece look (no rim band).
  bool get plainBody => this == classic || this == flat;

  /// Calculator shell: a darker rim band around a shaded face.
  BoxDecoration bodyRim(CalcSkin skin, BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _l(skin.bodyTop, this == metallic ? 0.25 : 0.08),
        _d(skin.body, 0.35),
      ],
    ),
    boxShadow: const [
      BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  BoxDecoration bodyFace(CalcSkin skin, BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    gradient: switch (this) {
      metallic => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _l(skin.bodyTop, 0.20),
          skin.bodyTop,
          _l(skin.body, 0.10),
          skin.body,
          _d(skin.body, 0.10),
        ],
        stops: const [0, 0.2, 0.5, 0.8, 1],
      ),
      matte => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skin.bodyTop, skin.body],
      ),
      _ => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_l(skin.bodyTop, 0.04), skin.bodyTop, skin.body],
        stops: const [0, 0.25, 1],
      ),
    },
  );

  /// Highlight over the face (glossy shells catch the light top-left).
  Gradient? bodySheen() => switch (this) {
    glossy => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment(0.1, -0.2),
      colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
    ),
    metallic => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x14FFFFFF),
        Color(0x00FFFFFF),
        Color(0x10FFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: [0, 0.3, 0.6, 1],
    ),
    _ => null,
  };
}

/// Provides the active [CalcFinish] to the widget tree.
class FinishScope extends InheritedWidget {
  const FinishScope({super.key, required this.finish, required super.child});

  final CalcFinish finish;

  @override
  bool updateShouldNotify(FinishScope oldWidget) => oldWidget.finish != finish;
}

/// The calculator shell: rim band, shaded face and sheen, with the softly
/// curved lower edge of classic bodies.
class CalcShell extends StatelessWidget {
  const CalcShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    this.flat = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Square corners (full-screen focus mode).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    final finish = CalcFinish.of(context);
    final outer = flat
        ? BorderRadius.zero
        : const BorderRadius.vertical(
            top: Radius.circular(28),
            bottom: Radius.elliptical(44, 36),
          );
    final inner = flat
        ? BorderRadius.zero
        : const BorderRadius.vertical(
            top: Radius.circular(24),
            bottom: Radius.elliptical(40, 32),
          );
    final sheen = finish.bodySheen();
    if (finish.plainBody) {
      // The original W-Calc body: one rounded piece with a soft shadow.
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: flat ? BorderRadius.zero : BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [skin.bodyTop, skin.body],
          ),
          border: finish == CalcFinish.flat
              ? Border.all(color: Colors.black26)
              : null,
          boxShadow: flat
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: finish.bodyRim(skin, outer),
      child: Padding(
        padding: EdgeInsets.all(flat ? 0 : 4),
        child: DecoratedBox(
          decoration: finish.bodyFace(skin, inner),
          position: DecorationPosition.background,
          child: Container(
            foregroundDecoration: sheen == null
                ? null
                : BoxDecoration(borderRadius: inner, gradient: sheen),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
