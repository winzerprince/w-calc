# Testing W-Calc

## Quick web test (no install)

```bash
cd w-calc
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

## On-device checklist (v0.10+)

Install the newest `…-arm64-v8a.apk` from GitHub Releases (uninstall first to see the first-start
tour again). Tick each line; report anything that differs from your real calculators with the
keys you pressed and what each showed.

**Start and look**
- [ ] Dark launch screen with the W-Calc icon; launcher icon fills its shape (no white frame).
- [ ] First-start tour: notes and arrows over a dark scrim; tap moves on; *skip* closes.
- [ ] Tap the solar panel: full screen; tap again: back.
- [ ] Long-press `sin`: bubble lists SHIFT ▸ sin⁻¹ and ALPHA ▸ D.
- [ ] Every key vibrates (Settings ▸ Vibrate on key press).
- [ ] Menu ▸ Theme ▸ Finish: Classic, Raised, Soft, Metallic look different.

**Models** (Menu ▸ Calculator model; tap a picture to preview)
- [ ] Scientific Plus: `2 ab/c 3 + 1 ab/c 2 =` → `1┘1┘6`.
- [ ] Textbook Plus II: `2 □/□ 3 ▶ + 1 □/□ 2 =` → 7/6; `S⇔D` → 1.166666667.
- [ ] Textbook Plus: `MODE 5 3`, `1 = 1 = 3 □/□ 4 = =` → X1 = −1/2 + √2/2 i.
- [ ] Scientific View: `1 + 1 enter`, `2 n/d 3 ▶ + 1 n/d 2 enter` → both answers stay on screen.
- [ ] Scientific Two-View: `5 n/d 6 + 1 n/d 10 enter` → 14/15; `◄►` → 0.933333333.
- [ ] Scientific Max: `MODE 6 4 4 4` opens a 4×4 MatD editor.
- [ ] Textbook Basic: ∫, CALC and CONST are faded and do nothing.

**Graph, history, manual**
- [ ] Type `X² − 4` (ALPHA `)` gives X): chart icon appears; graph shows roots at ±2.
- [ ] Textbook: `MODE 5 3`, `1 = −3 = 2 =` then chart icon: curve crosses at 1 and 2.
- [ ] Clock icon lists earlier calculations; tap one copies its answer.
- [ ] Menu ▸ Manual: search "speed of light"; open the constants list and filter "gas".

**Questions for your real units** — see `docs/behaviour-notes.md` (open items #73, #79, #81,
#83, #84 and the older "verify on device" rows).
