# Testing W-Calc

## Quick web test (no install)

```bash
cd ~/code/projects/w-calc
git switch dev && git pull         # latest integrated work
tool/web.sh                         # dev server, hot reload, LAN-accessible
```

The script prints `Open on phone: http://<your-ip>:8080`. Open it in your phone's browser
(same Wi-Fi) or on the computer. First load takes ~20–60 s while it compiles.
Press `r` in the terminal to hot-reload after pulling new changes, `q` to quit.

Closest-to-production (fully offline, no CDN): `tool/web.sh release`.

### Physical keyboard (computer browser)
| Keyboard | Calculator |
|---|---|
| `0-9 . + - * / ( )` | same keys |
| `Enter` or `=` | `=` |
| `Backspace` | `DEL` |
| `Esc` / `Delete` | `AC` |
| arrows | cursor / REPLAY |
| `s` / `a` | SHIFT / ALPHA |
| `n` | `(−)` |
| `e` | `EXP` |

## Android build
Every merge to `main` produces a signed APK in the GitHub Release (`*-arm64-v8a.apk` for most phones).

## Reporting a mismatch
One line per case, comparing against the real calculator:

```
keys | expected display (upper / lower) | mode/setup if not default
2 ÷ 3 = | 0.666666667 |
SHIFT DEL 1 | cursor shape … |
```

Visual differences: a phone photo of the real LCD next to a screenshot is ideal.
Assumptions waiting for confirmation are listed in [`behaviour-notes.md`](behaviour-notes.md).

## Repro links (web)
Append `?keys=` with comma-separated keys to the web URL to replay them on load, e.g.
`http://<ip>:8080/?keys=56,times,(,neg,12,),=`. Add `&skin=midnight` (classic, midnight, high-contrast, ivory) to preview a theme. In URLs write `+` as `%2B` (a bare `+` means space) and the comma key as `comma`. Names: digits, `plus minus times div neg`,
`( ) EXP Ans = AC DEL INS SHIFT ALPHA MODE hyp < > up down`, functions `sin cos tan log ln sqrt x2 x-1 pow`, shortcuts `asin acos atan 10^ e^ e cbrt x3 xroot fact nPr nCr pi Ran# Rnd DRG`.
