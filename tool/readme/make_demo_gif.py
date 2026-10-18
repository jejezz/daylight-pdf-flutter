#!/usr/bin/env python3
"""Build docs/screenshots/demo.gif from the raw light captures (no screen recording needed).

    flutter test integration_test/readme_shots_test.dart -d macos     # writes the raw captures
    cp <tmp>/daylight_pdf_readme/*.png docs/screenshots/raw/          # (names use '-' instead of '_')
    python3 tool/readme/make_demo_gif.py

The GIF is 760px wide, 15 fps, with short cross-fades between screens (conventions/readme-guide.md §4: <= 15 s, <= 5 MB).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'docs/screenshots/raw'
OUT = ROOT / 'docs/screenshots/demo.gif'

# The flow: open recent files, convert, arrange pages, annotate and search, print.
FRAMES = ['home-light', 'convert-light', 'pages-light', 'viewer-light', 'print-light']
WIDTH = 760
FPS = 15
HOLD_SECONDS = 2.2
FADE_STEPS = 5


def load(name: str) -> Image.Image:
    img = Image.open(RAW / f'{name}.png').convert('RGB')
    return img.resize((WIDTH, round(img.height * WIDTH / img.width)), Image.LANCZOS)


def main() -> None:
    shots = [load(n) for n in FRAMES]
    frame_ms = round(1000 / FPS)
    frames: list[Image.Image] = []
    durations: list[int] = []
    for i, shot in enumerate(shots):
        frames.append(shot)
        durations.append(round(HOLD_SECONDS * 1000))
        if i + 1 < len(shots):
            for step in range(1, FADE_STEPS + 1):
                frames.append(Image.blend(shot, shots[i + 1], step / (FADE_STEPS + 1)))
                durations.append(frame_ms)
    palette = [f.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    palette[0].save(OUT, save_all=True, append_images=palette[1:], duration=durations, loop=0, optimize=True, disposal=2)
    seconds = sum(durations) / 1000
    print(f'wrote {OUT} {OUT.stat().st_size / 1024:.0f} KB, {len(frames)} frames, {seconds:.1f} s')


if __name__ == '__main__':
    main()
