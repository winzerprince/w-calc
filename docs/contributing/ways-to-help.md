# Ways to help

You don't need to write code to help.

## Report a bug
Use the [Bug report](https://github.com/winzerprince/w-calc/issues/new/choose) form: the model,
the exact keys you pressed, what you expected (or what your physical calculator shows) and what
W-Calc showed. A screenshot helps.

## Send test vectors
Have a real scientific calculator? Key sequences with the exact result are gold. Write them as:

```
keys | expected display | mode/setup
```
e.g. `1 ab/c 2 + 2 ab/c 3 = | 1⌟1⌟6 | COMP, Norm 1`. They become tests word for word.

## Improve the manual or docs
Spotted something unclear in the built-in manual (`lib/manual/`) or these docs? A small pull
request is welcome.

## Write code
- Look for issues labelled **good first issue** or **help wanted**.
- Engine fixes: add a failing test in `packages/wcalc_engine/test/` first, then the fix.
- UI changes: include a screenshot in the pull request.

## Suggest a model
Know a calculator used in your school that W-Calc doesn't have? Open an **Idea or request** with
what it looks like and how it differs. Models from Africa, India, Asia and the Americas are
especially welcome.
