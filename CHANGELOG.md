# Changelog

All notable changes. Format: `## [version] - date`, newest first. Release notes are taken from here by CI.

## [0.0.3-alpha] - 2026-11-22

Scientific functions (M3) and device-accurate keypad legends.

### Added
- Functions computed with 34 working digits and rounded to 15: sin cos tan and inverses
  (Deg/Rad/Gra with exact quadrants), hyperbolic and inverses, log, ln, 10ˣ, eˣ, √, ∛, x², x³,
  x⁻¹, x!, x^y, ˣ√y, nPr, nCr, π, e, Ran#, Rnd, DRG▶ conversion; device input ranges (Math ERROR).
- Device priority for powers, Type A/B functions, implied multiplication (2π, 2√3), nPr/nCr.
- MODE setup screens: angle unit (Deg/Rad/Gra) and display format (Fix/Sci/Norm) with indicators.
- 309 reference values checked against mpmath (`tool/gen_function_vectors.py`).

### Changed
- Keypad legends positioned, ordered and coloured like the device, with mode brackets and
  legends under the row-4 keys; labels above SHIFT/ALPHA/MODE/ON; oval REPLAY disc.
- Result line: dot + comma tail at every digit with 3-digit grouping.

## [0.0.2-alpha] - 2026-11-22

Arithmetic engine and first real look.

### Added
- 15-digit decimal arithmetic (`0.1 + 0.2 = 0.3` exactly); results in Norm 1/2, Fix, Sci formats.
- Expression evaluation following the device priority rules: + − × ÷, (−), parentheses
  (final `)` optional), implied multiplication, Ans, EXP; Math / Syntax / Stack ERROR.
- Device-like editing: overwrite and INS cursor, DEL, ◀ ▶, 12-column scrolling, 79-step limit,
  replay of the last expression, `=` repeats with new Ans.
- LCD: original 5×7 dot-matrix font, seven-segment result line with exponent, indicator row
  (S, A, D …), blinking cursor.
- Keypad: full layout with colour-coded secondary legends, cursor disc, press feedback, haptics.
- Web: physical keyboard support; `?keys=` repro links; bundled fonts (works offline).

## [0.0.1-alpha] - 2026-11-22

First pipeline release (skeleton).

### Added
- Flutter app shell (Android + web) with placeholder LCD and full keypad layout.
- `wcalc_engine` pure-Dart package: key model, display state, digit entry, AC, SHIFT/ALPHA indicators.
- CI/CD: fast checks on PRs to `dev`; full gate on PRs to `main`; signed Android build and GitHub Release on merge to `main`.
- Project docs: plan, CI/CD rules, working agreement.
