import 'package:flutter/widgets.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../ui/keypad_layout.dart';

/// Engine families: two-line LCD models and textbook-display models.
enum CalcFamily { twoLine, textbook }

/// A calculator the user can choose: what it can do and which printed
/// legends it shows. All models share the engine and the keypad geometry;
/// future models can bring their own layouts and skins.
class CalcModel {
  const CalcModel({
    required this.id,
    required this.name,
    required this.description,
    required this.features,
    this.hiddenLegends = const {},
    this.hideEngineeringSymbols = false,
    this.layout = twoLineLayout,
    this.family = CalcFamily.twoLine,
    this.skinId,
    this.profile = NaturalProfile.textbook,
    this.naturalModes,
    this.indicatorLabels = const {},
    this.bigLinear = false,
  });

  /// Textbook family: MatA–MatD up to 4 × 4, VctA–VctD, four unknowns.
  final bool bigLinear;

  /// Textbook family: screen layout (single expression or four-line history).
  final NaturalProfile profile;

  /// Textbook family: modes on the MODE menu (null: all eight).
  final Set<NaturalMode>? naturalModes;

  /// LCD indicator texts that differ on this model (e.g. 2nd for SHIFT).
  final Map<Indicator, String> indicatorLabels;

  /// Which engine (and LCD) the model uses.
  final CalcFamily family;

  /// Skin applied when the user picks this model (they may change it).
  final String? skinId;

  /// A fresh engine for this model.
  CalcEngine createEngine() => switch (family) {
    CalcFamily.twoLine => Calculator(features: features),
    CalcFamily.textbook => NaturalCalculator(
      profile: profile,
      modes: naturalModes,
      bigLinear: bigLinear,
    ),
  };

  final String id;
  final String name;
  final String description;
  final CalcFeatures features;

  /// Printed legends (SHIFT / mode functions) this model does not have.
  final Set<String> hiddenLegends;

  /// Hide the k, M, G … legends on the digit keys.
  final bool hideEngineeringSymbols;

  /// Physical arrangement of the keys.
  final KeypadLayout layout;

  static const plus = CalcModel(
    id: 'plus',
    name: 'Scientific Plus',
    description: 'All modes: complex, statistics, base-n, equations, matrices, vectors, calculus, constants',
    features: CalcFeatures.full,
  );

  static const basic = CalcModel(
    id: 'basic',
    name: 'Scientific Basic',
    description: 'Everyday school model: calculations, fractions, statistics and regression',
    features: CalcFeatures.basic,
    hiddenLegends: {
      'CONV',
      'd/dx',
      'SOLVE',
      'LOGIC',
      'DEC',
      'HEX',
      'BIN',
      'OCT',
      '∠',
      'arg',
      'Abs',
      'Conjg',
      '▸r∠θ',
      '▸a+bi',
      'Re↔Im',
      'i',
      'MAT',
      'VCT',
      '=',
      ':',
    },
    hideEngineeringSymbols: true,
  );

  static const grid = CalcModel(
    id: 'grid',
    name: 'Scientific Grid',
    description: 'Square key grid with arrow keys and a 2nd key; complex, statistics, base-n and equations',
    features: CalcFeatures.standard,
    hiddenLegends: {'MAT', 'VCT'},
    layout: gridLayout,
  );

  static const textbook = CalcModel(
    id: 'textbook',
    name: 'Textbook Plus',
    description:
        'Natural textbook display: fractions, roots and powers as written. '
        'Silver body with a round cursor disc',
    features: CalcFeatures.full,
    layout: textbookDiscLayout,
    family: CalcFamily.textbook,
    skinId: 'silver',
  );

  static const textbook2 = CalcModel(
    id: 'textbook2',
    name: 'Textbook Plus II',
    description:
        'Same functions as Textbook Plus in the newer black body with four '
        'arrow keys',
    features: CalcFeatures.full,
    layout: textbookCrossLayout,
    family: CalcFamily.textbook,
    skinId: 'black',
  );

