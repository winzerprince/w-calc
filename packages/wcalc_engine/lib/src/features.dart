import 'calc_key.dart';

/// Calculation modes of the engine.
enum CalcMode { comp, cmplx, sd, reg, base, eqn, mat, vct }

/// What a calculator model offers. The full feature set matches the
/// reference model; smaller models switch parts off while sharing the engine.
class CalcFeatures {
  const CalcFeatures({
    this.modes = const {...CalcMode.values},
    this.constants = true,
    this.conversions = true,
    this.calculus = true,
    this.calc = true,
    this.solve = true,
    this.engSymbols = true,
  });

  /// Everything (the two-line "991-style" reference model).
  static const full = CalcFeatures();

  /// Basic two-line scientific: COMP, SD, REG; no constants, conversions,
  /// calculus, CALC or SOLVE.
  /// Everything except matrices and vectors.
  static const standard = CalcFeatures(
    modes: {
      CalcMode.comp,
      CalcMode.cmplx,
      CalcMode.sd,
      CalcMode.reg,
      CalcMode.base,
      CalcMode.eqn,
    },
  );

  static const basic = CalcFeatures(
    modes: {CalcMode.comp, CalcMode.sd, CalcMode.reg},
    constants: false,
    conversions: false,
    calculus: false,
    calc: false,
    solve: false,
    engSymbols: false,
  );

  final Set<CalcMode> modes;
  final bool constants;
  final bool conversions;
  final bool calculus;
  final bool calc;
  final bool solve;
  final bool engSymbols;

  /// Whether a key press (with SHIFT when [shift]) is available.
  bool allows(CalcKey key, {required bool shift}) => switch (key) {
    CalcKey.constant => shift ? conversions : constants,
    CalcKey.integrate => calculus,
    CalcKey.calc => shift ? solve : calc,
    _ => true,
  };
}
