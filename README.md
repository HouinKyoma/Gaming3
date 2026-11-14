# Ashborn

A 2D top-down action roguelike for our game jam, made in **Godot 4.7** with GDScript.
You die, your Ash is banked, you buy permanent upgrades, and you go back down stronger.

## Running it
1. Open this folder in Godot 4.7 (Project Manager > Import > `project.godot`).
2. Let it import (first time only), then press **F5**.

**PRESS SPACE TO BOUNCE BACK** on the title screen starts a run. When you die, the same prompt appears: press Space and you are straight back in, with one more **Bounce** stack (+10% damage, +3% speed, +half a heart per stack, max 10, kept between sessions). The numbers are at the top of `autoload/run_state.gd` and `Save.BOUNCE_MAX`. The upgrade shop (the Threshold) is a button on the title and death screens.

**Floors and biomes:** 1 The Crypt (spikes), 2 The Ossuary (pits, boss: The Necromancer), 3 The Warden's Hall (spikes and pits, boss: The Hollow Reaper), 4 The Ashen Throne (lava, final boss: Ashen Tyrant). Floors are short (5-6 rooms) so a run moves fast. Each `data/floors/*.tres` sets its tile sheet, tint, hazard chances, how often rooms are bigger than the screen, and `boss_id`.

**Rooms** come in five sizes (the camera follows you in the big ones). Most combat rooms are generated (`RoomTemplates.generate()`): pillar halls, rock clusters, inner walls, pit fields, rings, rivers with bridges, open arenas, plus the floor's hazards. Pits `O` block walking but not bullets, spikes `^` hurt while raised, lava `~` hurts (dash over it).

**Bosses** (`scenes/enemies/boss.gd` is the shared base; each attack is a short script). Each boss has its own moveset, and they are meant to be hard (health is moderate, the patterns are not):
- **The Necromancer** (floor 2, `bone_shaman.gd`): strafes while firing homing soul bolts, bouncing bone barrages, graves that burst and raise spirits/goblins, curse pools, triple blinks, bone prison (ring of graves with one gap), death nova.
- **The Hollow Reaper** (floor 3, `warden.gd`): all scythe, scythe hits take a full heart. Rushes in for sweep combos that fling blade shards, throws 3-5 boomerang scythes, dash + spin chains, a whirlwind that sprays bullets, soul waves, and "execution" (appears next to you and spins: dash out).
- **The Ashen Tyrant** (floor 4, `tyrant.gd`): a fire demon. Turning fire breath that sprays embers, meteor storms (full heart), lava pools with heavy fireballs, wall-slam charges, bouncing heavy fireballs, fire walls, ring eruptions, imps. At 0 HP it **bounces back** as **The Tyrant Reborn**.
Hazard types in `boss_hazard.gd`: `circle`, `beam`, `arc` (scythe sweep / breath), `zone` (lava / curse puddle), `scythe` (boomerang).
**Bullet colours:** pink = normal (half a heart), green = bounces off walls, cyan = curves, purple = homing, **big red-orange with a yellow ring = HEAVY (a full heart)**. Helpers: `make_heavy()`, `heavy_shot()`, `heavy_bouncer()`, `make_bouncy()`, `homing_shot()`.
Every boss has an **intro** (camera zooms in, name card, Space skips) and **two stages**: the boss bar shows both segments, and when the first runs out the boss bounces back under a new name (The Necromancer, Undying / The Reaper Unbound / The Tyrant Reborn). Stage HP, names and intro subtitles are at the top of each boss script (`_boss_ready`).
Enemy bullets are drawn in code for contrast (see the bullet colours above). To use `art/projectiles/enemy_bullet_spin.png` instead, set `DRAW_ENEMY_BULLETS = false` in `scenes/projectiles/projectile.gd`. Red circles and lines are warnings: get out before they fill.

**Soft-lock safety:** every room checks itself 2-3 times a second: enemies stuck in walls or pits are moved out, the enemy counter is re-counted, and if you somehow leave the room you go through the door (or are put back). The exit / boss is always at least half the floor away from the start. Doors only fire when the player is really standing in them and not in the first 0.2 s after entering a room (all rooms share one position, so otherwise the same-side door of the next room could catch the player and skip a room).

**Controls:** WASD move · mouse aims · hold left mouse to shoot · Space / right mouse to dash (after you buy Ember Dash) · Esc to pause.

**Admin keys** (work in every build, including the itch.io export): F1 +100 Ash · F2 kill all enemies · F3 skip to next floor · F4 god mode · F5 reset save. The title screen also has a **Reset save** button. To hide all of them from players, set `ADMIN_CONTROLS = false` at the admin-keys section of `autoload/game.gd`.

