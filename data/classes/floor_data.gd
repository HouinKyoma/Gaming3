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
@export var clear_bonus_ash: int = 10         ## dropped when the exit room is cleared
