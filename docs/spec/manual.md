# In-app manual

Data lives in `lib/manual/` (original W-Calc text; never copy manual wording).

- `manual_model.dart`: chapters → articles → blocks (`Para`, `Steps`/`ManualStep`, `Example`,
  `Tip`), audiences (`all`, `twoLine`, `textbook`), mode requirements, ranked search.
- `manual_content.dart`: the content. One article = one task or concept.

Rules
- Tag every article with its `audience`; tag examples whose keys differ per family with `only`.
- Two-line articles that need a mode list it in `requires` (hidden on models without it).
- Write key sequences with `parseKeySequence` names (`SHIFT`, `frac`, `S<>D`, `>`, `X` …). The UI
  draws them as keycaps using the current model's labels.
- Give examples a `verify` string: `test/manual_examples_test.dart` replays them on the real engine
  (two-line: copied result text; textbook: structured result text such as `fraction{7|6}`).
- When a textbook mode is implemented, add its article and remove it from "Other modes".
