# Graph expressions (our spec)

The graph screen's expression list is typeset, not plain text. Each row is a structured
input (`GxRow`): symbols and boxes — fraction, power, subscript, √, ⁿ√, |a|, Σ, Π, ∫, d/dx.

## Editing (`GxEditor`)
- Typing letters that spell a function name turns them into that function (`sin`, `sinh`,
  `arcsin`, `ln`, `log`, `exp`, `floor`, `ceil`, `round`, `sign`, `mod`, `min`, `max`, csc/sec/cot
  and their hyperbolic / inverse forms). `pi` → π, `theta` → θ, `sqrt` → √ box.
- `/` takes the term before the cursor as numerator (`(x+1)/` drops the brackets).
- `^` opens an exponent, `_` a subscript. `(` closes itself when typed at the end or before an
  operator; `)` steps over an existing `)`.
- ←/→ walk through every slot. Backspace steps into a box before the cursor; at the start of a
  box it removes the box and keeps its contents (a fraction becomes `a ÷ b`).
- Saved as LaTeX-like text: `y=x^{2}+\frac{1}{x}`. Plain formulas (`x^2-1`, `sqrt(x)/2`,
  `|x|`, `y<=x`) are read too (old saved graphs, calculator formulas).

## Meaning of a row (`gxAnalyse`)
| Row | Shape |
|---|---|
| `x^2`, `y = 2x`, `2x = y` | function y = f(x) |
| `y < x`, `y ≥ sin x` | function with a shaded side (dashed edge when strict) |
| `x = y^2`, `x > 1` | x as a function of y |
| `x^2 + y^2 = 25`, `xy < 1` | implicit relation (left − right compared with 0) |
| `(1, 2)`, `(a, a^2)` | point |
| `b = -3.5` | slider variable |
| `c = 2b + 1` | defined variable |
| `f(x) = x^2 + c` | function definition; drawn when its parameter is x; callable as `f(…)` |
| `2 + 3` | constant: value shown |

- Implied multiplication everywhere (`2x`, `ab`, `x(x+1)`); `sin 2x` = sin(2x);
  `sin x cos x` = sin(x)·cos(x); `sin^2 x` squares the result; `sin^{-1}` is arcsin;
  `log_2 8` = 3; `x!` uses Γ so non-integers work.
- Σ/Π run the index (`n=1` in the lower slot) over integers, max 100 000 terms; ∫ uses Simpson's
  rule with 128 intervals; d/dx is a central difference.
- Variables not defined by any row are offered as sliders.
- Trig follows the graph's Radians/Degrees setting.
