"""Imports the downloaded boss sprites into the game's art folders.

    python tools/import_bosses.py

Reads (from the project folder):
  "Undead executioner.zip"              Kronovi, https://darkpixel-kronovi.itch.io/undead-executioner
                                        -> the Hollow Warden (art/enemies/warden/) + its summoned spirits (art/enemies/spirit/)
  "Necromancer_creativekind-Sheet.png"  CreativeKind, https://creativekind.itch.io/necromancer-free
                                        -> the Bone Shaman (art/enemies/bone_shaman/), mirrored to face right

Frames are trimmed to one shared box per character (so they don't jitter), centred on the body,
feet at the bottom, and get a thin ghostly outline so the dark sprites read on dark floors.
Prints the frame sizes to put in art/art_spec.gd.
"""
import io
import os
import zipfile
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ART = os.path.join(ROOT, "art")


def cells(sheet, cw, ch, count, row=None):
    cols = sheet.width // cw
    out = []
    for i in range(count):
        c, r = (i % cols, i // cols) if row is None else (i, row)
        out.append(sheet.crop((c * cw, r * ch, c * cw + cw, r * ch + ch)))
    return out


def outline(img, rgba):
    src = img.load()
    out = img.copy()
    dst = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 40:
                    dst[x, y] = rgba
                    break
    return out


def brighten(img, k):
    px = img.copy()
    p = px.load()
    for y in range(px.height):
        for x in range(px.width):
            r, g, b, a = p[x, y]
            if a:
                p[x, y] = (min(255, int(r * k + 60)), min(255, int(g * k + 60)), min(255, int(b * k + 60)), a)
    return px


def body_center_x(frames):
    xs, n = 0.0, 0
    for f in frames:
        px = f.load()
        for y in range(f.height):
            for x in range(f.width):
                if px[x, y][3] > 40:
                    xs += x
                    n += 1
    return xs / max(1, n)


def pack(anims, center_from, scale, ghost, folder, key):
    """anims: {name: [frames]} all from same-size cells. Writes strips, returns frame size."""
    allf = [f for fs in anims.values() for f in fs]
    boxes = [f.getbbox() for f in allf if f.getbbox()]
    minx = min(b[0] for b in boxes)
    maxx = max(b[2] for b in boxes)
    miny = min(b[1] for b in boxes)
    maxy = max(b[3] for b in boxes)
    cx = round(body_center_x(center_from))
    half = max(cx - minx, maxx - cx) + 1
    box = (cx - half, miny - 1, cx + half, maxy + 1)
    size = None
    os.makedirs(os.path.join(ART, folder), exist_ok=True)
    for name, frames in anims.items():
        done = []
        for f in frames:
            c = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
            c.paste(f, (-box[0], -box[1]))
            if scale != 1:
                c = c.resize((c.width * scale, c.height * scale), Image.NEAREST)
            done.append(outline(c, ghost))
        size = done[0].size
        strip = Image.new("RGBA", (size[0] * len(done), size[1]), (0, 0, 0, 0))
        for i, f in enumerate(done):
            strip.paste(f, (i * size[0], 0))
        path = os.path.join(ART, folder, "%s_%s.png" % (key, name))
        strip.save(path)
        print("write", os.path.relpath(path, ROOT), strip.size)
    print("  -> %s frame size: Vector2i(%d, %d)" % (key, size[0], size[1]))
    return size


def executioner():
    zpath = os.path.join(ROOT, "Undead executioner.zip")
    if not os.path.exists(zpath):
        print("skip executioner (zip not found)")
        return
    z = zipfile.ZipFile(zpath)

    def sheet(name):
        for n in z.namelist():
            if n.endswith("png/" + name + ".png"):
                return Image.open(io.BytesIO(z.read(n))).convert("RGBA")
        raise SystemExit("missing " + name)

    idle = cells(sheet("idle"), 100, 100, 4)
    anims = {
        "idle": idle,
        "walk": cells(sheet("idle2"), 100, 100, 8),
        "windup": cells(sheet("summon"), 100, 100, 5),     # raises the scythe
        "attack": cells(sheet("attacking"), 100, 100, 13),  # scythe swings (charges, rings)
        "summon": cells(sheet("skill1"), 100, 100, 12),     # shadow-spike burst (slams, summons)
        "death": cells(sheet("death"), 100, 100, 18),
    }
    anims["hurt"] = [brighten(idle[0], 1.6)]
    pack(anims, idle, 1, (150, 128, 196, 170), "enemies/warden", "warden")

    spirit = {
        "idle": cells(sheet("summonIdle"), 50, 50, 4),
        "walk": cells(sheet("summonIdle"), 50, 50, 4),
        "death": cells(sheet("summonDeath"), 50, 50, 6),
    }
    pack(spirit, spirit["idle"], 1, (170, 150, 220, 190), "enemies/spirit", "spirit")


def necromancer():
    path = os.path.join(ROOT, "Necromancer_creativekind-Sheet.png")
    if not os.path.exists(path):
        print("skip necromancer (sheet not found)")
        return
    sheet = Image.open(path).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)   # face right
    cols = sheet.width // 160

    def row(r, n):
        # after the mirror, frame 0 of each row is at the far right
        return [sheet.crop(((cols - 1 - i) * 160, r * 128, (cols - i) * 160, r * 128 + 128)) for i in range(n)]

    idle = row(0, 8)
    anims = {
        "idle": idle,
        "walk": row(1, 8),
        "attack": row(2, 13),          # staff flare (skull volleys, blink rings)
        "windup": row(3, 13)[:7],      # staff raised, before beams
        "summon": row(4, 17),          # skull fire (bone rain, summons)
        "hurt": row(5, 5)[1:3],
        "death": row(6, 9),
    }
    pack(anims, idle, 1, (200, 60, 70, 150), "enemies/bone_shaman", "bone_shaman")


if __name__ == "__main__":
    executioner()
    necromancer()
