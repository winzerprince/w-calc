# W-Calc — Project Plan (development → production)

Goal: a fast, lightweight, offline, accurate phone app that behaves like a classic two-line
"MS-series" scientific calculator (reference model: CASIO fx-991MS), so students can practise
on their phones with the same keystrokes, menus, display behaviour and results as the physical unit.

Status: v0.9.0-beta — feature-complete beta: nine models, graphs, manual, themes/finishes, tours, key hints, launch screen, adaptive icon, privacy policy, fuzz-tested. Next: device verification of behaviour notes, Play listing assets, v1.0.0. Last updated 2026-11-23.

---

## 1. Source material

| File | What it is | Rules |
|---|---|---|
| `docs/downloads/fx-100MS_570MS_991MS_EN.pdf` | Official CASIO user's guide (2nd ed., S-V.P.A.M., © 2018) | Private reference. Gitignored. Never commit, bundle or quote in the app. |
| `docs/downloads/fx-100MS_570MS_991MS_EN.md` | Markdown conversion (key icons → `[KEY]`, LCD figures as images) | Same as above. Spec for behaviour only. |
| `docs/downloads/front.jpeg`, `back.jpeg` | Photos of the owner's physical fx-991MS | Private reference. Physical unit = **ground truth** for testing. |

Note: the physical unit has an `EXP` key, the 2nd-edition manual shows `×10ˣ`. Editions may differ
in small details (e.g. constant values, CODATA 2010 in 2nd ed.). When manual and device disagree,
**the device wins**; record the difference in `docs/behaviour-notes.md`.

---

## 2. Legal: what we may and may not do

Not legal advice. Before public launch, a short consult with an IP lawyer is cheap insurance.

### Allowed (low risk)
- **Reproduce functionality.** Maths, operator precedence, menus-as-behaviour, keystroke sequences,
  error conditions, display formats are ideas/methods, not copyrightable expression
  (US 17 U.S.C. §102(b); EU Software Directive Art. 1(2), *SAS Institute v World Programming*).
- **Clean-room engine.** Write our own code from observed behaviour (device + manual as a spec).
- **Public-domain data.** CODATA constants and NIST SP 811 conversion factors are facts, free to use.
- **Functional layout.** Two-line display, 5-column keypad, shift/alpha colour-coded secondary labels,
  similar key positions — these serve function and muscle memory.
- **Factual compatibility statement** in the store description, e.g.
  *"Keystroke-compatible with popular two-line scientific calculators such as the fx-991MS.
  Not affiliated with or endorsed by CASIO."* (nominative use; keep it to one plain-text mention).

### Not allowed (high risk)
- **ROM / firmware.** Never dump, download, or ship CASIO firmware. ROM-based emulators are what
  gets taken down. Our engine is 100% our own code.
- **Trademarks in branding.** No "CASIO", "fx-991", "fx-", "MS", "S-V.P.A.M.", "Natural V.P.A.M.",
  "ClassWiz" in app name, icon, package id, screenshots, or keywords field.
- **Logos and trade dress copies.** No CASIO logo, no pixel-copied faceplate, no photos/scans of the
  real calculator or manual figures in the app or store listing.
- **Manual text.** Don't copy manual wording into in-app help; write our own.
- **Claims.** Don't claim "official", "approved for exams", or identical results guaranteed.

### How we navigate it
1. Own name + own icon + own artwork (drawn from scratch, vector).
2. "Classic" theme: same layout and colour *semantics* (shift = yellow/orange text, alpha = red),
   but our own palette, shapes, fonts (OFL-licensed or our own dot-matrix font).
3. Engine spec is written by us in `docs/spec/` from the manual + device tests; code never references
   manual text.
4. Disclaimer in About screen and store listing.
5. Trademark search on chosen name: USPTO, EUIPO, WIPO Global Brand Database, plus a Play Store search.
6. Keep the converted manual gitignored (already: `**/downloads/`). The PDF carries a
   "no copy" permission flag; our conversion is for private engineering reference only.

---

## 3. Technology choice

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Flutter (Dart)** | One codebase: Android, iOS, web, desktop. Own renderer → pixel-exact custom LCD & keypad. Hot reload for fast iteration. Pure-Dart engine runs in unit tests and web. | ~6–9 MB Android download (per-ABI split). | **Recommended** |
| Kotlin Multiplatform + Compose MP | Native feel, small Android size | iOS/web Compose less mature; slower iteration for a custom-drawn UI | Good #2 |
| React Native / Expo | Big ecosystem | JS doubles for numbers, bridge overhead, custom drawing awkward | No |
| Native Kotlin + Swift | Smallest, fastest | Two UIs, double work | No (solo project) |
| PWA only | Zero install, free hosting | iOS limits, no store presence, schools may block | Ship as bonus target from Flutter web |

### Architecture

```
w-calc/
  packages/wcalc_engine/ pure Dart, no Flutter import — the "calculator brain"
    decimal/            own decimal float: 15-digit mantissa, exp ±99 (internally 18–20 digits, round to 15)
    keys/               key codes, SHIFT/ALPHA/hyp/STO/RCL state machine
    input/              token buffer (79 steps, ■ cursor at 73), insert/overwrite, replay
    parser/             CASIO priority table (13 levels, Type A/B functions, implied ×)
    eval/               numeric + command stacks (10 / 24) → Stack ERROR parity
    functions/          trig/hyp/log/exp/roots/!/nPr/nCr/Pol/Rec/Rnd/Ran#, ∫ (Simpson), d/dx
    format/             Norm1/2, Fix, Sci, Eng, ENG symbols, a b/c & d/c, sexagesimal, Dot/Comma
    modes/              COMP CMPLX SD REG BASE EQN MAT VCT, CALC, SOLVE (Newton), DISTR
    data/               40 constants, 40 conversions
  app/                  Flutter UI
    lcd/                CustomPainter: dot-matrix top line + 7-segment result line + indicators
    keypad/             vector keys, haptics, long-press help, landscape layout
    persistence/        memories/variables/settings survive app restart (like the real unit)
```

