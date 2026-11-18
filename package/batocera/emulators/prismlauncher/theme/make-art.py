#!/usr/bin/env python3
"""Generate the Minecraft system's artwork (original pixel art, no Mojang assets).

Writes, next to this script:
  art/logos/minecraft.svg, art/logos/minecraft-w.svg  system logo (color / white)
  art/consoles/minecraft.png                          475x450 block for the carousel
  art/background/minecraft.png                        background (convert to .jpg)
  ../../../emulationstation/batocera-es-system/roms/minecraft/images/*.png  menu entry images

ES's SVG renderer can't draw <text>, so the word is built from rectangles in
a small pixel font. Only the standard library is used; PNGs are written by
hand. Run: python3 make-art.py, then convert the background to JPEG
(macOS: sips -s format jpeg art/background/minecraft.png --out art/background/minecraft.jpg).
"""
from __future__ import annotations

import random
import struct
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Menu entry images live with the menu entries
IMAGES = HERE.parents[2] / "emulationstation/batocera-es-system/roms/minecraft/images"

# 5x7 pixel font, only the letters we need
FONT = {
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
}

GRASS = [(95, 159, 53), (106, 170, 64), (84, 140, 46), (117, 181, 72)]
DIRT = [(134, 96, 67), (121, 85, 58), (150, 108, 74), (108, 76, 51)]


def textures(seed: int) -> tuple[list[list[tuple]], list[list[tuple]]]:
    """16x16 top (grass) and side (grass edge over dirt) textures."""
    rnd = random.Random(seed)
    top = [[rnd.choice(GRASS) for _ in range(16)] for _ in range(16)]
    side = []
    for y in range(16):
        row = []
        for x in range(16):
            edge = 3 + (rnd.random() < 0.5) + (x * 7 % 3 == 0)
            row.append(rnd.choice(GRASS) if y < edge else rnd.choice(DIRT))
        side.append(row)
    return top, side


def shade(c: tuple, f: float) -> tuple:
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


def gray(c: tuple, base: float) -> tuple:
    v = int(min(255, base * (0.85 + 0.15 * sum(c[:3]) / 400)))
    return (v, v, v)


def cube_quads(cx: float, top: float, w: float, side_h: float, seed: int = 7, mono: bool = False):
    """Isometric block as a list of (quad points, rgb) texel quads."""
    h = w / 2
    tex_top, tex_side = textures(seed)
    quads = []

    def add(origin, ax, ay, tex, f, base):
        for j in range(16):
            for i in range(16):
                p = (origin[0] + i * ax[0] + j * ay[0], origin[1] + i * ax[1] + j * ay[1])
                pts = [p, (p[0] + ax[0], p[1] + ax[1]),
                       (p[0] + ax[0] + ay[0], p[1] + ax[1] + ay[1]), (p[0] + ay[0], p[1] + ay[1])]
                c = tex[j][i]
                quads.append((pts, gray(c, base) if mono else shade(c, f)))

    # top: from the back corner, axes toward the right and left corners
    add((cx, top), (w / 16, h / 16), (-w / 16, h / 16), tex_top, 1.0, 255)
    # left face: from the left corner, axes toward the front edge and down
    add((cx - w, top + h), (w / 16, h / 16), (0, side_h / 16), tex_side, 0.72, 200)
    # right face: from the front-top corner, axes toward the right corner and down
    add((cx, top + 2 * h), (w / 16, -h / 16), (0, side_h / 16), tex_side, 0.86, 228)
    return quads


# ------------------------------------------------------------------ raster

