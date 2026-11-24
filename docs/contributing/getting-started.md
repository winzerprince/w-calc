# Getting started

## You need
- Flutter **3.47.9** (stable), which includes Dart. Check with `flutter --version`.
- Git and a GitHub account.
- Optional: an Android phone or emulator. The web build is enough for most work.

## Run it
```bash
git clone https://github.com/<you>/w-calc.git   # your fork
cd w-calc
git switch dev                                     # all work is based on dev
flutter pub get
tool/web.sh                                        # opens in the browser, hot reload with r
```
`tool/web.sh` also prints an address you can open on a phone on the same Wi-Fi.
On a connected Android device: `flutter run`.

## Check your work
```bash
tool/gate.sh
```
This runs formatting, both analyzers, the engine tests and the app tests. It must print
`gate: OK` before you open a pull request. Fix formatting with `dart format lib test packages tool`.

Only the engine? `cd packages/wcalc_engine && dart test` is faster.

## Open a pull request
1. Branch from `dev`: `fix/<topic>`, `feature/<topic>` or `docs/<topic>`.
2. Commit with a Conventional Commit title: `fix(engine): …`, `feat(ui): …`, `docs: …`, `test: …`.
3. Open the pull request **into `dev`**, not `main`. Fill in the template.
