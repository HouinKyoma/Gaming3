class_name ArtSpec
extends RefCounted
## THE ART LIST. Every animated sprite in the game is described here.
##
## For each entry the game loads   res://art/<folder>/<key>_<animation>.png
## Each PNG is a HORIZONTAL STRIP: frames left to right, no padding, transparent background.
##   size  = the size of ONE frame in pixels (keep this when you redraw).
##   The number of frames is read from the PNG: frame count = PNG width / frame width.
##   So you can draw more or fewer frames without changing any code.
##   anims = animation name -> [frames per second, loops?]
## Draw characters facing RIGHT with their feet at the bottom-centre of the frame.
##
## Current art: 0x72 "16x16 DungeonTileset II" (CC0), built by tools/import_0x72.py.
## Sizes below match that pack. If you redraw at another size, change it here.

const SPRITES := {
	# --- Characters ------------------------------------------------------------
	"player": {"folder": "player", "size": Vector2i(16, 28), "anims": {
		"idle": [6, true], "walk": [10, true], "dash": [16, true],
		"hurt": [12, false], "death": [10, false]}},
	"crawler": {"folder": "enemies/crawler", "size": Vector2i(16, 16), "anims": {
		"idle": [4, true], "walk": [8, true], "death": [12, false]}},
	"swarmer": {"folder": "enemies/swarmer", "size": Vector2i(16, 16), "anims": {
		"idle": [6, true], "walk": [12, true], "death": [12, false]}},
	"spitter": {"folder": "enemies/spitter", "size": Vector2i(16, 24), "anims": {
		"idle": [4, true], "walk": [8, true], "attack": [10, false], "death": [12, false]}},
	"charger": {"folder": "enemies/charger", "size": Vector2i(16, 24), "anims": {
		"idle": [4, true], "walk": [8, true], "windup": [8, true], "attack": [12, true],
		"death": [12, false]}},
	"warden": {"folder": "enemies/warden", "size": Vector2i(32, 36), "anims": {
		"idle": [6, true], "walk": [6, true], "windup": [8, true], "attack": [10, false],
		"summon": [8, false], "hurt": [10, false], "death": [10, false]}},

	# Floor 2 boss. Placeholder = the Spitter (0x72 orc shaman) bleached to bone at 2x size.
	"bone_shaman": {"folder": "enemies/bone_shaman", "size": Vector2i(32, 48), "anims": {
		"idle": [6, true], "walk": [8, true], "windup": [8, true], "attack": [10, false],
		"summon": [8, false], "hurt": [10, false], "death": [10, false]}},
	# Final boss. Placeholder = the Warden recoloured red at 2x size (tools not needed, just overwrite).
	"tyrant": {"folder": "enemies/tyrant", "size": Vector2i(64, 72), "anims": {
		"idle": [6, true], "walk": [6, true], "windup": [8, true], "attack": [10, false],
		"summon": [8, false], "hurt": [10, false], "death": [10, false]}},

	# --- Projectiles and pickups -------------------------------------------------
	"player_bullet": {"folder": "projectiles", "size": Vector2i(8, 8), "anims": {
		"spin": [12, true]}},
	"enemy_bullet": {"folder": "projectiles", "size": Vector2i(8, 8), "anims": {
		"spin": [12, true]}},
	"ash": {"folder": "pickups", "size": Vector2i(8, 8), "anims": {"idle": [8, true]}},
	"heart": {"folder": "pickups", "size": Vector2i(13, 12), "anims": {"idle": [1, true]}},

	# --- Props -----------------------------------------------------------------------
	"door": {"folder": "props", "size": Vector2i(32, 16), "anims": {
		"closed": [1, true], "open": [1, true]}},
	"stairs": {"folder": "props", "size": Vector2i(16, 16), "anims": {"idle": [4, true]}},
	"pedestal": {"folder": "props", "size": Vector2i(16, 16), "anims": {
		"full": [4, true], "empty": [1, true]}},
	"spawn_marker": {"folder": "props", "size": Vector2i(16, 16), "anims": {"idle": [10, true]}},
}

## Non-animated images, loaded by path:
##   res://art/tiles/dungeon_tiles.png   64x48, a 4x3 grid of 16x16 tiles (see room.gd for which is which)
##   res://art/ui/heart_full.png, heart_half.png, heart_empty.png   13x12
##   res://art/ui/ash_icon.png   8x8        res://art/ui/crosshair.png   9x9
##   res://art/ui/logo.png   240x60         res://art/ui/icons/<upgrade_id>.png   16x16


static func get_spec(key: String) -> Dictionary:
	if SPRITES.has(key):
		return SPRITES[key]
	return {}


static func frame_size(key: String) -> Vector2i:
	var spec := get_spec(key)
	if spec.is_empty():
		return Vector2i(16, 16)
	return spec["size"]
