# Changelog

All notable changes. Format: `## [version] - date`, newest first. Release notes are taken from here by CI.

## [Unreleased]

### Added
- Settings ▸ App appearance: System, Light or Dark for menus and pages (separate from calculator
  themes) and a text-size slider (85–150 %).
- History (Menu ▸ History or the clock button): every calculation with its time and answer,
  kept separately per model; tap to copy; clear per model. "Save history on this device" is on
  by default — switching it off stops saving and removes what was stored.

### Changed
- Header: W-Calc sits top left above the menu icon; history and graph buttons have fixed slots,
  so nothing shifts when they appear; solar panel and model name top right.
- New app icon: indigo tile, bright display, white keys with an orange accent.

### Added
- Graph: mouse wheel / trackpad scroll zooms around the pointer (web).

## [0.10.0-beta] - 2026-11-23

Ten models, history at a tap, INS wrapping, smoother pages.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Added
- Textbook models: INS (SHIFT DEL) before a function wraps what follows the cursor into it, e.g.
  1+7/6 → 1+√(7/6).
- History button next to the logo: earlier calculations and answers; tap one to copy its answer.
- *Textbook Basic* model: everyday textbook display with COMP, STAT and TABLE (no calculus,
  CALC/SOLVE, constants or conversions; those keys are faded); Indigo theme.

### Changed
- Pages open and close with a soft fade-and-rise animation.

## [0.9.0-beta] - 2026-11-23

Store readiness: launch screen, adaptive icon, key hints, privacy policy, crash fuzzing.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Added
- Crash testing: thousands of random key presses on every engine and model pass without
  errors.
- Adaptive launcher icon on Android 8+ (no white frame around the icon).
- Launch screen: dark backdrop with the W-Calc icon (Android 12+ splash too); no white flash.
- Long-press a key to see what else it does (SHIFT / 2nd, ALPHA and mode functions).
- Store listing draft and privacy policy (no data collected); privacy line on the About page.

## [0.8.0-beta] - 2026-11-23

Graphs from equations and statistics, TI-style menus, a smaller and lighter app.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Added
- More graph shortcuts: the graph button also appears for quadratic / cubic equations (their
  polynomial) and for paired statistics data (scatter plot with the regression curve), on the
  two-line models' REG mode too.
- Graph mode remembers the functions you typed.
- Graph in landscape keeps the function list beside the plot; screen readers hear a summary
  (curves, roots, turning points, intersections).
- Scientific View and Two-View: menus show option names in rows; ◀ ▶ move the highlight and
  enter chooses (numbers still work).

### Changed
- Smaller download: the bundled fonts are subset to the characters W-Calc uses (−285 KB).
- Dot displays draw in two batched calls (lighter on battery and older phones).

## [0.7.0-beta] - 2026-11-23

Graphs, more key styles, constant and conversion lists, glass displays.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Added
- LCD glass: a soft shadow under the display window's top edge and a faint reflection.
- Graph: plot functions (typed like 2x+1, sin(x), sqrt(x)), pan and pinch to zoom, tap to trace,
  roots, extrema and y-intercepts marked, Rad/Deg. A graph button appears next to the logo when
  the calculation uses X; Menu ▸ Graph opens graph mode. Intersections are marked too; a short
  tour and a manual chapter explain it. A table button lists x and y values for the visible
  curves; tapping a row traces it.
- Manual: full lists of the 40 constants (name, symbol, value, unit) and 40 unit conversions,
  with a filter box; values come straight from the calculator.
- Key styles: Classic (the original W-Calc look, now the default), Flat, Raised and Soft join
  Glossy, Matte, Rubber and Metallic (Menu ▸ Theme ▸ Finish).

## [0.6.0-beta] - 2026-11-23

Nine calculator models: new two-line dot, four-line and big-matrix models; first-start tours.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Fixed
- Textbook models: the matrix size menu now shows its second page (1×3, 1×2).
- Font licence texts are now bundled so the third-party licence page can show them.