  /// Four-line history display with textbook input; 2nd key.
  static final view = CalcModel(
    id: 'view',
    name: 'Scientific View',
    description:
        'Four-line display that keeps earlier entries and answers on screen; '
        'textbook input, ◄► answer toggle, statistics and tables',
    features: CalcFeatures.full,
    layout: viewLayout,
    family: CalcFamily.textbook,
    skinId: 'slate',
    profile: NaturalProfile.multiLine,
    naturalModes: {NaturalMode.comp, NaturalMode.stat, NaturalMode.table},
    indicatorLabels: {Indicator.shift: '2nd'},
  );

  /// Four-line textbook display, 2ndF key, round cursor pad.
  static final write = CalcModel(
    id: 'write',
    name: 'Scientific Write',
    description:
        'Four-line textbook display with a 2ndF key; calculations, complex '
        'numbers, statistics, tables and equations',
    features: CalcFeatures.full,
    layout: writeLayout,
    family: CalcFamily.textbook,
    skinId: 'pearl',
    profile: NaturalProfile.multiLine,
    naturalModes: {
      NaturalMode.comp,
      NaturalMode.cmplx,
      NaturalMode.stat,
      NaturalMode.eqn,
      NaturalMode.table,
    },
    indicatorLabels: {Indicator.shift: '2ndF'},
  );

  /// Two-line dot display: entry line above a tall result line; 2nd key.
  static final twoView = CalcModel(
    id: 'twoview',
    name: 'Scientific Two-View',
    description:
        'Classic two-line dot display: the entry on top (÷ shown as /), the '
        'answer below; fractions like 14/15 and 7u1/8, statistics',
    features: CalcFeatures.full,
    layout: viewLayout,
    family: CalcFamily.textbook,
    skinId: 'graphite',
    profile: NaturalProfile.twoLine,
    naturalModes: {NaturalMode.comp, NaturalMode.stat},
    indicatorLabels: {Indicator.shift: '2nd'},
  );

  /// Textbook display with bigger linear algebra (four 4 × 4 matrices,
  /// four vectors, four unknowns).
  static final max = CalcModel(
    id: 'max',
    name: 'Scientific Max',
    description:
        'Textbook display with four matrices up to 4×4, four vectors and '
        'equations with four unknowns',
    features: CalcFeatures.full,
    layout: textbookDiscLayout,
    family: CalcFamily.textbook,
    skinId: 'ocean',
    bigLinear: true,
  );

  static final all = [
    plus,
    grid,
    basic,
    textbook,
    textbook2,
    max,
    twoView,
    view,
    write,
  ];

  static CalcModel byId(String? id) =>
      all.firstWhere((m) => m.id == id, orElse: () => plus);

  static const _engSymbolKeys = {
    CalcKey.d1,
    CalcKey.d2,
    CalcKey.d3,
    CalcKey.d4,
    CalcKey.d5,
    CalcKey.d6,
    CalcKey.d7,
    CalcKey.d8,
    CalcKey.d9,
  };
  static const _engSymbolTexts = {'f', 'p', 'n', 'μ', 'm', 'k', 'M', 'G', 'T'};

  /// Whether [label] printed near [key] belongs to this model.
  bool showsLegend(CalcKey key, KeyLabel label) {
    if (label.kind != LabelKind.alpha && hiddenLegends.contains(label.text)) {
      return false;
    }
    if (label.kind == LabelKind.alpha && label.text == '=' ||
        label.text == ':') {
      return features.calc;
    }
    if (hideEngineeringSymbols &&
        _engSymbolKeys.contains(key) &&
        _engSymbolTexts.contains(label.text)) {
      return false;
    }
    return true;
  }

  /// Key caps without a function on this model are drawn faded.
  bool keyEnabled(CalcKey key) =>
      family == CalcFamily.textbook || features.allows(key, shift: false);
}

/// Provides the active [CalcModel] to the widget tree.
class ModelScope extends InheritedWidget {
  const ModelScope({super.key, required this.model, required super.child});

  final CalcModel model;

  static CalcModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModelScope>()?.model ??
      CalcModel.plus;

  @override
  bool updateShouldNotify(ModelScope oldWidget) => oldWidget.model != model;
}
