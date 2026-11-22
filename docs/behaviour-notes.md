# Behaviour notes (device vs manual)

Ground truth = the owner's physical unit (older edition, `EXP` key). Each entry: what we assumed,
how to verify on the device, result.

| # | Topic | Assumption in code | Verify on device | Status |
|---|---|---|---|---|
| 1 | Norm result width | 10 digit positions in total (`2÷3` → `0.666666667`, `1÷81` → `0.012345679`) | `2 ÷ 3 =`, `1 ÷ 81 =` | to verify |
| 2 | Exponential mantissa | integer mantissa keeps trailing point (`1÷200` → `5.` `-03`) | `1 ÷ 200 =` | to verify |
| 3 | Fix with large numbers | if rounded value ≥ 1e10 → exponential, 10 significant digits | Fix 3, `123456789 × 100 =` | to verify |
| 4 | Rounding | half away from zero at every internal step (15 digits) and at display (10 digits) | `2 ÷ 3 × 3 =` → `2.`; `1 ÷ 3 × 3 =` → `1.` | to verify |
| 5 | Implied × before `(` | binds tighter than × ÷ (`6 ÷ 2(1+2)` → `1.`) | `6 ÷ 2 ( 1 + 2 =` | to verify |
| 6 | Lower line while typing | keeps showing previous result until `=` | `7 = 1 +` → lower still `7.`? | to verify |
| 7 | Error screen | message on upper line, lower line blank; ◀/▶ returns with cursor at error, AC clears | `1 ÷ 0 =` then `◀` | to verify |
| 8 | `^` key text | shows `^` (no automatic `(`), left-to-right with equal priority | `2 ^ 3 ^ 2 =` → `64.`? | to verify |
| 9 | `EXP` as first key | means `1E…` (`EXP 3 =` → `1000.`) | `EXP 3 =` | to verify |
| 10 | Upper line scrolling | 12 columns; cursor occupies a column, so a long line at the end shows 11 chars + `_` | type 15 digits | to verify |
| 11 | `=` after a result | re-evaluates the same expression with the new Ans (`2 = × 3 = =` → `18.`) | `2 = × 3 = =` | to verify |
| 12 | Number right after `)` | Syntax ERROR (`(2)3`) | `( 2 ) 3 =` | to verify |
| 13 | DEL at end of line | deletes last token; in INS mode deletes token left of cursor | | to verify |