## How the game is put together
| Folder | What's in it |
|---|---|
| `autoload/` | Global singletons: `Events` (signals), `Content` (data lists), `Save` (persistent), `Run` (current run), `Game` (scene switching, input, admin keys) |
| `data/` | All balance numbers as `.tres` files: player base stats, upgrades, enemies, floors. Tune here, not in code. |
| `scenes/` | Player, enemies, projectiles, pickups, rooms, the run scene and the menus |
| `art/` | **The only folder artists touch.** Every image the game uses. |
| `audio/` | Sound effects (`sfx/`) and music loops (`music/`), loaded by file name |
| `tools/` | Python scripts that import the art packs and generate placeholder art / sounds |
| `source_assets/` | The original art downloads (zips, sprite sheets). Ignored by Godot, not exported. |
| `unused/` | Leftover files the game doesn't use, kept instead of deleted. Ignored by Godot. |

- **Treasure rooms** have a chest: walk into it (any HP, no dash needed) to get a random run item plus a full heal; a popup shows what you got (`scenes/rooms/treasure.gd`, `scenes/ui/item_popup.gd`).
- **Rooms** are generated per floor (`scenes/run/floor_generator.gd`) and built from text layouts in `scenes/rooms/room_templates.gd`. To add a room layout, copy one and edit the characters.
- **Adding an enemy:** make a scene in `scenes/enemies/` (copy `crawler.tscn` + a script that `extends Enemy`), a `.tres` in `data/enemies/`, add its path to `autoload/content.gd`, and its id to a floor's `enemy_pool`.
- **Boons** (pick 1 of 3 between floors, lost on death) are `UpgradeData` files with no costs in `data/boons/`, listed in `autoload/content.gd`.
- **Sounds:** `Audio.play_sfx("name")` plays `audio/sfx/name.wav`. To replace a sound, overwrite the file. Music loops are in `audio/music/`: `menu_loop` (title / menus), `hall_loop` (ambient music in the halls of a run; `run_loop` is its fallback), `boss_theme` (Necromancer and Tyrant), `boss_reaper` (Hollow Reaper), `boss_loop` (fallback). Which boss uses which track is `BOSS_MUSIC` at the top of `autoload/audio.gd`.
- **Adding an upgrade:** a `.tres` in `data/upgrades/` (stat name on `PlayerStats` + mode + costs), its path in `autoload/content.gd`, and an icon at `art/ui/icons/<id>.png`.

## Credits
Made by Erkhem and Erdembileg (game) and Enkhtuvshin (music). The full list of third-party assets is in `CREDITS.md` and in the game (title screen > **Credits**); edit `CREDITS` in `scenes/ui/credits_panel.gd` when it changes.
Rebuild the 0x72 sprites with `python tools/import_0x72.py <path to the pack's frames folder>`.

## Replacing the art
Everything you see is a placeholder at its **final path and size**. To put in real art, **overwrite the PNG with one that has the same name**. No code changes.

- Animated sprites are **horizontal strips**: frames left to right, no padding, transparent background.
- Keep the **frame size** listed in `art/art_spec.gd`. The number of frames is read from the image width, so you can draw more or fewer frames.
- Draw characters **facing right**, feet at the **bottom-centre** of the frame.
- Boss sprites: the Hollow Reaper is Kronovi's Undead Executioner and the Necromancer is CreativeKind's Necromancer, imported by `python tools/import_bosses.py` (reads `Undead executioner.zip` and `Necromancer_creativekind-Sheet.png` from `source_assets/`; it trims, aligns and outlines the frames and prints the sizes for `art/art_spec.gd`). The Necromancer raises the pack's spirits ("Lost Spirit", also on floor 3).
- Biome tile sheets: `art/tiles/biome_*.png` (8 x 3 tiles, layout at the top of `scenes/rooms/room.gd`), made by `python tools/make_biomes.py` from the 0x72 tiles. Overwrite these with real art when you have it.
- The Ashen Tyrant (`art/enemies/tyrant/`, 64x72 frames) is 0x72's big demon (CC0) at double size. Overwrite those 7 PNGs to change it.
- Animation names are fixed: `idle`, `walk`, `attack`, `windup`, `dash`, `hurt`, `death`, `summon`.
- Tiles: `art/tiles/dungeon_tiles.png` is a 4×3 grid of 16×16 tiles. Keep each tile in its slot (see the top of `scenes/rooms/room.gd`).
- Deleted a placeholder by accident? Run `python tools/make_placeholders.py`. It only creates missing files.

## Exporting (Windows + itch.io Web)
1. In Godot: Editor > Manage Export Templates > Download and Install (once per machine).
2. Project > Export. Two presets are ready: **Windows Desktop** (single .exe in `build/windows/`) and **Web** (`build/web/`, thread support off so itch.io needs no special settings).
3. Untick **Export With Debug** when exporting (the admin keys still work; it just makes the build smaller and faster).
4. For itch.io: zip the contents of `build/web/` (so `index.html` is at the top of the zip), upload it as an HTML game, and tick "This file will be played in the browser". Set the viewport to 960 × 540 and turn on the fullscreen button. Upload the zipped `build/windows/Ashborn.exe` too, as a Windows download.

## Plan
The full design and build plan is in the claude.ai project "Game jam" (`plans/roguelike_plan_and_structure.md`).
