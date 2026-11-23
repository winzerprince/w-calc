import 'package:flutter/widgets.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../ui/keypad_layout.dart';

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
  });

  final String id;
  final String name;
  final String description;
  final CalcFeatures features;

  /// Printed legends (SHIFT / mode functions) this model does not have.
  final Set<String> hiddenLegends;

  /// Hide the k, M, G … legends on the digit keys.
  final bool hideEngineeringSymbols;

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

  static const all = [plus, basic];

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
  bool keyEnabled(CalcKey key) => features.allows(key, shift: false);
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
