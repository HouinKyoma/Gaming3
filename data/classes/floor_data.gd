class_name FloorData
extends Resource
## Settings for one floor of a run.

@export var display_name: String = "Floor 1"
@export var room_count: int = 7               ## including start and exit/boss
@export var combat_budget: int = 4            ## spent on enemies in each combat room
## Enemy ids (EnemyData.id) that can appear on this floor.
@export var enemy_pool: PackedStringArray = PackedStringArray()
@export var hp_multiplier: float = 1.0
@export var is_boss_floor: bool = false
## EnemyData.id of the boss in this floor's boss room (only used when is_boss_floor).
@export var boss_id: String = "warden"
@export var clear_bonus_ash: int = 10         ## dropped when the exit room is cleared

@export_group("Biome")
## Tile sheet for this floor (see the top of scenes/rooms/room.gd for the layout).
@export_file("*.png") var tiles_path: String = "res://art/tiles/dungeon_tiles.png"
## Colour the whole dungeon is tinted with (CanvasModulate). White = no tint.
@export var ambient: Color = Color.WHITE
## Chance (0-1) that a room gets pits / spikes / lava, and that a combat room is bigger than the screen.
@export_range(0.0, 1.0) var pit_chance: float = 0.2
@export_range(0.0, 1.0) var spike_chance: float = 0.2
@export_range(0.0, 1.0) var lava_chance: float = 0.0
@export_range(0.0, 1.0) var big_room_chance: float = 0.35
