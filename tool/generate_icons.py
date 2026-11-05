"""Render Steady Through's simple path-and-sun mark for native app icons.

Run with Python and Pillow from the repository root. The source is drawn at
four times final size so small icons keep smooth edges.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SCALE = 4
SIZE = 1024


def point(x: float, y: float) -> tuple[int, int]:
    return round(x * SCALE), round(y * SCALE)


def cubic(start, first, second, end, count=90):
    for step in range(count + 1):
        t = step / count
        r = 1 - t
        x = r**3 * start[0] + 3 * r**2 * t * first[0] + 3 * r * t**2 * second[0] + t**3 * end[0]
        y = r**3 * start[1] + 3 * r**2 * t * first[1] + 3 * r * t**2 * second[1] + t**3 * end[1]
        yield point(x, y)


def draw_mark() -> Image.Image:
    full = SIZE * SCALE
    image = Image.new('RGB', (full, full))
    pixels = image.load()
    for y in range(full):
        ratio = y / (full - 1)
        color = (
            round(31 + ratio * (19 - 31)),
            round(92 + ratio * (58 - 92)),
            round(103 + ratio * (72 - 103)),
        )
        for x in range(full):
            pixels[x, y] = color

    draw = ImageDraw.Draw(image)
    # A generous, gently curving route works as a recognizable mark at 32 px.
    route = list(cubic((215, 760), (270, 665), (360, 550), (455, 575)))
    route += list(cubic((455, 575), (550, 610), (545, 495), (635, 435)))
    route += list(cubic((635, 435), (675, 405), (700, 370), (720, 343)))
    width = 86 * SCALE
    draw.line(route, fill='#F5F5E8', width=width, joint='curve')
    for x, y in (route[0], route[-1]):
        radius = width // 2
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill='#F5F5E8')

    sun_x, sun_y = point(758, 268)
    outer = 115 * SCALE
    draw.ellipse(
        (sun_x - outer, sun_y - outer, sun_x + outer, sun_y + outer),
        fill='#F2D796',
    )
    inner = 66 * SCALE
    draw.ellipse(
        (sun_x - inner, sun_y - inner, sun_x + inner, sun_y + inner),
        fill='#FAE9B9',
    )
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def save_size(source: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main() -> None:
    source = draw_mark()
    source_path = ROOT / 'assets' / 'brand' / 'steady-through-icon.png'
    save_size(source, source_path, SIZE)

    android = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        save_size(source, android / f'mipmap-{density}' / 'ic_launcher.png', size)

    ios = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    contents = json.loads((ios / 'Contents.json').read_text())
    for entry in contents['images']:
        if 'filename' not in entry:
            continue
        base = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].removesuffix('x'))
        save_size(source, ios / entry['filename'], round(base * scale))

    mac = ROOT / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_size(source, mac / f'app_icon_{size}.png', size)

    windows = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
    source.save(windows, format='ICO', sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)])


if __name__ == '__main__':
    main()
