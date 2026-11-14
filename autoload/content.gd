extends Node
## Autoload "Content": every data resource the game uses, loaded once.
## To add an upgrade, enemy or floor: create the .tres (right-click > New Resource),
## then add its path to the matching list below.

const PLAYER_BASE_PATH := "res://data/player_base.tres"

const UPGRADE_PATHS := [
	"res://data/upgrades/unlock_dash.tres",
	"res://data/upgrades/vitality.tres",
	"res://data/upgrades/power.tres",
	"res://data/upgrades/rapid_fire.tres",
	"res://data/upgrades/swiftness.tres",
	"res://data/upgrades/greed.tres",
	"res://data/upgrades/piercing.tres",
	"res://data/upgrades/second_wind.tres",
]

const ENEMY_PATHS := [
	"res://data/enemies/crawler.tres",
	"res://data/enemies/swarmer.tres",
	"res://data/enemies/spitter.tres",
	"res://data/enemies/charger.tres",
	"res://data/enemies/warden.tres",
	"res://data/enemies/tyrant.tres",
	"res://data/enemies/bone_shaman.tres",
	"res://data/enemies/spirit.tres",
]

const FLOOR_PATHS := [
	"res://data/floors/floor_1.tres",
	"res://data/floors/floor_2.tres",
	"res://data/floors/floor_3.tres",
	"res://data/floors/floor_4.tres",
]

## Run-only boons offered between floors (UpgradeData with no costs).
const BOON_PATHS := [
	"res://data/boons/boon_quick_hands.tres",
	"res://data/boons/boon_heavy_ash.tres",
	"res://data/boons/boon_fleet_foot.tres",
	"res://data/boons/boon_hearty.tres",
	"res://data/boons/boon_lodestone.tres",
	"res://data/boons/boon_ember_tithe.tres",
	"res://data/boons/boon_long_shot.tres",
	"res://data/boons/boon_thick_skin.tres",
]

## Default boss. Each floor picks its own with FloorData.boss_id.
const BOSS_ID := "warden"

var player_base: PlayerStats
var upgrades: Array[UpgradeData] = []
var boons: Array[UpgradeData] = []
var enemies: Dictionary = {}          # String id -> EnemyData
var floors: Array[FloorData] = []


func _ready() -> void:
	player_base = load(PLAYER_BASE_PATH) as PlayerStats
	if player_base == null:
		push_error("Content: could not load %s" % PLAYER_BASE_PATH)
		player_base = PlayerStats.new()

	for path in UPGRADE_PATHS:
		var up := load(path) as UpgradeData
		if up:
			upgrades.append(up)
		else:
			push_error("Content: could not load upgrade %s" % path)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.sort_order < b.sort_order)

	for path in BOON_PATHS:
		var boon := load(path) as UpgradeData
		if boon:
			boons.append(boon)
		else:
			push_error("Content: could not load boon %s" % path)

	for path in ENEMY_PATHS:
		var enemy := load(path) as EnemyData
		if enemy:
			enemies[String(enemy.id)] = enemy
		else:
			push_error("Content: could not load enemy %s" % path)

	for path in FLOOR_PATHS:
		var fd := load(path) as FloorData
		if fd:
			floors.append(fd)
		else:
			push_error("Content: could not load floor %s" % path)


func get_enemy(id: String) -> EnemyData:
	return enemies.get(id) as EnemyData


func get_upgrade(id: StringName) -> UpgradeData:
	for up in upgrades:
		if up.id == id:
			return up
	return null