### Added
- Scientific View: statistics editor columns named L1, L2, L3.
- Model picker grouped by display: two-line, textbook and multi-line.
- *Scientific Max* model: textbook display with four matrices up to 4×4 (size typed as m?, n?),
  four vectors and equations with four unknowns; Ocean theme.
- *Scientific Two-View* model: classic two-line dot display (entry line with / and *, tall answer
  line with a trailing point, fractions 14/15 and 7u1/8, ◄► toggle), 2nd key, Graphite theme.
- First-start tours: hand-drawn notes and arrows over a dark scrim explain the display, menu,
  modifier and MODE keys, the solar panel; the model, theme and manual pages have their own.
  Replay them from Settings ▸ Help.
- Two four-line models: *Scientific View* (history display, 2nd key, ◄► answer toggle, enter;
  COMP, STAT, TABLE) and *Scientific Write* (2ndF key, round pad; COMP, CMPLX, STAT, EQN, TABLE),
  with new Slate and Pearl themes.
- Textbook engine: display profiles (single expression or four-line history) and per-model
  mode lists; model-specific LCD indicator names (2nd / 2ndF).

## [0.5.0-beta] - 2026-11-23

Finishes and body shapes, model previews, focus mode, a fuller manual, and a proprietary licence.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Fixed
- The chosen calculator model was not remembered after restarting the app.

### Removed
- Keyboard shortcuts page (physical keyboards still work).

### Added
- Manual: Advanced functions chapter (hyperbolic, Pol/Rec, ENG, DRG▸, °′″, multi-statements,
  Abs/Rnd, replay and history).
- Textbook models: multi-statements stop at each result (Disp); °′″ on a result switches to the
  decimal.
- Finishes (Menu ▸ Theme ▸ Finish): glossy plastic, soft-touch matte, rubber keys or metallic,
  for keys, cursor pad and body; the body is now a shaded shell with a rim and curved lower edge.
- Model picker shows a miniature of each calculator (its real keypad and colours); tap it for a
  large preview with a "Use this model" button.
- Focus mode: tap the solar panel to show the calculator full screen (system bars hidden, or
  browser full screen); tap again to return.

### Changed
- About page shortened to version, purpose, notice and legal information.
- Licence: W-Calc is now proprietary (all rights reserved). Versions up to v0.4.0-beta remain
  GPL-3.0-or-later for anyone who received them.

## [0.4.0-beta] - 2026-11-23

All eight modes on the textbook-display models, and working key vibration on Android.

**Which file to install on Android:** most phones need `…-arm64-v8a.apk`; if unsure, use
`…-universal.apk`.

### Fixed
- Android: key-press vibration now uses the vibrator directly, so it works even when the phone's
  touch-feedback setting is off.

### Added
- Textbook models: STAT mode with the eight regression types (incl. A·B^x), Stat Editor
  (FREQ column, DEL row, Ins, Del-A), and the Sum / Var / Reg / Distr / MinMax menus.
- Textbook models: EQN mode (2-3 unknowns, quadratic, cubic) with a Coefficient Editor that
  accepts fractions and √, exact quadratic roots (−1/2 ± √2/2 i, double root shown once).
- Textbook models: BASE-N mode (16-bit binary, 32-bit octal / hex, padded results, logic
  menu with d h b o prefixes).
- Textbook models: MATRIX and VECTOR modes (Dim / Data menus, grid editor, MatAns / VctAns
  screens that continue with an operator, det, Trn, inverse, powers, Abs, Dot, cross product).
  All eight textbook modes now work.
- Textbook models remember the mode, BASE-N number system, STAT data and matrices / vectors
  across restarts.
- Textbook models: TABLE mode (f(X), Start / End / Step, up to 30 rows, Insufficient MEM).

## [0.3.0-beta] - 2026-11-23

