import 'package:flutter/widgets.dart';
import 'package:wcalc_engine/wcalc_engine.dart' show CalcKey;

import '../../app/app_settings.dart';
import '../../app/calc_model.dart';
import '../legend.dart';
import 'coach_tour.dart';

/// Widgets the tours point at.
abstract final class TourKeys {
  static final menu = GlobalKey(debugLabel: 'tour-menu');
  static final lcd = GlobalKey(debugLabel: 'tour-lcd');
  static final shift = GlobalKey(debugLabel: 'tour-shift');
  static final mode = GlobalKey(debugLabel: 'tour-mode');
  static final solar = GlobalKey(debugLabel: 'tour-solar');
  static final keypad = GlobalKey(debugLabel: 'tour-keypad');
  static final modelPicture = GlobalKey(debugLabel: 'tour-model-picture');
  static final modelChoice = GlobalKey(debugLabel: 'tour-model-choice');
  static final skins = GlobalKey(debugLabel: 'tour-skins');
  static final finish = GlobalKey(debugLabel: 'tour-finish');
  static final manualSearch = GlobalKey(debugLabel: 'tour-manual-search');
  static final manualChapters = GlobalKey(debugLabel: 'tour-manual-chapters');
}

/// Tour ids (stored once seen).
abstract final class Tours {
  static const calculator = 'calculator';
  static const models = 'models';
  static const theme = 'theme';
  static const manual = 'manual';
}

List<TourStep> calculatorTour(CalcModel model) {
  final shift =
      model.layout.allKeys
          .where((k) => k.key == CalcKey.shift)
          .map((k) => legendText(k.main))
          .firstOrNull ??
      'SHIFT';
  return [
    TourStep(
      TourKeys.menu,
      'Tap here for the menu:\nmodels, themes, finishes and the manual',
    ),
    TourStep(
      TourKeys.lcd,
      'This is your display.\nLong-press it to copy the answer!',
    ),
    TourStep(
      TourKeys.shift,
      '$shift unlocks the coloured\nlabels printed above the keys',
    ),
    TourStep(
      TourKeys.mode,
      'MODE switches modes — statistics,\nequations, complex numbers…',
    ),
    TourStep(TourKeys.solar, 'Psst… tap the solar panel\nfor full screen'),
    TourStep(
      TourKeys.keypad,
      'Every key works like the real thing.\nHappy calculating!',
    ),
  ];
}

final modelsTour = [
  TourStep(
    TourKeys.modelPicture,
    'Tap a picture to see\nthe calculator up close',
  ),
  TourStep(
    TourKeys.modelChoice,
    'Pick the one that looks like yours —\nit switches straight away',
  ),
];

final themeTour = [
  TourStep(TourKeys.skins, 'Colours for the body,\nkeys and display'),
  TourStep(TourKeys.finish, 'And the feel: glossy, matte,\nrubber or metal'),
];

final manualTour = [
  TourStep(
    TourKeys.manualSearch,
    'Search anything —\ntry “fraction” or “mean”',
  ),
  TourStep(
    TourKeys.manualChapters,
    '…or browse the chapters,\nwritten for your model',
  ),
];

/// Runs tour [id] once (after the page has been laid out), unless it was
/// seen before or settings are not loaded yet. [force] replays it.
void runTourOnce(
  BuildContext context,
  String id,
  List<TourStep> Function() steps, {
  bool force = false,
}) {
  final settings = SettingsScope.maybeOf(context);
  if (settings == null) return;
  if (!force && (!settings.loaded || settings.seenTours.contains(id))) return;
  settings.markTourSeen(id);
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Let page transitions finish so targets are in place.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    await showTour(context, steps());
  });
}

/// Settings ▸ Help asks the calculator screen to replay its tour.
final calculatorTourRequest = ValueNotifier<int>(0);
