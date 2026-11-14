class_name PlayerStats
extends Resource
## Every tunable player number. data/player_base.tres is the starting point;
## upgrades and boons modify a duplicate of it at the start of each run.

@export var max_hp: int = 6                 ## 2 HP = one heart
@export var move_speed: float = 90.0        ## px/s
@export var damage: float = 2.0
@export var fire_cooldown: float = 0.33     ## seconds between shots
@export var bullet_speed: float = 220.0
@export var bullet_lifetime: float = 0.8
@export var invuln_time: float = 0.8        ## i-frames after being hit
@export var magnet_radius: float = 24.0     ## pickups fly to you inside this radius
@export var ash_multiplier: float = 1.0
@export var can_dash: bool = false
@export var dash_speed: float = 320.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.9
@export var piercing: bool = false
@export var second_wind: bool = false
