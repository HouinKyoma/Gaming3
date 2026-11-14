"""Builds the biome tile sheets from the 0x72 DungeonTileset II tiles in art/tiles/dungeon_tiles.png.

Usage (from the project folder, needs: pip install pillow):  python tools/make_biomes.py

OVERWRITES art/tiles/biome_*.png. To use your own art instead,
just paint over those PNGs (layout: see the top of scenes/rooms/room.gd) and don't run this again.
"""
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ART = os.path.join(ROOT, "art")
T = 16

# dark, mid, light colours per biome (None = keep the original colours)
BIOMES = {
    "crypt": None,
    "ossuary": ((44, 34, 30), (150, 128, 100), (238, 224, 196)),
    "hall": ((16, 24, 40), (66, 98, 128), (176, 214, 232)),
    "ashen": ((26, 10, 12), (104, 40, 32), (226, 140, 92)),
}
LAVA = {"crypt": ((120, 20, 10), (240, 110, 30), (255, 220, 120)),
        "ossuary": ((120, 20, 10), (240, 110, 30), (255, 220, 120)),
        "hall": ((10, 40, 90), (40, 140, 220), (190, 240, 255)),
        "ashen": ((140, 20, 8), (255, 96, 24), (255, 230, 120))}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_map(img, pal, contrast=1.15):
    if pal is None:
        return img.copy()
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            l = max(0.0, min(1.0, (l - 0.5) * contrast + 0.5))
            c = lerp(pal[0], pal[1], l * 2) if l < 0.5 else lerp(pal[1], pal[2], (l - 0.5) * 2)
            px[x, y] = c + (a,)
    return out


def tile(sheet, cx, cy):
    return sheet.crop((cx * T, cy * T, cx * T + T, cy * T + T))


def boulder(pal):
    pal = pal or ((40, 34, 44), (110, 100, 112), (190, 180, 186))
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for y in range(T):
        for x in range(T):
            dx, dy = (x - 7.5) / 6.8, (y - 8.5) / 5.8
            d = dx * dx + dy * dy
            if d <= 1.0:
                shade = 0.75 - 0.35 * dx - 0.45 * dy
                if d > 0.72:
                    shade *= 0.45
                shade = max(0.0, min(1.0, shade))
                c = lerp(pal[0], pal[1], shade * 2) if shade < 0.5 else lerp(pal[1], pal[2], (shade - 0.5) * 2)
                px[x, y] = c + (255,)
    return img


def pit_tile(pal, lip=True):
    """A dark hole with a lit stone lip at the top, so pits read clearly from a distance."""
    pal = pal or ((36, 28, 40), (92, 80, 96), (160, 146, 160))
    img = Image.new("RGBA", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            if lip and y < 3:
                c = lerp(pal[1], pal[2], 0.5 if y == 0 else 0.15)
            else:
                depth = min(1.0, (y - 3) / 6.0) if lip else 1.0
                c = lerp(lerp(pal[0], (0, 0, 0), 0.4), (4, 2, 6), depth)
                if (x * 7 + y * 3) % 23 == 0 and y > 9:
                    c = lerp(c, pal[0], 0.6)
            px[x, y] = c + (255,)
    return img


def lava(pal, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (T, T))
    px = img.load()
    blobs = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(2, 5)) for _ in range(5)]
    for y in range(T):
        for x in range(T):
            v = 0.25
            for bx, by, br in blobs:
                for ox in (-T, 0, T):
                    for oy in (-T, 0, T):
                        d = ((x - bx - ox) ** 2 + (y - by - oy) ** 2) ** 0.5
                        v += max(0.0, 1.0 - d / br) * 0.6
            v = min(1.0, v + rnd.uniform(-0.05, 0.05))
            c = lerp(pal[0], pal[1], v * 2) if v < 0.5 else lerp(pal[1], pal[2], (v - 0.5) * 2)
            px[x, y] = c + (255,)
    return img


def build_sheets():
    src = Image.open(os.path.join(ART, "tiles", "dungeon_tiles.png")).convert("RGBA")
    spikes = Image.open(os.path.join(ART, "props", "spawn_marker_idle.png")).convert("RGBA")
    n = max(1, spikes.width // T)
    spikes_down = spikes.crop((0, 0, T, T))
    spikes_up = spikes.crop(((n - 1) * T, 0, n * T, T))
    hole = tile(src, 0, 2)   # the 0x72 "hole" tile, used as the pit
    for name, pal in BIOMES.items():
        sheet = Image.new("RGBA", (8 * T, 3 * T), (0, 0, 0, 0))
        for cy in range(3):
            for cx in range(4):
                sheet.paste(gradient_map(tile(src, cx, cy), pal), (cx * T, cy * T))
        sheet.paste(boulder(pal), (0, 2 * T))   # rock: a boulder instead of the hole
        floor = gradient_map(tile(src, 0, 0), pal)
        for i, sp in enumerate((spikes_down, spikes_up)):
            cell = floor.copy()
            cell.alpha_composite(gradient_map(sp, pal) if pal else sp)
            sheet.paste(cell, ((4 + i) * T, 0))
        sheet.paste(lava(LAVA[name], 1), (6 * T, 0))
        sheet.paste(lava(LAVA[name], 2), (7 * T, 0))
        sheet.paste(pit_tile(pal), (4 * T, T))
        sheet.paste(pit_tile(pal, lip=False), (5 * T, T))
        out = os.path.join(ART, "tiles", "biome_%s.png" % name)
        sheet.save(out)
        print("write", out)


if __name__ == "__main__":
    build_sheets()
