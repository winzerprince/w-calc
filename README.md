# W-Calc

An offline scientific-calculator app for students: ten calculators that look and work like the
ones used in class, with exact answers, graphs and a built-in manual. Android first; web for local
testing.

> Independent product, not affiliated with or endorsed by any calculator manufacturer. All
> calculation code is original.

## What it does
- **Ten models in three display families** — two-line (Scientific Plus, Grid, Basic), textbook
  display (Textbook Plus, Plus II, Basic, Scientific Max) and multi-line (Scientific Two-View,
  View, Write). Each has its own keypad, display, modes and theme.
- **Every mode** — COMP, CMPLX, STAT/SD/REG, BASE-N, EQN (up to 4 unknowns), MATRIX (up to 4×4),
  VECTOR, TABLE, CALC/SOLVE, ∫, d/dx, Σ, 40 constants, 40 conversions.
- **Exact results** on textbook models: fractions, √ forms and π forms with S⇔D.
- **Graphs** — functions, equations and statistics data; trace, roots, extrema, intersections,
  tables.
- **Manual** — searchable, filtered to the model in use; every example is replayed by a test.
- **Look and feel** — 11 themes, 8 key finishes, focus (full-screen) mode, first-start tours,
  long-press key hints, key vibration.
- **Private** — no network, no data collected ([`docs/PRIVACY.md`](docs/PRIVACY.md)).

## Status
Beta (v0.9.x). Plan: [`docs/PLAN.md`](docs/PLAN.md) · changes: [`CHANGELOG.md`](CHANGELOG.md) ·
device questions: [`docs/behaviour-notes.md`](docs/behaviour-notes.md) · known issues:
[`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md).

## Layout
- `packages/wcalc_engine/` — pure Dart engine: decimal arithmetic, evaluator, two-line and
  textbook calculators, dot-matrix rendering, graph maths. No Flutter.
- `lib/` — Flutter UI: LCDs, keypads, models, themes, manual, graph, tours.
- `docs/spec/` — our own behaviour specs.

## Develop
```bash
flutter pub get
tool/gate.sh            # format, analyze, engine + widget tests (run before every PR)
tool/web.sh             # run in a browser (LAN-accessible); `tool/web.sh release` for a release build
```
Android builds run only in CI on `main`. Workflow and CI rules: [`docs/CI_CD.md`](docs/CI_CD.md).

## License
Proprietary — all rights reserved. See [`LICENSE`](LICENSE). Releases up to v0.4.0-beta were
GPL-3.0-or-later. Third-party components: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
