# Contributing to W-Calc

Thank you for helping! W-Calc is actively developed, and reports from people who use it are the
fastest way to make it better.

More detail: [docs/contributing/](docs/contributing/README.md) (setup, project map, ways to help).

## Report a bug
Open an issue with the **Bug report** form: https://github.com/winzerprince/w-calc/issues/new/choose

The most useful report is: model, the exact keys you pressed, what you expected (or what your
physical calculator shows) and what W-Calc showed — a screenshot if you can.

## Suggest an idea
Use the **Idea or request** form. New calculator models you know from class are especially welcome.

## Contribute code
1. Fork, then branch from `dev` (`fix/…`, `feature/…`).
2. Calculator behaviour lives in `packages/wcalc_engine/` (pure Dart). Add a failing test first,
   then the fix. The Flutter UI is in `lib/`.
3. Run `tool/gate.sh` (format, analyze, all tests) before opening a pull request into `dev`.
4. Use Conventional Commit titles (`fix(engine): …`, `feat(ui): …`).

Please don't add manufacturer logos, firmware, manual text or trademarks, and only add
dependencies under permissive licences (MIT, BSD, Apache-2.0, OFL). By contributing you agree that
your contribution is released under the project's MIT licence.
