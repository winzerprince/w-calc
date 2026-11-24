# Project map

W-Calc has two halves: a pure Dart **engine** that does every calculation, and a Flutter **UI**
that draws the calculator and sends key presses to the engine. The UI never does maths.

```
key press ─▶ lib/ui (keypad) ─▶ engine: Calculator.press(key) ─▶ display state ─▶ lib/ui (LCD painter)
```

## Engine: `packages/wcalc_engine/` (no Flutter imports)
| Folder in `lib/src/` | What it does |
|---|---|
| `calculator.dart`, `calc_engine.dart` | Key handling, modes, memories |
| `input/`, `key_sequence.dart` | Typing, cursor, editing |
| `eval/` | Parsing and evaluating expressions |
| `number/` | Our own decimal number type (never `double` for anything shown) |
| `format/` | Turning numbers into display text (Fix/Sci/Norm, fractions, √ and π forms) |
| `natural/` | Textbook display (fractions and roots as written) |
| `lcd/`, `display_state.dart` | What the screen shows |
| `stats/`, `eqn/` | Statistics/regression, equation solvers |
| `graph/` | Graph expressions and evaluation |
| `features.dart` | Which model has which features |

Tests mirror this in `packages/wcalc_engine/test/`.

## App: `lib/`
| Folder | What it does |
|---|---|
| `app/` | Settings, models list, history, links |
| `ui/` | Calculator screen, keypad, LCD, themes, finishes, graph screen (`ui/graph/`), pages, tours |
| `manual/` | The built-in manual text |

Widget tests are in `test/`.

## Docs
- `docs/spec/`: our own description of how features behave. Update it when behaviour changes.
- `docs/behaviour-notes.md`: quirks found on real calculators.
- `tool/`: scripts (`gate.sh`, `web.sh`, icon and test-vector generators).

## Ground rules
- Behaviour follows real classroom calculators; a real device beats any manual.
- Clean-room only: no manufacturer firmware, logos, artwork, manual text or trademarks.
- Dependencies and assets must be MIT, BSD, Apache-2.0 or OFL licensed.
