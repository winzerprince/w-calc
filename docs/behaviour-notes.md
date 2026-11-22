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
| 32 | Fraction input | `a┘b` / `a┘b┘c` is part of the number (integers only); so `2^3┘4` = 2^(3/4). Device priority table puts fractions below powers, which would give (2³)/4 | `2 ^ 3 a b/c 4 =` | to verify |
| 33 | % rule | splits at the last top-level + − × ÷ before `%` (`A op B %`); `B %` alone = B/100 | `1 + 2 × 3 SHIFT =` | to verify |
| 34 | % then + / − | only after `A × B %`: `+` → A + A·B/100, `−` → A − A·B/100; upper line shows `A×B%+` | `2500 × 15 SHIFT = +` | to verify display |
| 35 | Sexagesimal result | `d°m°s` using a `°` cell between parts; seconds get the decimals left of 10 digits; minutes/seconds not zero-padded | `12°34°56° × 3.45 =` → `43°24°31.2` | to verify |
| 36 | °′″ after a decimal result | does nothing (SHIFT °′″ converts to sexagesimal); after a sexagesimal result converts to decimal | `2.258 = °′″` | to verify |
| 37 | EngON display | symbol drawn small in the exponent area; `5` stays `5.`; values outside f…T use normal exponent display | `9 ÷ 10 =` | to verify |
| 38 | Disp screen | shows `Disp` only (contrast `◀CONT▶` not emulated) | MODE ×6 | — |
| 39 | Constant values | CODATA 2010 (2nd-ed. manual); older editions may use older CODATA values | `CONST 06 =` (h) → `6.62606957`⁻³⁴ ? | to verify on your edition |
| 40 | CONST/CONV prompt | `CONST--` / `CONV--`, digits fill in; first digit 0-4 only; numbers outside 01-40 ignored | `CONST 2 8` | to verify |
| 41 | Conversion factors | NIST SP 811 (hp = 745.6999 W, calorie at 15 °C = 4.1855 J, pc = 3.085678e16 m, mmHg = 133.3224 Pa) | `1 CONV 29 =` | to verify |
| 42 | ∫ partitions omitted | Simpson with N = 2, 4, … doubling until two results agree to 1e-12 (max 2⁹) | `∫dx sin X , 0 , π )` (Rad) | to verify speed/result |
| 43 | d/dx Δx omitted | central difference with Richardson step, h = 10⁻³·max(1,|a|) | `d/dx X³ , 2 )` | — |
| 44 | ∫( / d/dx( text | shown as `∫(` and `d/dx(` | press ∫dx | to verify |
