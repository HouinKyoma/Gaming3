"""Builds the game's art from 0x72's "16x16 DungeonTileset II" (CC0, https://0x72.itch.io/dungeontileset-ii).

Usage (from the project folder, needs: pip install pillow):
    python tools/import_0x72.py path/to/0x72_DungeonTilesetII_v1.7/frames

Unlike make_placeholders.py this OVERWRITES the images it produces. Files it does not
produce (bullets, crosshair, logo) are left alone. Animations the pack does not have
(death, windup, attack...) are generated from the pack's own frames (tinted / faded).
Frame sizes written here must match art/art_spec.gd.
"""
import os
import sys
import glob
from PIL import Image, ImageEnhance

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
FRAMES = sys.argv[1] if len(sys.argv) > 1 else "frames"


def load(name):
    return Image.open(os.path.join(FRAMES, name + ".png")).convert("RGBA")


def anim(prefix):
    files = sorted(glob.glob(os.path.join(FRAMES, prefix + "_f*.png")),
                   key=lambda p: int(p.rsplit("_f", 1)[1].split(".")[0]))
    if not files:
        raise SystemExit("missing frames for " + prefix)
    return [Image.open(f).convert("RGBA") for f in files]


def fit(img, size, anchor="bottom"):
    """Place img centred (horizontally) on a transparent canvas of `size`, bottom- or centre-aligned."""
    w, h = size
    if img.width > w or img.height > h:
        scale = min(w / img.width, h / img.height)
        img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.NEAREST)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (w - img.width) // 2
    y = h - img.height if anchor == "bottom" else (h - img.height) // 2
    out.paste(img, (x, y), img)
    return out


