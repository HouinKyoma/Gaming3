# Ashborn (working title)

A 2D top-down action roguelike for our game jam, made in **Godot 4.7** with GDScript.
You die, your Ash is banked, you buy permanent upgrades, and you go back down stronger.

## Running it
1. Open this folder in Godot 4.7 (Project Manager > Import > `project.godot`).
2. Let it import (first time only), then press **F5**.

**PRESS SPACE TO BOUNCE BACK** on the title screen starts a run. When you die, the same prompt appears: press Space and you are straight back in, with one more **Bounce** stack (+10% damage, +3% speed, +half a heart per stack, max 10, kept between sessions). The numbers are at the top of `autoload/run_state.gd` and `Save.BOUNCE_MAX`. The upgrade shop (the Threshold) is a button on the title and death screens.

**Floors and biomes:** 1 The Crypt (spikes), 2 The Ossuary (pits, boss: Bone Shaman), 3 The Warden's Hall (spikes and pits, boss: Hollow Warden), 4 The Ashen Throne (lava, final boss: Ashen Tyrant). Each `data/floors/*.tres` sets its tile sheet, tint, hazard chances, how often rooms are bigger than the screen, and `boss_id`.

**Rooms** come in five sizes (the camera follows you in the big ones). Most combat rooms are generated (`RoomTemplates.generate()`): pillar halls, rock clusters, inner walls, pit fields, rings, rivers with bridges, open arenas, plus the floor's hazards. Pits `O` block walking but not bullets, spikes `^` hurt while raised, lava `~` hurts (dash over it).

**Bosses** (`scenes/enemies/boss.gd` is the shared base; each attack is a short script):
- **Bone Shaman** (floor 2): blinks around, bouncing skull volleys, bone rain warning circles, aimed beams, curving skull storms.
- **Hollow Warden** (floor 3): ring bursts, bullet streams, bouncing orbs, chain charges, leap slams, cross / rotating beams, spirals, summons.
- **Ashen Tyrant** (floor 4): spirals, bullet walls with a gap, meteor rain, bouncing bombs, chain charges. At 0 HP it **bounces back** as **The Tyrant Reborn** with a new health bar: twin curving spirals, rotating beams, crushing walls from both sides, meteor storms, blink slams.
Every boss has an **intro** (camera zooms in, name card, Space skips) and **two stages**: the boss bar shows both segments, and when the first runs out the boss bounces back under a new name (Bone Shaman, Risen / The Warden Unchained / The Tyrant Reborn). Stage HP, names and intro subtitles are at the top of each boss script (`_boss_ready`).
Enemy bullets are drawn in code for contrast (pink with a dark outline and white core); green bullets bounce off walls, cyan ones curve. To use `art/projectiles/enemy_bullet_spin.png` instead, set `DRAW_ENEMY_BULLETS = false` in `scenes/projectiles/projectile.gd`. Red circles and lines are warnings: get out before they fill.

**Soft-lock safety:** every room checks itself 2-3 times a second: enemies stuck in walls or pits are moved out, the enemy counter is re-counted, and if you somehow leave the room you go through the door (or are put back). The exit / boss is always at least half the floor away from the start.

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

## Art credits
Sprites and tiles: **0x72, "16x16 DungeonTileset II"** (CC0), https://0x72.itch.io/dungeontileset-ii.
Rebuild them with `python tools/import_0x72.py <path to the pack's frames folder>`.
Bullets, crosshair, logo and all sounds/music are our own generated placeholders.

## Replacing the art
Everything you see is a placeholder at its **final path and size**. To put in real art, **overwrite the PNG with one that has the same name**. No code changes.

- Animated sprites are **horizontal strips**: frames left to right, no padding, transparent background.
- Keep the **frame size** listed in `art/art_spec.gd`. The number of frames is read from the image width, so you can draw more or fewer frames.
- Draw characters **facing right**, feet at the **bottom-centre** of the frame.
- Boss sprites: the Hollow Warden is Kronovi's Undead Executioner and the Bone Shaman is CreativeKind's Necromancer, imported by `python tools/import_bosses.py` (reads `Undead executioner.zip` and `Necromancer_creativekind-Sheet.png` from the project folder; it trims, aligns and outlines the frames and prints the sizes for `art/art_spec.gd`). The Warden summons the pack's spirits ("Lost Spirit", also on floor 3).
- Biome tile sheets: `art/tiles/biome_*.png` (8 x 3 tiles, layout at the top of `scenes/rooms/room.gd`), made by `python tools/make_biomes.py` from the 0x72 tiles. Overwrite these with real art when you have it.
- The Ashen Tyrant's placeholder (`art/enemies/tyrant/`, 64x72 frames) is the Warden recoloured red at double size. Overwrite those 7 PNGs with your own boss.
- Animation names are fixed: `idle`, `walk`, `attack`, `windup`, `dash`, `hurt`, `death`, `summon`.
- Tiles: `art/tiles/dungeon_tiles.png` is a 4×3 grid of 16×16 tiles. Keep each tile in its slot (see the top of `scenes/rooms/room.gd`).
- Deleted a placeholder by accident? Run `python tools/make_placeholders.py`. It only creates missing files.

## Exporting (Windows + itch.io Web)
1. In Godot: Editor > Manage Export Templates > Download and Install (once per machine).
2. Project > Export. Two presets are ready: **Windows Desktop** (single .exe in `build/windows/`) and **Web** (`build/web/`, thread support off so itch.io needs no special settings).
3. For itch.io: zip the contents of `build/web/`, upload it as an HTML game, and tick "This file will be played in the browser". Set the viewport to 960 × 540 or larger.

## Plan
The full design and build plan is in the claude.ai project "Game jam" (`plans/roguelike_plan_and_structure.md`).
