# wcalc_engine

Pure-Dart "calculator brain" for W-Calc. No Flutter imports, so it runs in plain
`dart test`, on the web and on Android unchanged.

- `CalcKey` — every physical key on the keypad.
- `Calculator` — key-driven state machine: `press(key)` updates `display`.
- `DisplayState` — what the two-line LCD shows (upper dot-matrix line, lower result line, indicators).

Run tests: `dart test` (from this folder).
