"""Generates placeholder art at the exact paths, sizes and frame counts the game expects.

Run from the project folder:   python tools/make_placeholders.py      (needs: pip install pillow)

It NEVER overwrites an existing PNG, so it is safe to run again after artists start
replacing files: only missing images are created. The frame sizes here must match
res://art/art_spec.gd (the game reads frame counts from the PNG width).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")

# key: (folder, (w, h), {anim: frames}, colour)
SPRITES = {
    "player":  ("player", (16, 28), {"idle": 4, "walk": 6, "dash": 3, "hurt": 2, "death": 6}, "#4a90e2"),
    "crawler": ("enemies/crawler", (16, 16), {"idle": 2, "walk": 4, "death": 4}, "#d9443c"),
    "swarmer": ("enemies/swarmer", (16, 16), {"idle": 2, "walk": 2, "death": 3}, "#f0803c"),
    "spitter": ("enemies/spitter", (16, 24), {"idle": 2, "walk": 4, "attack": 3, "death": 4}, "#c0396b"),
    "charger": ("enemies/charger", (16, 24), {"idle": 2, "walk": 4, "windup": 2, "attack": 2, "death": 5}, "#9e2a2b"),
    "warden":  ("enemies/warden", (32, 36), {"idle": 4, "walk": 4, "windup": 2, "attack": 4, "summon": 4, "hurt": 1, "death": 8}, "#7a1f3d"),
}
ROUND = {
    "player_bullet": ("projectiles", (8, 8), {"spin": 2}, "#ffe066"),
    "enemy_bullet":  ("projectiles", (8, 8), {"spin": 2}, "#ff3cc7"),
    "ash":           ("pickups", (8, 8), {"idle": 4}, "#f2a65a"),
}
UPGRADE_ICONS = {
    "unlock_dash": ("D", "#4a90e2"), "vitality": ("V", "#e8424f"), "power": ("P", "#f2a65a"),
    "rapid_fire": ("R", "#ffe066"), "swiftness": ("S", "#5ad19a"), "greed": ("G", "#e0c35a"),
    "piercing": ("X", "#b48cf2"), "second_wind": ("W", "#f2f2f2"),
    # boons (run-only)
    "boon_quick_hands": ("q", "#ffe066"), "boon_heavy_ash": ("h", "#f2a65a"),
    "boon_fleet_foot": ("f", "#5ad19a"), "boon_hearty": ("+", "#e8424f"),
    "boon_lodestone": ("m", "#8ab4f2"), "boon_ember_tithe": ("$", "#e0c35a"),
    "boon_long_shot": ("l", "#b48cf2"), "boon_thick_skin": ("t", "#9a90a3"),
}

HEART = [
    ".##...##.",
    "####.####",
    "#########",
    "#########",
    ".#######.",
    "..#####..",
    "...###...",
    "....#....",
]


def hex_rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(rgba, k):
    r, g, b, a = rgba
    f = (lambda c: max(0, min(255, int(c * k))))
    return (f(r), f(g), f(b), a)


def save(rel_path, img):
    path = os.path.join(ROOT, rel_path)
    if os.path.exists(path):
        print("keep   ", rel_path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("create ", rel_path)


def character_strip(size, frames, colour, anim):
    w, h = size
    img = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = hex_rgba(colour)
    for i in range(frames):
        x0 = i * w
        bob = (i % 2) if anim in ("idle", "walk") else 0
        col = base
        inset_x, top = 2, 3
        if anim == "death":
            t = i / max(1, frames - 1)
            top = int(3 + (h - 5) * t)
            col = shade(base, 1.0 - 0.6 * t)
        elif anim in ("hurt",):
            col = shade(base, 1.6)
        elif anim in ("windup", "summon"):
            col = shade(base, 1.3 if i % 2 else 1.0)
            inset_x = 1
        elif anim == "attack":
            inset_x = 1
            col = shade(base, 1.2)
        elif anim == "dash":
            col = shade(base, 1.3)
        box = [x0 + inset_x, top + bob, x0 + w - 1 - inset_x, h - 2]
        if box[3] <= box[1]:
            box[1] = box[3] - 1
        d.ellipse(box, fill=col, outline=shade(col, 0.5))
        if anim != "death" or i < frames - 2:
            # "eye" on the right so you can see which way it faces
            ey = top + bob + max(2, (h - top) // 3)
            ex = x0 + w - 2 - inset_x - max(2, w // 6)
            d.rectangle([ex, ey, ex + max(1, w // 12), ey + max(1, h // 12)], fill=(255, 255, 255, 255))
        # frame number dots along the bottom edge
        for k in range(min(i + 1, w // 2)):
            img.putpixel((x0 + k * 2, h - 1), (255, 255, 255, 160))
    return img


def round_strip(size, frames, colour):
    w, h = size
    img = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = hex_rgba(colour)
    for i in range(frames):
        x0 = i * w
        inset = 1 + (i % 2)
        d.ellipse([x0 + inset, inset, x0 + w - 1 - inset, h - 1 - inset], fill=base, outline=shade(base, 0.6))
        d.point((x0 + w // 2 - 1, h // 2 - 1), fill=(255, 255, 255, 255))
    return img


def heart_img(mode):
    img = Image.new("RGBA", (9, 8), (0, 0, 0, 0))
    red, dark = hex_rgba("#e8424f"), hex_rgba("#5a1a22")
    for y, row in enumerate(HEART):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            filled = mode == "full" or (mode == "half" and x <= 4)
            img.putpixel((x, y), red if filled else dark)
    return img


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main():
    for key, (folder, size, anims, colour) in SPRITES.items():
        for anim, n in anims.items():
            save(f"{folder}/{key}_{anim}.png", character_strip(size, n, colour, anim))

    for key, (folder, size, anims, colour) in ROUND.items():
        for anim, n in anims.items():
            save(f"{folder}/{key}_{anim}.png", round_strip(size, n, colour))

    # heart pickup (8x8, 1 frame)
    hp = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    hp.paste(heart_img("full").crop((0, 0, 8, 8)), (0, 0))
    save("pickups/heart_idle.png", hp)

    # door 32x16: closed (bars) / open (dark gap)
    closed = Image.new("RGBA", (32, 16), hex_rgba("#7b5537"))
    d = ImageDraw.Draw(closed)
    d.rectangle([0, 0, 31, 15], outline=hex_rgba("#3d2a1b"))
    for x in range(4, 32, 6):
        d.line([x, 1, x, 14], fill=hex_rgba("#3d2a1b"))
    save("props/door_closed.png", closed)
    opened = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(opened)
    d.rectangle([0, 0, 31, 15], fill=hex_rgba("#1a1418"), outline=hex_rgba("#3d2a1b"))
    save("props/door_open.png", opened)

    # stairs 32x32, 4 frames (glow pulse)
    stairs = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(stairs)
    for i in range(4):
        x0 = i * 32
        d.rectangle([x0 + 2, 2, x0 + 29, 29], fill=hex_rgba("#141016"), outline=hex_rgba("#f2a65a", 120 + 40 * i))
        for k, y in enumerate(range(6, 28, 5)):
            d.rectangle([x0 + 5 + k * 2, y, x0 + 26 - k * 2, y + 2], fill=shade(hex_rgba("#6b6270"), 1.0 - k * 0.15))
    save("props/stairs_idle.png", stairs)

    # pedestal 16x24: full (2 frames, orb) / empty
    def pedestal(frames, orb):
        img = Image.new("RGBA", (16 * frames, 24), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for i in range(frames):
            x0 = i * 16
            d.rectangle([x0 + 3, 12, x0 + 12, 22], fill=hex_rgba("#7d7387"), outline=hex_rgba("#3a3340"))
            d.rectangle([x0 + 2, 10, x0 + 13, 12], fill=hex_rgba("#9a90a3"))
            if orb:
                r = 3 + (i % 2)
                d.ellipse([x0 + 8 - r, 6 - r, x0 + 7 + r, 5 + r], fill=hex_rgba("#e8424f"), outline=hex_rgba("#ffffff"))
        return img
    save("props/pedestal_full.png", pedestal(2, True))
    save("props/pedestal_empty.png", pedestal(1, False))

    # spawn marker 16x16, 3 frames (shrinking ring)
    marker = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(marker)
    for i in range(3):
        r = 7 - i * 2
        d.ellipse([i * 16 + 8 - r, 8 - r, i * 16 + 7 + r, 7 + r], outline=hex_rgba("#ff3c3c", 220))
    save("props/spawn_marker_idle.png", marker)

    # tiles 64x48 (4 x 3 tiles of 16)
    tiles = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(tiles)
    floor = hex_rgba("#2b2430")
    for i, k in enumerate([1.0, 1.08, 0.92, 1.0]):
        x0 = i * 16
        d.rectangle([x0, 0, x0 + 15, 15], fill=shade(floor, k))
        d.rectangle([x0, 0, x0 + 15, 15], outline=shade(floor, 0.8))
        if i == 2:
            d.line([x0 + 3, 4, x0 + 8, 9, x0 + 12, 8], fill=shade(floor, 0.6))
        if i == 3:
            d.rectangle([x0 + 6, 6, x0 + 9, 9], fill=shade(floor, 1.3))
    wall = hex_rgba("#4a3f52")
    d.rectangle([0, 16, 15, 31], fill=wall)
    d.line([0, 16, 15, 16], fill=shade(wall, 1.4))
    d.line([0, 24, 15, 24], fill=shade(wall, 0.7))
    d.rectangle([16, 16, 31, 31], fill=shade(wall, 0.9))
    d.rectangle([32, 16, 47, 31], fill=shade(wall, 0.8), outline=shade(wall, 1.3))
    d.rectangle([48, 16, 63, 31], fill=wall)
    d.line([48, 16, 48, 31], fill=shade(wall, 1.4))
    d.line([56, 16, 56, 31], fill=shade(wall, 0.7))
    d.ellipse([1, 34, 14, 46], fill=hex_rgba("#6b6270"), outline=hex_rgba("#3a3340"))
    d.rectangle([19, 32, 28, 47], fill=hex_rgba("#7d7387"), outline=hex_rgba("#3a3340"))
    d.rectangle([33, 33, 46, 46], fill=hex_rgba("#8a5a34"), outline=hex_rgba("#4a2f1b"))
    d.line([33, 33, 46, 46], fill=hex_rgba("#4a2f1b"))
    d.line([46, 33, 33, 46], fill=hex_rgba("#4a2f1b"))
    save("tiles/dungeon_tiles.png", tiles)

    # UI
    for mode in ("full", "half", "empty"):
        save(f"ui/heart_{mode}.png", heart_img(mode))
    ash = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(ash)
    d.polygon([(4, 0), (7, 4), (4, 7), (1, 4)], fill=hex_rgba("#f2a65a"), outline=hex_rgba("#8a4a1b"))
    save("ui/ash_icon.png", ash)
    cross = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    for k in (0, 1, 2, 6, 7, 8):
        cross.putpixel((4, k), (255, 255, 255, 255))
        cross.putpixel((k, 4), (255, 255, 255, 255))
    cross.putpixel((4, 4), (255, 80, 80, 255))
    save("ui/crosshair.png", cross)
    logo = Image.new("RGBA", (240, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(logo)
    d.text((120, 30), "ASHBORN", fill=hex_rgba("#f2a65a"), font=font(36), anchor="mm")
    save("ui/logo.png", logo)
    for uid, (letter, colour) in UPGRADE_ICONS.items():
        icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(icon)
        d.rectangle([0, 0, 15, 15], fill=shade(hex_rgba(colour), 0.45), outline=hex_rgba(colour))
        d.text((8, 8), letter, fill=hex_rgba(colour), font=font(11), anchor="mm")
        save(f"ui/icons/{uid}.png", icon)


if __name__ == "__main__":
    main()
