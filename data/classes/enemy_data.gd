class_name EnemyData
extends Resource
## Tuning numbers for one enemy type. Visuals are NOT here: they live in res://art/.

@export var id: StringName
@export var display_name: String = "Enemy"   ## shown on the death screen ("Slain by")
@export var scene: PackedScene
@export var max_hp: int = 4
@export var move_speed: float = 40.0
@export var contact_damage: int = 1
@export var budget_cost: int = 1             ## how much of a room's budget it uses
@export var spawn_count: int = 1             ## 3 for swarmer packs
@export var ash_drop: int = 1                ## pickups rolled on death
@export_range(0.0, 1.0) var ash_chance: float = 1.0
@export_range(0.0, 1.0) var heart_chance: float = 0.08

@export_group("Attacks (optional)")
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 90.0
@export var projectile_damage: int = 1
@export var preferred_min_range: float = 80.0
@export var preferred_max_range: float = 120.0
@export var windup_time: float = 0.6
@export var charge_speed: float = 260.0
@export var charge_time: float = 0.4
