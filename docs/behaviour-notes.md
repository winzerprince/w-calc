# Behaviour notes (device vs manual)

Ground truth = the owner's physical unit (older edition, `EXP` key). Each entry: what we assumed,
how to verify on the device, result.

| # | Topic | Assumption in code | Verify on device | Status |
|---|---|---|---|---|
| 1 | Norm result width | 10 digit positions in total (`2÷3` → `0.666666667`, `1÷81` → `0.012345679`) | `2 ÷ 3 =`, `1 ÷ 81 =` | to verify |
| 2 | Exponential mantissa | integer mantissa keeps trailing point (`1÷200` → `5.` `-03`) | `1 ÷ 200 =` | to verify |
| 3 | Fix with large numbers | if rounded value ≥ 1e10 → exponential, 10 significant digits | Fix 3, `123456789 × 100 =` | to verify |
| 4 | Rounding | half away from zero at every internal step (15 digits) and at display (10 digits) | `2 ÷ 3 × 3 =` → `2.`; `1 ÷ 3 × 3 =` → `1.` | to verify |