Textbook-display calculators (silver and black bodies), exact results and a searchable manual.

**Which file to install on Android:** most phones from the last ten years (for example Samsung
Galaxy S-series) need `…-arm64-v8a.apk`; if unsure, use `…-universal.apk`. The `x86_64` file is
for emulators and Chromebooks only and shows "app not compatible" on phones.

### Added
- Manual (Menu ▸ Manual) replaces the user guide: searchable chapters and articles with keycap
  key sequences and worked examples for the model in use, on a white or black page matching the
  theme. Every example is checked against the calculator by a test.
- Engine groundwork for the textbook-display models (silver / black units): 2-D input editor
  (fractions, roots, powers, log base, Abs, ∫, d/dx, Σ), full-dot 96×31 screen rendering,
  COMP calculations with exact fraction results, S⇔D, SETUP / MODE / CLR / hyp / DRG menus,
  memories, errors with Goto.
- Two new calculator models in Menu ▸ Calculator model: *Textbook Plus* (silver body, round
  cursor disc) and *Textbook Plus II* (black body, four arrow keys), with full-dot LCD and their
  own Silver / Black themes. COMP and CMPLX work; STAT, BASE-N, EQN, MATRIX, TABLE and VECTOR
  follow in the next releases.
- Textbook models keep results exact: fractions, √ forms ((√2+2)×√3 = 2√3+√6, 1÷√2 = √2/2)
  and π forms (π÷6 = π/6); function results such as sin 45° are recognised. S⇔D and SHIFT =
  switch to decimals.
- Textbook models: CMPLX mode (i, ∠, arg, Conjg, ▶r∠θ, ▶a+bi, exact parts), CALC with prompts
  and Y = … assignment, SOLVE for X with the L−R check, multi-statements.

### Fixed
- Copying a BASE-mode result no longer includes the base letter.

## [0.2.0-beta] - 2026-11-23

Calculator models, accessibility and tablet layout.

### Added
- Calculator models: choose *Scientific Plus* (all modes) or *Scientific Basic* (COMP, SD, REG) in
  Menu ▸ Calculator model. Memories and data carry over; keys a model lacks are faded and inert.
- *Scientific Grid* model: square key grid with arrow keys and a 2nd key; all modes except MAT/VCT.
  Keypad layouts are now data (`KeypadLayout`), so models can differ in look. Web: `?model=grid`.
- Tablets: portrait body grows up to 620 px wide and keeps calculator proportions.
- Long-press the LCD to copy the result (plain text, `E` notation).
- Screen readers: keys can be activated by TalkBack/VoiceOver and announce their second functions.
- Busy display during long calculations, landscape layout and app icon.

### Fixed
- MAT/VCT: at most two matrices or vectors may be pending in a calculation (Stack ERROR otherwise).

## [0.1.0-beta] - 2026-11-23

All calculation modes of the reference calculator, plus app settings and themes.

### Added
- BASE mode: DEC/HEX/BIN/OCT, 32-bit integer arithmetic, two's complement, And/Or/Xor/Xnor/Not/Neg,
  d/h/b/o prefixes.
- EQN mode: 2–3 simultaneous linear equations, quadratic and cubic equations (complex roots).
- MAT mode: matrices up to 3×3 — Dim, Edit, +, −, ×, scalar ×, Det, Trn, Abs, x⁻¹, x², x³, MatAns.
- VCT mode: 2-D/3-D vectors — Dim, Edit, +, −, scalar ×, dot and cross products, Abs, VctAns.
- OFF (SHIFT AC) and LCD contrast (Disp ◀CONT▶).
- Settings: vibration and click sound on key press, theme, factory reset.
- Themes: Classic, Midnight (backlit LCD), High contrast, Ivory.
- In-app user guide, keyboard shortcut list, About page with version and licences.

### Changed
- CI: dev pull requests use a placeholder check (full gates run locally); builds and releases only
  after 6–10 merges, on main.