def strip(frames, size, anchor="bottom"):
    out = Image.new("RGBA", (size[0] * len(frames), size[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(fit(f, size, anchor), (i * size[0], 0))
    return out


def tint(img, rgb, amount):
    r, g, b, a = img.split()
    overlay = Image.new("RGBA", img.size, rgb + (255,))
    mixed = Image.blend(img, overlay, amount)
    mixed.putalpha(a)
    return mixed


def brighten(img, k):
    rgb = ImageEnhance.Brightness(img.convert("RGB")).enhance(k).convert("RGBA")
    rgb.putalpha(img.split()[3])
    return rgb


def death_frames(base, n):
    """Sinks, darkens and fades the sprite over n frames."""
    frames = []
    for i in range(n):
        t = i / max(1, n - 1)
        h = max(1, int(base.height * (1.0 - 0.75 * t)))
        squashed = base.resize((base.width + int(4 * t), h), Image.NEAREST)
        f = tint(squashed, (60, 20, 30), 0.25 + 0.5 * t)
        alpha = f.split()[3].point(lambda v: int(v * (1.0 - 0.85 * t)))
        f.putalpha(alpha)
        frames.append(f)
    return frames


def save(rel, img):
    path = os.path.join(ART, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("write", rel, img.size)


def character(key, folder, src, size, extra):
    idle = anim(src + "_idle_anim")
    run = anim(src + "_run_anim")
    save(f"{folder}/{key}_idle.png", strip(idle, size))
    save(f"{folder}/{key}_walk.png", strip(run, size))
    save(f"{folder}/{key}_death.png", strip(death_frames(idle[0], extra.get("death", 5)), size))
    if "attack" in extra:
        frames, rgb, amt = extra["attack"]
        src_frames = run if frames == "run" else idle
        save(f"{folder}/{key}_attack.png", strip([tint(f, rgb, amt) for f in src_frames], size))
    if "windup" in extra:
        rgb = extra["windup"]
        save(f"{folder}/{key}_windup.png", strip([tint(idle[0], rgb, 0.15), tint(idle[0], rgb, 0.55)], size))
    if "summon" in extra:
        save(f"{folder}/{key}_summon.png", strip([tint(f, (150, 80, 220), 0.45) for f in idle], size))
    if "hurt" in extra:
        save(f"{folder}/{key}_hurt.png", strip([brighten(idle[0], 1.8)], size))


def main():
    # --- Characters --------------------------------------------------------------
    knight_idle = anim("knight_m_idle_anim")
    knight_run = anim("knight_m_run_anim")
    knight_hit = anim("knight_m_hit_anim")
    P = (16, 28)
    save("player/player_idle.png", strip(knight_idle, P))
    save("player/player_walk.png", strip(knight_run, P))
    save("player/player_dash.png", strip([brighten(f, 1.5) for f in knight_run[:3]], P))
    save("player/player_hurt.png", strip([knight_hit[0], brighten(knight_hit[0], 1.8)], P))
    save("player/player_death.png", strip(death_frames(knight_idle[0], 6), P))

    character("crawler", "enemies/crawler", "goblin", (16, 16), {"death": 4})
    character("swarmer", "enemies/swarmer", "imp", (16, 16), {"death": 3})
    character("spitter", "enemies/spitter", "orc_shaman", (16, 24),
              {"death": 4, "attack": ("idle", (120, 255, 120), 0.45)})
    character("charger", "enemies/charger", "chort", (16, 24),
              {"death": 5, "windup": (255, 60, 40), "attack": ("run", (255, 120, 60), 0.3)})
    character("warden", "enemies/warden", "big_demon", (32, 36),
              {"death": 8, "windup": (255, 230, 120), "attack": ("run", (255, 80, 40), 0.35),
               "summon": True, "hurt": True})

    # --- Pickups -------------------------------------------------------------------
    save("pickups/ash_idle.png", strip(anim("coin_anim"), (8, 8), "center"))
    save("pickups/heart_idle.png", strip([load("ui_heart_full")], (13, 12), "center"))

    # --- Props ---------------------------------------------------------------------
    closed, opened = load("doors_leaf_closed"), load("doors_leaf_open")
    save("props/door_closed.png", closed.crop((0, 10, 32, 26)))
    save("props/door_open.png", opened.crop((0, 10, 32, 26)))
    save("props/stairs_idle.png", strip([load("floor_stairs")], (16, 16)))
    save("props/pedestal_full.png", strip([anim("chest_full_open_anim")[0]], (16, 16)))
    save("props/pedestal_empty.png", strip([anim("chest_empty_open_anim")[-1]], (16, 16)))
    save("props/spawn_marker_idle.png", strip(anim("floor_spikes_anim"), (16, 16)))

    # --- Tile sheet (4 x 3 tiles of 16; positions are fixed, see scenes/rooms/room.gd) ---
    sheet = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    layout = {
        (0, 0): load("floor_1"), (1, 0): load("floor_5"), (2, 0): load("floor_2"), (3, 0): load("floor_7"),
        (0, 1): load("wall_mid"), (1, 1): load("wall_top_mid"), (2, 1): load("wall_mid"), (3, 1): load("wall_mid"),
        (0, 2): load("hole"), (1, 2): load("wall_mid"), (2, 2): load("crate").crop((0, 8, 16, 24)),
        (3, 2): load("floor_6"),
    }
    for (cx, cy), tile in layout.items():
        sheet.paste(tile, (cx * 16, cy * 16), tile)
    save("tiles/dungeon_tiles.png", sheet)

    # --- UI ------------------------------------------------------------------------
    for mode in ("full", "half", "empty"):
        save(f"ui/heart_{mode}.png", load(f"ui_heart_{mode}"))
    save("ui/ash_icon.png", fit(anim("coin_anim")[0], (8, 8), "center"))

    icons = {
        "unlock_dash": "flask_blue", "vitality": "ui_heart_full", "power": "weapon_red_gem_sword",
        "rapid_fire": "weapon_arrow", "swiftness": "flask_green", "greed": "coin_anim_f0",
        "piercing": "weapon_spear", "second_wind": "flask_big_red",
        "boon_quick_hands": "weapon_knife", "boon_heavy_ash": "weapon_hammer",
        "boon_fleet_foot": "flask_big_green", "boon_hearty": "flask_red",
        "boon_lodestone": "flask_big_blue", "boon_ember_tithe": "flask_big_yellow",
        "boon_long_shot": "weapon_bow", "boon_thick_skin": "flask_yellow",
    }
    for uid, src in icons.items():
        img = load(src)
        if src == "coin_anim_f0":
            img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        save(f"ui/icons/{uid}.png", fit(img, (16, 16), "center"))


if __name__ == "__main__":
    main()
