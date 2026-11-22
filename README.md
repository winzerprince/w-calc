# W-Calc

A fast, lightweight, offline two-line scientific calculator for students, keystroke-compatible with
classic MS-series scientific calculators. Android first; web for local testing.

> Not affiliated with or endorsed by any calculator manufacturer. All calculation code is original.

## Status
Pre-alpha. See [`docs/PLAN.md`](docs/PLAN.md) for milestones and [`CHANGELOG.md`](CHANGELOG.md).

## Develop
```bash
flutter pub get
(cd packages/wcalc_engine && dart pub get && dart test)   # engine tests
flutter test                                               # widget tests
tool/web.sh                                                # run in browser (LAN-accessible)
```
Workflow and CI rules: [`docs/CI_CD.md`](docs/CI_CD.md).

## License
GPL-3.0-or-later. See [`LICENSE`](LICENSE).