## [0.0.8-alpha] - 2026-11-23

Statistics (M8), ×10 mark and menu.

### Added
- SD mode: DT data entry with frequencies (`;`), DT DT repeat, CL, Scl; S-SUM (Σx², Σx, n) and
  S-VAR (x̄, xσn, xσn−1); ▲▼ data screens with edit / add / delete; Data Full (EditOFF / ESC).
- REG mode: Lin, Log, Exp, Pwr, Inv, Quad regression; Σy², Σy, Σxy, Σx³, Σx²y, Σx⁴, ȳ, yσn,
  yσn−1, A, B, C, r, x̂, ŷ, x̂1, x̂2 usable in expressions.
- Normal distribution (SD): P(, Q(, R(, ▶t.
- Result line: printed ×10 between mantissa and exponent.
- W-Calc menu (tap the name): Settings, Theme, User guide, Keyboard shortcuts, About (coming soon).

## [0.0.7-alpha] - 2026-11-23

Complex numbers (M7).

### Added
- CMPLX mode (MODE 2): `i` (ENG key), polar input r∠θ (SHIFT (−)), Abs, arg, Conjg.
- Re⇔Im (SHIFT =) between real/imaginary parts or r/θ, with R⇔I, i, ∠ indicators.
- a+bi / r∠θ format (Disp page in CMPLX) and ▶r∠θ / ▶a+bi commands.
- Complex values in Ans, variables, history and saved state; mode is remembered.

## [0.0.6-alpha] - 2026-11-22

Equations and calculus (M6).

### Added
- Pol( / Rec( with results in E and F.
- 40 scientific constants (CONST) and 40 metric conversions (CONV).
- Integration ∫( f, a, b[, n] ) by Simpson's rule and differentiation d/dx( f, a[, Δx] ).
- CALC: prompts for each variable, Y = … assignment, repeat with new values.
- SOLVE: Newton's method from a chosen start value, ▲▼ between variables, Can't Solve.

### Changed
- Working precision 24 digits (still exact against all reference values), about 2× faster.

## [0.0.5-alpha] - 2026-11-22

Fractions, sexagesimal, percent and engineering notation (M5).

### Added
- Exact fractions: a b/c input, mixed/improper results (`4⌟11⌟12.`), a b/c ↔ decimal and
  d/c ↔ mixed conversion, decimal-to-fraction conversion, fractions stay exact through Ans.
- Sexagesimal input with °′″ (`2°0°30°`), sexagesimal results, decimal ↔ d°m°s conversion.
- Percent (SHIFT =): of, ratio, rate of change, mark-up / discount with + / −.
- ENG and SHIFT ENG engineering shifts; EngON engineering symbols (f p n μ m k M G T) for input
  and results.
- Disp setup screens: EngON/EngOFF, ab/c / d/c, Dot / Comma (comma decimal display).

## [0.0.4-alpha] - 2026-11-22

Memories and history (M4).

### Added
- Variables A–F, M, X, Y: STO (SHIFT RCL), RCL, ALPHA names in expressions with implied ×.
- Independent memory: M+, M− with the M indicator.
- Calculation history (~150 bytes): ▲ ▼ with indicators, edit any entry, COPY (SHIFT ▲) into a
  multi-statement.
- Multi-statements with `:` (ALPHA ∫dx): `=` steps through, Disp indicator.
- CLR (SHIFT MODE): Mcl / Mode / All with confirmation; ON clears history.
- Memories, Ans and setup persist across app restarts.

### Changed
- Key legends grouped tightly per key; MODE after the last setup page returns to calculation.
- Key presses vibrate (Android haptics; Vibration API on web).

## [0.0.3-alpha] - 2026-11-22

Scientific functions (M3) and device-accurate keypad legends.

### Added
- Functions computed with 24 working digits and rounded to 15: sin cos tan and inverses
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
