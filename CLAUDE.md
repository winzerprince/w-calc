# W-Calc — working agreement

Clean-room Flutter app that behaves like the user's physical two-line MS-series scientific calculator
(reference model fx-991MS). Plan: `docs/PLAN.md`. CI rules: `docs/CI_CD.md`.

## Ground truth & legal (non-negotiable)
- The user's physical unit (photos in `docs/downloads/`, older edition with `EXP` key) beats the manual.
  Record every manual-vs-device difference in `docs/behaviour-notes.md`.
- `docs/downloads/` is private and gitignored: never commit, quote or bundle it. Write our own help text.
- Never use CASIO firmware/ROM, logos, or trademarks ("CASIO", "fx-", "991", "V.P.A.M.") in code, assets,
  names, package ids or store text. Only allowed mention: one factual compatibility line + disclaimer in the store listing/About.
- License: MIT, open source, public repo (LICENSE). Don't mention earlier licences in public text. Only add permissive dependencies/assets (MIT, BSD, Apache-2.0, OFL) so
  the app stays MIT; never GPL/LGPL/AGPL code.
- Distribution: itch.io first (web build + Android APK). Everything for the store page
  (descriptions, screenshots, disclaimers, roadmap) lives in `docs/downloads/release-kit/` (private).
- Donations: Ko-fi link in Settings ▸ Support and About (`lib/app/links.dart`). List every third-party component in THIRD_PARTY_NOTICES.md.

## Layout
- `packages/wcalc_engine/` — pure Dart, no Flutter imports. All calculator behaviour lives here.
- `lib/` — Flutter UI only (LCD painter, keypad, persistence). No maths in the UI.
- `test/` — widget tests. Engine tests in `packages/wcalc_engine/test/`.
- `docs/spec/` — our own behaviour spec per feature; `docs/behaviour-notes.md` — device quirks.

## Workflow
- Branch from `dev`: `feature/<milestone>-<topic>`, `fix/…`, `chore/…`, `docs/…`. PR into `dev` (squash).
  Release = PR `dev` → `main` (merge commit) after bumping `pubspec.yaml` version + `CHANGELOG.md`.
- Conventional Commits (`feat(engine): …`, `fix(ui): …`, `ci: …`, `docs: …`, `test: …`).
- TDD: write failing engine test first (from manual example or device vector), then code. Engine coverage ≥ 90 % (enforced on PR → main).
- Test vectors from the user: `keys | expected display | mode/setup` → add verbatim as golden tests.
- Before every PR: `dart format lib test packages`, analyze, engine + widget tests all green locally.
  Judge analyze/format by exit code, never through a pipe (`cmd | tail` hides failures; it let an
  unformatted file reach CI once). Use `set -o pipefail` or run the command bare.
- CI builds Android only, and only on `main`. Website https://w-calc.0xwinzer.com is Cloudflare Pages,
  deployed from a local build with `tool/deploy_web.sh` after each release. No ads anywhere
  (decided 2026-11-24; Ko-fi instead). `tool/web.sh` for local testing.
- PRs into dev only get a placeholder CI check: the local gates (format, both analyzers, engine + app
  tests) are mandatory before every PR. Release dev → main only after 6–10 significant merges.
- Product vision: after the fx-991MS-style model is complete, add more calculator models (looks of
  classics used in Africa, India, Asia, America) reusing the engine through shared interfaces; users
  pick the one they know.
- Number type: own decimal, never `double`, for anything that reaches the display.

## Communication preferences
- Work autonomously; merge own PRs when checks are green.
- Only interrupt the user for: ambiguity that changes behaviour, critical failures, legal/security issues,
  or things needing their accounts/money (Play Console, secrets).
- Alert the user to test after significant milestones (e.g. first full UI look, a mode working end to end),
  with exact steps: what to open, which keys to press, what to compare against the device.
- Terse status updates.
