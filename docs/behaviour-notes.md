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
| 14 | Minus sign position | sits in the digit cell immediately left of the number (not fixed at far left) | any negative result | to verify |
| 15 | Exponent display | small 2-digit exponent at top right of result line, own small minus | `1 ÷ 200 =` | to verify |
| 16 | Cursor | blinks every 0.5 s; overwrite = underline under character, INS = box around character | | to verify |
| 17 | 3-digit separators | result line groups the integer part with comma tails (`1,234,567.25`), per the 2nd-ed. manual's *Dot* setting ("period decimal point, comma separator"); not applied to exponential results | `1234567 =` | to verify on your edition |
| 18 | MAT / VCT legend brackets | neutral grey corner brackets (colour not documented) | look at keys 4 / 5 | to verify |
| 19 | Rad: sin π, cos(π/2) | arguments within 1e-13 (relative) of a non-zero multiple of π/2 snap to it → `sin π = 0`, `tan(π/2)` = Math ERROR | Rad: `sin SHIFT EXP =` | to verify |
| 20 | Rnd after a result | rounds Ans (`10 ÷ 3 = SHIFT 0 × 3 =` → `9.999` in Fix 3), shown as `Rnd Ans` | as described | to verify display text |
| 21 | hyp | shows a `hyp` indicator until the next key; hyp + non-trig key drops hyp | press hyp | to verify |
| 22 | Function texts | `sin⁻¹ ` (with `⁻¹` as 2 columns), `10^`, `e^`, `³√`, `ˣ√`, `Ran#`, `Rnd ` | type them, compare widths | to verify |
| 23 | MODE menus | 6 pages (COMP CMPLX / SD REG BASE / EQN MAT VCT / Deg Rad Gra / Fix Sci Norm / Disp), MODE after the last page returns to calculation (confirmed by owner); selecting a setting returns to the expression being edited | MODE repeatedly | to verify |
| 24 | Changing Fix/Sci/Norm | a result already on screen is re-shown in the new format | `100 ÷ 7 =` then Fix 3 | to verify |
| 25 | RCL display | upper shows `A=`, result line the value; Ans unchanged; an operator after RCL continues from the variable (`RCL A +` → `A+`) | `RCL (−)` then `+` | to verify |
| 26 | STO display | expression stays on the upper line, value on the result line; Ans updated | `3 + 5 SHIFT RCL (−)` | to verify |
| 27 | CLR | `Mcl Mode All` / `1 2 3`, then a confirm screen (`Mcl` / `Mode` / `All`) executed with `=`, cancelled with AC; afterwards screen shows `0.` | `SHIFT MODE 1` | to verify confirm-screen text |
| 28 | History size | ~150 bytes ≈ (steps + 7) per calculation, oldest dropped first | many calculations, count ▲ steps | to verify |
| 29 | ▲ after AC | shows the newest history entry | `1 + 1 = AC ▲` | to verify |
| 30 | ON | clears screen and history, keeps memories, Ans and setup | `ON` | to verify |
| 31 | Memory persistence | variables, M, Ans and setup survive closing the app (device keeps them while off) | close and reopen app | — |
