# W-Calc — working agreement

Clean-room Flutter app that behaves like the user's physical two-line MS-series scientific calculator
(reference model fx-991MS). Plan: `docs/PLAN.md`. CI rules: `docs/CI_CD.md`.

## Ground truth & legal (non-negotiable)
- The user's physical unit (photos in `docs/downloads/`, older edition with `EXP` key) beats the manual.
  Record every manual-vs-device difference in `docs/behaviour-notes.md`.
- `docs/downloads/` is private and gitignored: never commit, quote or bundle it. Write our own help text.
- Never use CASIO firmware/ROM, logos, or trademarks ("CASIO", "fx-", "991", "V.P.A.M.") in code, assets,
  names, package ids or store text. Only allowed mention: one factual compatibility line + disclaimer in the store listing/About.
- License GPL-3.0.

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
- CI builds Android only, and only on `main`. Web is local only (`tool/web.sh`).
- Number type: own decimal, never `double`, for anything that reaches the display.

## Communication preferences
- Work autonomously; merge own PRs when checks are green.
- Only interrupt the user for: ambiguity that changes behaviour, critical failures, legal/security issues,
  or things needing their accounts/money (Play Console, secrets).
- Alert the user to test after significant milestones (e.g. first full UI look, a mode working end to end),
  with exact steps: what to open, which keys to press, what to compare against the device.
- Terse status updates.
