# Textbook-display models (spec)

Our own description of the second calculator family (silver 1st edition,
black 2nd edition). Both editions share behaviour; they differ in body, key colours and the cursor
pad (round disc vs four separate arrow keys). Sources: official online manual (2nd edition) and the
printed user guide, both read privately; nothing here is copied from them.

## Display
- Full dot-matrix area 96 × 31 dots plus a fixed indicator row above it
  (S, A, M, STO, RCL, STAT, CMPLX, MAT, VCT, D/R/G, FIX, SCI, Math, ▲▼, Disp).
- Text font 5 × 7 dots on a 6-dot pitch → 16 characters per line, 4 text lines on menus.
- **MathIO (Natural)**: input drawn as in a textbook — stacked fractions, √ with a bar,
  superscript powers, log with subscript base, ∫ / Σ with limits, |abs|. Input may be up to two
  screens tall (62 dots); the view scrolls with the cursor.
  Results are right-aligned at the bottom: exact forms (fraction, a√b/c, π form) when possible.
- **LineIO (Linear)**: one input line like the two-line models; fractions shown as `7⌟6`.
- STAT, BASE-N, MATRIX and VECTOR always use Linear display.
- Error screen: three lines — `<Kind> ERROR`, `[AC]  :Cancel`, `[◀][▶]:Goto`.

## Input
- Natural display is always insert mode; Linear may toggle overwrite (SHIFT DEL).
- Templates (slots, cursor moves between them with ◀ ▶ ▲ ▼):
  fraction □/□, mixed ◻□/□, √□, ∛□, ˣ√□ (index, radicand), x^□, 10^□, e^□, log_□(□),
  Abs|□|, ∫ (f, lower, upper), d/dx (f, x=a), Σ (f, x=a, b).
- Pressing □/□ right after a number makes that number the numerator (cursor to denominator).
- Functions that open a parenthesis (sin(, log(, ln(, Pol(…) need `)`; it may be omitted before =.
- ▶ at the very end jumps to the start, ◀ at the start jumps to the end.
- SHIFT DEL (INS) on Natural: the expression right of the cursor becomes the argument of the next
  template function (wrap).
- Up to 99 bytes per expression; cursor shape changes when ≤ 10 bytes remain.

## Priority (tightest first)
parentheses → functions with `(` → postfix (x², x³, x⁻¹, x!, °′″, %, ▸t), powers, roots →
fractions → unary minus, base prefixes → conversions, estimators → implied × → nPr nCr ∠ →
dot product → × ÷ → + − → and → or xor xnor.

## Results
- S⇔D toggles exact ↔ decimal. SHIFT = gives the decimal form directly (then S⇔D offers
  fraction/π form only).
- SHIFT S⇔D toggles mixed ↔ improper fraction.
- π form only for |x| < 10⁶. Mixed fraction only if ≤ 10 digits in total.

## Modes (MODE): 1 COMP, 2 CMPLX, 3 STAT, 4 BASE-N, 5 EQN, 6 MATRIX, 7 TABLE, 8 VECTOR
SETUP (SHIFT MODE), page 1: 1 MthIO (→ 1 MathO, 2 LineO) 2 LineIO 3 Deg 4 Rad 5 Gra 6 Fix 7 Sci 8 Norm.
Page 2 (▼): 1 ab/c 2 d/c 3 CMPLX (a+bi / r∠θ) 4 STAT (FREQ ON/OFF) 5 Disp (Dot/Comma) 6 ◀CONT▶.
Defaults: MthIO-MathO, Deg, Norm 1, d/c, a+bi, STAT OFF, Dot. CLR (SHIFT 9): Setup / Memory / All.

- **STAT**: type menu 1-VAR, A+BX, _+CX², ln X, e^X, A·B^X, A·X^B, 1/X → spreadsheet editor
  (X | Y | FREQ; 80/40/26 rows). SHIFT 1 menu: Type, Data, Sum, Var, Reg (or Distr in 1-VAR), MinMax.
  Editor: DEL deletes a row; Edit ▸ Ins / Del-A.
- **TABLE**: f(X) → Start? (1) End? (5) Step? (1) → table of X, f(X), at most 30 rows
  (else Insufficient MEM). AC returns to f(X).
- **EQN**: 1 two unknowns, 2 three unknowns, 3 quadratic, 4 cubic; coefficient grid editor.
- **MATRIX / VECTOR**: MatA–C / VctA–C, Dim / Data / Mat… / Ans / det / Trn (or Dot) menus
  under SHIFT 4 / SHIFT 5; result screens MatAns / VctAns.
- **CMPLX**: i on ENG; SHIFT 2 menu arg, Conjg, ▸r∠θ, ▸a+bi.
- **BASE-N**: DEC/HEX/BIN/OCT on x², x^, log, ln; BIN is 16-bit; SHIFT 3 logic menu.

## Errors
Math, Stack, Syntax, Argument, Dimension, Variable, Can't Solve, Insufficient MEM, Time Out.

## Keys (SHIFT / ALPHA)
Row CALC (SOLVE / =), ∫ (d/dx / :), x⁻¹ (x!), log_□ (Σ).
□/□ (mixed), √□ (∛), x² (x³), x^□ (ˣ√), log (10^□), ln (e^□).
(−) (∠ / A), °′″ (← / B), hyp (Abs / C), sin cos tan (inverses / D E F).
RCL (STO), ENG (← / i), ( (%), ) (, / X), S⇔D (a b/c⇔d/c / Y), M+ (M− / M).
7 CONST, 8 CONV, 9 CLR, DEL INS, AC OFF; 4 MATRIX, 5 VECTOR, × nPr, ÷ nCr;
1 STAT, 2 CMPLX, 3 BASE, + Pol, − Rec; 0 Rnd, . (Ran# / RanInt), ×10^x (π / e), Ans DRG▸.
hyp opens a menu (sinh … tanh⁻¹).

## Build plan
- N1 engine: math input tree, editing, linearisation → evaluator, COMP results.
- N2 engine: dot-matrix layout/rendering (bitmap), Linear and Natural screens, errors.
- N3 engine: exact result forms, S⇔D.
- N4 engine: SETUP/MODE menus, CMPLX, BASE-N, EQN, MATRIX, VECTOR, STAT editor, TABLE, CALC/SOLVE.
- N5 app: keypad layouts + two skins (silver disc, black arrow-pad), full-dot LCD painter, models
  in Settings.
