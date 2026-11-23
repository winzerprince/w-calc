"""Draws the W-Calc app icon (original design) and writes all launcher sizes.

Usage: python3 tool/make_icons.py   (needs Pillow)
"""
from PIL import Image, ImageDraw

S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def icon(size=S, padding=0.0, rounded=True, body_layer=True):
    """W-Calc icon: pure black tile (blends into AMOLED black), bright
    display with a pixel W, white keys with one orange accent."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = int(S * padding)
    if body_layer:
        body = Image.new('RGBA', (S, S))
        bd = ImageDraw.Draw(body)
        bd.rectangle([0, 0, S, S], fill=(0, 0, 0, 255))
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [p, p, S - p, S - p], radius=int(S * 0.23) if rounded else 0, fill=255)
        img.paste(body, (0, 0), mask)
    inner = S - 2 * p
    def X(f): return p + int(inner * f)
    ink = (0x0C, 0x18, 0x10)
    # Display: bright mint glass with a dark bezel line.
    d.rounded_rectangle([X(0.14), X(0.15), X(0.86), X(0.47)], radius=int(inner * 0.06), fill=(0x3A, 0x3D, 0x44))
    d.rounded_rectangle([X(0.165), X(0.175), X(0.835), X(0.445)], radius=int(inner * 0.045), fill=(0xD4, 0xF5, 0xC4))
    # Bold pixel W.
    w = ['#...#', '#...#', '#.#.#', '#.#.#', '#.#.#', '##.##', '#...#']
    pitch = inner * 0.034
    dot = pitch * 0.86
    ox, oy = X(0.21), X(0.195)
    for r, row in enumerate(w):
        for c, ch in enumerate(row):
            if ch == '#':
                x, y = ox + c * pitch, oy + r * pitch
                d.rectangle([x, y, x + dot, y + dot], fill=ink)
    # "=" bars.
    d.rounded_rectangle([X(0.54), X(0.25), X(0.78), X(0.285)], radius=int(inner * 0.01), fill=ink)
    d.rounded_rectangle([X(0.54), X(0.335), X(0.78), X(0.37)], radius=int(inner * 0.01), fill=ink)
    # Keys: 2 rows × 3, white, last one orange.
    for r in range(2):
        for c in range(3):
            x0 = X(0.14 + c * 0.25)
            y0 = X(0.56 + r * 0.17)
            color = (0xFF, 0x7A, 0x1A) if (r, c) == (1, 2) else (0xF4, 0xF6, 0xFF)
            d.rounded_rectangle([x0, y0, x0 + int(inner * 0.22), y0 + int(inner * 0.13)],
                                radius=int(inner * 0.04), fill=color)
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
