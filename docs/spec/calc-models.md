# Calculator models

One engine, several calculators. A model is data, not a fork of the engine.

| Layer | Type | Holds |
|---|---|---|
| Engine | `CalcFeatures` (`packages/wcalc_engine/lib/src/features.dart`) | Allowed modes, CONST/CONV, ∫dx/d/dx, CALC/SOLVE, ENG symbols |
| App | `CalcModel` (`lib/app/calc_model.dart`) | Name, description, features, hidden legends |
| UI | `ModelScope` | Active model; keypad hides legends and fades inert keys |

Rules
- MODE pages are generated from `features.modes`; menu digits renumber accordingly.
- A gated key press does nothing (no error), like a key absent from a cheaper unit.
- Switching model moves the saved state to a new `Calculator(features:)`; a mode the
  new model lacks falls back to COMP.
- Adding a model: define `CalcFeatures` + `CalcModel` entry in `CalcModel.all`; optional
  own skin. Later models may bring their own `KeySpec` layout through the same scope.

Models today: `plus` (reference two-line model, full), `basic` (COMP/SD/REG).