class Canvas:
    def __init__(self, width: int, height: int, bg=(0, 0, 0, 0)):
        self.w, self.h = width, height
        self.px = [list(bg) for _ in range(width * height)]

    def quad(self, pts, rgb, alpha=255):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1 = max(0, int(min(xs))), min(self.w - 1, int(max(xs)) + 1)
        y0, y1 = max(0, int(min(ys))), min(self.h - 1, int(max(ys)) + 1)
        edges = list(zip(pts, pts[1:] + pts[:1]))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px, py = x + 0.5, y + 0.5
                sign = 0
                inside = True
                for (ax, ay), (bx, by) in edges:
                    cross = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
                    if cross == 0:
                        continue
                    s = 1 if cross > 0 else -1
                    if sign == 0:
                        sign = s
                    elif s != sign:
                        inside = False
                        break
                if inside:
                    self.px[y * self.w + x] = [*rgb, alpha]

    def rect(self, x, y, w, h, rgb, alpha=255):
        for yy in range(max(0, int(y)), min(self.h, int(y + h))):
            for xx in range(max(0, int(x)), min(self.w, int(x + w))):
                self.px[yy * self.w + xx] = [*rgb, alpha]

    def save_png(self, path: Path):
        raw = b"".join(b"\x00" + bytes(v for p in self.px[y * self.w:(y + 1) * self.w] for v in p)
                       for y in range(self.h))

        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
                         + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def draw_block(c: Canvas, cx, top, w, side_h, seed=7):
    for pts, rgb in cube_quads(cx, top, w, side_h, seed):
        c.quad(pts, rgb)


def draw_word(c: Canvas, word, x, y, cell, rgb, shadow=None):
    for k, ch in enumerate(word):
        for r, row in enumerate(FONT[ch]):
            for col, bit in enumerate(row):
                if bit == "1":
                    px, py = x + (k * 6 + col) * cell, y + r * cell
                    if shadow:
                        c.rect(px + cell // 3, py + cell // 3, cell, cell, shadow)
                    c.rect(px, py, cell, cell, rgb)


# --------------------------------------------------------------------- svg

def logo_svg(white: bool) -> str:
    cell = 10
    text_w = (len("MINECRAFT") * 6 - 1) * cell
    w = 38
    block_w = 2 * w + 8
    width, height = block_w + 24 + text_w + 4, 7 * cell + 30
    parts = []
    for pts, rgb in cube_quads(w + 4, 2, w, 44, mono=white):
        d = " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)
        # a hairline stroke in the same color closes anti-aliasing seams between texels
        parts.append(f'<polygon points="{d}" fill="rgb{rgb}" stroke="rgb{rgb}" stroke-width="0.6"/>')
    tx, ty = block_w + 24, (height - 7 * cell) / 2
    fill, shadow = ("#ffffff", None) if white else ("#6aaa40", "#2d4d1a")
    for k, ch in enumerate("MINECRAFT"):
        for r, row in enumerate(FONT[ch]):
            for col, bit in enumerate(row):
                if bit == "1":
                    x, y = tx + (k * 6 + col) * cell, ty + r * cell
                    if shadow:
                        parts.append(f'<rect x="{x + 3}" y="{y + 3}" width="{cell}" height="{cell}" fill="{shadow}"/>')
                    parts.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" fill="{fill}"/>')
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">\n'
            + "\n".join(parts) + "\n</svg>\n")


# -------------------------------------------------------------------- main

def main() -> None:
    (HERE / "art/logos").mkdir(parents=True, exist_ok=True)
    (HERE / "art/logos/minecraft.svg").write_text(logo_svg(white=False))
    (HERE / "art/logos/minecraft-w.svg").write_text(logo_svg(white=True))

    console = Canvas(475, 450)
    draw_block(console, 237, 40, 170, 190)
    console.save_png(HERE / "art/consoles/minecraft.png")

    bg = Canvas(1280, 720, (14, 20, 12, 255))
    rnd = random.Random(3)
    for y in range(0, 720, 40):
        for x in range(0, 1280, 40):
            c = rnd.choice(DIRT if y > 400 else GRASS)
            bg.rect(x, y, 40, 40, shade(c, 0.18 + 0.06 * rnd.random()))
    bg.save_png(HERE / "art/background/minecraft.png")

    single = Canvas(400, 300)
    draw_block(single, 200, 40, 110, 125)
    single.save_png(IMAGES / "singleplayer.png")

    split = Canvas(400, 300)
    draw_block(split, 100, 70, 70, 80, seed=11)
    draw_block(split, 300, 70, 70, 80, seed=12)
    split.rect(198, 30, 4, 240, (230, 230, 230))
    split.save_png(IMAGES / "splitscreen.png")

    prism = Canvas(400, 300)
    for pts, rgb in cube_quads(200, 40, 110, 125, seed=5):
        prism.quad(pts, (rgb[0] // 2 + 70, rgb[1] // 3 + 30, rgb[2] // 2 + 110))  # violet tint
    prism.save_png(IMAGES / "prism.png")


if __name__ == "__main__":
    main()
