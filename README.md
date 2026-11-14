# Ashborn (working title)

A 2D top-down action roguelike for our game jam, made in **Godot 4.7** with GDScript.
You die, your Ash is banked, you buy permanent upgrades, and you go back down stronger.

## Running it
1. Open this folder in Godot 4.7 (Project Manager > Import > `project.godot`).
2. Let it import (first time only), then press **F5**.

First launch goes straight into a run. After that, Play opens the upgrade shop (the Threshold).

**Controls:** WASD move · mouse aims · hold left mouse to shoot · Space / right mouse to dash (after you buy Ember Dash) · Esc to pause.

**Debug keys** (only when run from the editor): F1 +100 Ash · F2 kill all enemies · F3 skip to next floor · F4 god mode · F5 reset save.

## How the game is put together
| Folder | What's in it |
|---|---|
| `autoload/` | Global singletons: `Events` (signals), `Content` (data lists), `Save` (persistent), `Run` (current run), `Game` (scene switching, input, debug keys) |
| `data/` | All balance numbers as `.tres` files: player base stats, upgrades, enemies, floors. Tune here, not in code. |
| `scenes/` | Player, enemies, projectiles, pickups, rooms, the run scene and the menus |
| `art/` | **The only folder artists touch.** Every image the game uses. |
| `audio/` | Sound effects (`sfx/`) and music loops (`music/`), loaded by file name |
| `tools/` | `make_placeholders.py` and `make_sounds.py` (create any missing placeholder art / sounds) |

- **Rooms** are generated per floor (`scenes/run/floor_generator.gd`) and built from text layouts in `scenes/rooms/room_templates.gd`. To add a room layout, copy one and edit the characters.
- **Adding an enemy:** make a scene in `scenes/enemies/` (copy `crawler.tscn` + a script that `extends Enemy`), a `.tres` in `data/enemies/`, add its path to `autoload/content.gd`, and its id to a floor's `enemy_pool`.
- **Boons** (pick 1 of 3 between floors, lost on death) are `UpgradeData` files with no costs in `data/boons/`, listed in `autoload/content.gd`.
- **Sounds:** `Audio.play_sfx("name")` plays `audio/sfx/name.wav`. To replace a sound, overwrite the file. Music loops are `menu_loop`, `run_loop` and `boss_loop` in `audio/music/`.
- **Adding an upgrade:** a `.tres` in `data/upgrades/` (stat name on `PlayerStats` + mode + costs), its path in `autoload/content.gd`, and an icon at `art/ui/icons/<id>.png`.

## Replacing the art (all art must be our own)
Everything you see is a placeholder at its **final path and size**. To put in real art, **overwrite the PNG with one that has the same name**. No code changes.

- Animated sprites are **horizontal strips**: frames left to right, no padding, transparent background.
- Keep the **frame size** listed in `art/art_spec.gd`. The number of frames is read from the image width, so you can draw more or fewer frames.
- Draw characters **facing right**, feet at the **bottom-centre** of the frame.
- Animation names are fixed: `idle`, `walk`, `attack`, `windup`, `dash`, `hurt`, `death`, `summon`.
- Tiles: `art/tiles/dungeon_tiles.png` is a 4×3 grid of 16×16 tiles. Keep each tile in its slot (see the top of `scenes/rooms/room.gd`).
- Deleted a placeholder by accident? Run `python tools/make_placeholders.py`. It only creates missing files.

## Exporting (Windows + itch.io Web)
1. In Godot: Editor > Manage Export Templates > Download and Install (once per machine).
2. Project > Export. Two presets are ready: **Windows Desktop** (single .exe in `build/windows/`) and **Web** (`build/web/`, thread support off so itch.io needs no special settings).
3. For itch.io: zip the contents of `build/web/`, upload it as an HTML game, and tick "This file will be played in the browser". Set the viewport to 960 × 540 or larger.

## Plan
The full design and build plan is in the claude.ai project "Game jam" (`plans/roguelike_plan_and_structure.md`).
