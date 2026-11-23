"""Draws the W-Calc app icon (original design) and writes all launcher sizes.

Usage: python3 tool/make_icons.py   (needs Pillow)
"""
from PIL import Image, ImageDraw

S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def icon(size=S, padding=0.0, rounded=True, body_layer=True):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = int(S * padding)
    # Body with vertical gradient.
    body = Image.new('RGBA', (S, S))
    bd = ImageDraw.Draw(body)
    for y in range(S):
        bd.line([(0, y), (S, y)], fill=lerp((0x3B, 0x41, 0x53), (0x1F, 0x23, 0x2D), y / S) + (255,))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([p, p, S - p, S - p], radius=int(S * 0.22) if rounded else 0, fill=255)
    if body_layer:
        img.paste(body, (0, 0), mask)
    inner = S - 2 * p
    def X(f): return p + int(inner * f)
    # LCD.
    d.rounded_rectangle([X(0.12), X(0.12), X(0.88), X(0.43)], radius=int(inner * 0.04), fill=(0x1B, 0x1E, 0x26))
    d.rounded_rectangle([X(0.15), X(0.15), X(0.85), X(0.40)], radius=int(inner * 0.03), fill=(0xC3, 0xCD, 0xB2))
    # Dot-matrix "W" on the LCD.
    w = ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#']
    dot = inner * 0.022
    pitch = inner * 0.028
    ox, oy = X(0.20), X(0.18)
    for r, row in enumerate(w):
        for c, ch in enumerate(row):
            if ch == '#':
                x, y = ox + c * pitch, oy + r * pitch
                d.rectangle([x, y, x + dot, y + dot], fill=(0x1C, 0x21, 0x17))
    # Seven-segment style "=" bars at the right of the LCD.
    d.rectangle([X(0.55), X(0.24), X(0.79), X(0.265)], fill=(0x1C, 0x21, 0x17))
    d.rectangle([X(0.55), X(0.31), X(0.79), X(0.335)], fill=(0x1C, 0x21, 0x17))
    # Keys: 3 × 3 grid, bottom-right key red.
    for r in range(3):
        for c in range(3):
            x0 = X(0.14 + c * 0.25)
            y0 = X(0.52 + r * 0.14)
            color = (0xB4, 0x50, 0x5A) if (r, c) == (2, 2) else ((0xD9, 0xD6, 0xCF) if r == 0 else (0x9D, 0xA2, 0xAA))
            d.rounded_rectangle([x0, y0, x0 + int(inner * 0.21), y0 + int(inner * 0.10)], radius=int(inner * 0.03), fill=color)
    return img.resize((size, size), Image.LANCZOS)


def main():
    base = 'android/app/src/main/res'
    for folder, px in [('mipmap-mdpi', 48), ('mipmap-hdpi', 72), ('mipmap-xhdpi', 96), ('mipmap-xxhdpi', 144), ('mipmap-xxxhdpi', 192)]:
        icon(px).save(f'{base}/{folder}/ic_launcher.png')
    icon(192).save('web/icons/Icon-192.png')
    icon(512).save('web/icons/Icon-512.png')
    # Maskable: content inside the safe zone, square full-bleed background.
    icon(192, padding=0.10, rounded=False).save('web/icons/Icon-maskable-192.png')
    icon(512, padding=0.10, rounded=False).save('web/icons/Icon-maskable-512.png')
    icon(32).save('web/favicon.png')
    icon(512).save('docs/icon-512.png')
    # Android 8+ adaptive icon: body colour behind, display and keys in the
    # 66/108 safe zone in front (launchers crop the outer part).
    for folder, px in [('mipmap-mdpi', 108), ('mipmap-hdpi', 162), ('mipmap-xhdpi', 216), ('mipmap-xxhdpi', 324), ('mipmap-xxxhdpi', 432)]:
        icon(px, padding=0.17, rounded=False, body_layer=False).save(f'{base}/{folder}/ic_launcher_foreground.png')


if __name__ == '__main__':
    main()