Why our own decimal type: the real unit computes in decimal (15 digits). Binary `double` gives
wrong-looking answers (`0.1+0.2`, `1/3*3`, `sin 180°`). Matching CASIO rounding is the core of "accurate".

Footprint targets: cold start < 400 ms, key → display < 16 ms, APK < 10 MB, no permissions,
no network, no ads, no tracking.

---

## 4. Development process

### Iteration loop (you test as I build)
1. I implement one milestone on a branch, with tests.
2. CI builds an APK + web preview automatically.
3. You install the APK (or open the web link) on your phone, compare against the real fx-991MS.
4. You report mismatches as **test vectors**: `keys | expected display | mode/setup`.
   Example: `[SHIFT][sin] 0.5 [=] | 30. | COMP, Deg`
5. I add each vector to the golden test suite → fix → it can never regress.

Golden tests come from three sources: every manual example, your device recordings,
and randomized cross-checks against a high-precision reference (e.g. Python `mpmath`) for function accuracy.

### Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Repo scaffold, Flutter app + `engine` package, CI green, lint, license | APK builds in CI |
| M1 | Decimal type + arithmetic + Norm display + errors | Manual pp.17–19 examples pass |
| M2 | LCD + keypad UI, SHIFT/ALPHA, cursor/DEL/INS, AC/ON | Usable basic calculator on phone |
| M3 | COMP functions: trig/hyp/log/power/roots/!/nPr/nCr/Ran#/Rnd/DRG | pp.31–38 pass |
| M4 | Memories: Ans, A–F/M/X/Y, M+/M−, STO/RCL, replay/history/COPY, multi-statement | pp.27–30 pass |
| M5 | Setup menus: Fix/Sci/Norm, Eng ON/OFF, fractions, sexagesimal, %, ENG, Dot/Comma | pp.13–27 pass |
| M6 | CALC, SOLVE, ∫dx, d/dx, Pol/Rec, constants, conversions | pp.35–45 pass |
| M7 | CMPLX | pp.46–47 pass |
| M8 | SD, REG (Lin/Log/Exp/Pwr/Inv/Quad), DISTR P/Q/R/t | pp.47–56 pass |
| M9 | BASE-N + logic ops | pp.56–59 pass |
| M10 | EQN (quadratic, cubic, 2–3 unknowns) | pp.59–62 pass |
| M11 | MAT, VCT | pp.63–69 pass |
| M12 | Polish: themes, haptics, a11y (TalkBack/VoiceOver), landscape, tablet, About/disclaimer | Beta-ready |
| M13 | Store release | Live on Play + web |

Early testable build target: end of M2.

### Branching & quality gates
- `main` always releasable; feature branches + PRs; Conventional Commits.
- PR gate: `dart format --set-exit-if-changed`, `flutter analyze`, engine tests (≥90% coverage on engine),
  widget golden tests for LCD rendering.

---

## 5. CI/CD (GitHub Actions)

Authoritative rules: [`CI_CD.md`](CI_CD.md). Summary: PR → `dev` runs fast checks only; PR → `main`
runs the full gate; builds (Android APK/AAB, signed) and releases happen only after merge to `main`.
Web is never built in CI — test it locally with `tool/web.sh`.

---

## 6. Publishing

| Channel | Cost | Notes |
|---|---|---|
| **Google Play** | $25 one-time | New personal developer accounts must run a closed test (currently 12 testers × 14 days — verify current rule) before production. Needs privacy policy URL + Data Safety form ("no data collected"). Target latest required API level. Avoid "Designed for Families" unless we comply; set audience 13+. |
| **Web / PWA** | free | Local testing only for now (`tool/web.sh`). Public hosting decided later. |
| **F-Droid** | free | Requires fully open-source build, no proprietary deps. Good fit for students. |
| Apple App Store | $99/yr | Later; needs Mac or CI macOS + review. |
| Others (later) | free | Samsung Galaxy Store, Huawei AppGallery, Amazon, Microsoft Store, Flathub. |

Store listing: own screenshots of our app, no CASIO marks except the single compatibility line + disclaimer.
Keywords: "scientific calculator", "engineering calculator", "student calculator", "statistics", "equation solver".

Reminder for users: phones are not allowed in exams — position the app as a **practice/learning** tool.

---

## 7. Naming

Rules: no CASIO marks, no "fx-", no "991"; short; searchable; free trademark + domain + Play title.

| Candidate | Comment |
|---|---|
| **W-Calc — Scientific Calculator** | Keeps repo name; generic subtitle carries search keywords. Recommended default. |
| Twoline Sci | Describes the two-line display |
| Dotline Calc | Nod to the dot-matrix LCD |
| SciPad Classic | Clear, friendly |
| Keystroke Scientific | Emphasises keystroke compatibility |

Store title pattern: `<Brand> – Scientific Calculator`.

---

## 8. Decisions (2026-11-22)

- Name: **W-Calc** (store title "W-Calc – Scientific Calculator"), app id `io.github.winzerprince.wcalc`
- License: proprietary, all rights reserved (from 2026-11-23; v0.0.1–v0.4.0 were GPL-3.0)
- Platforms: Android first (CI-built); web local only; iOS later
- Free, no ads, no tracking
- Reference: user's physical unit (from photos/device tests) over the manual
- Branching: work on `dev` (default), features → `dev`, `dev` → `main` releases; first release `v0.0.1-alpha`
