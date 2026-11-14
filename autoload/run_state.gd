extends Node
## Autoload "Run": everything about the current run. All of it resets on start_new_run().
## Only end_run() passes anything on to Save.

var active := false
var floor_index := 0
var ash := 0
var kills := 0
var rooms_cleared := 0
var time := 0.0
var stats: PlayerStats
var current_hp := 0
var boons: Array[UpgradeData] = []
var second_wind_used := false
var rng := RandomNumberGenerator.new()
## Filled by end_run(); read by the death and victory screens.
var last_result: Dictionary = {}

var _ash_exact := 0.0

## "Bounce back" buff, per stack (stacks = Save.get_bounce(), +1 per death, max Save.BOUNCE_MAX).
const BOUNCE_DAMAGE := 0.10   ## +10% damage
const BOUNCE_SPEED := 0.03    ## +3% move speed
const BOUNCE_HP := 1          ## +1 HP (half a heart)


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.room_cleared.connect(_on_room_cleared)


func _process(delta: float) -> void:
	if active:
		time += delta


func start_new_run() -> void:
	active = true
	floor_index = 0
	ash = 0
	_ash_exact = 0.0
	kills = 0
	rooms_cleared = 0
	time = 0.0
	boons.clear()
	second_wind_used = false
	rng.randomize()
	rebuild_stats()
	current_hp = stats.max_hp


## Base stats + permanent upgrades (at their saved level) + this run's boons.
func rebuild_stats() -> void:
	stats = Content.player_base.duplicate() as PlayerStats   # never modify the .tres itself
	for up in Content.upgrades:
		up.apply(stats, Save.get_level(up.id))
	for boon in boons:
		boon.apply(stats, 1)
	var bounce := Save.get_bounce()
	stats.damage *= 1.0 + BOUNCE_DAMAGE * bounce
	stats.move_speed *= 1.0 + BOUNCE_SPEED * bounce
	stats.max_hp += BOUNCE_HP * bounce


## "Bounce x3: +30% damage, +9% speed, +1.5 hearts" (empty string at 0 stacks).
func bounce_text(stacks: int) -> String:
	if stacks <= 0:
		return ""
	var hearts := BOUNCE_HP * stacks / 2.0
	var hearts_text := str(int(hearts)) if is_equal_approx(hearts, roundf(hearts)) else "%.1f" % hearts
	return "Bounce x%d: +%d%% damage, +%d%% speed, +%s hearts" % [
			stacks, roundi(BOUNCE_DAMAGE * stacks * 100.0), roundi(BOUNCE_SPEED * stacks * 100.0), hearts_text]


func add_boon(boon: UpgradeData) -> void:
	var old_max := stats.max_hp
	boons.append(boon)
	rebuild_stats()
	current_hp += stats.max_hp - old_max   # gaining max HP also heals that much


func add_ash(amount: int) -> void:
	# Kept as a float so Greed's x1.2 still counts on 1-Ash pickups.
	var mult := stats.ash_multiplier if stats else 1.0
	_ash_exact += amount * mult
	ash = floori(_ash_exact)
	Events.run_ash_changed.emit(ash)


func end_run(won: bool, killer: String) -> void:
	if not active:
		return
	active = false
	last_result = {
		"won": won,
		"killer": killer,
		"ash": ash,
		"floor": floor_index + 1,
		"rooms": rooms_cleared,
		"kills": kills,
		"time": time,
	}
	var bounce_before := Save.get_bounce()
	Save.bank_run(ash, floor_index + 1, won, killer)
	last_result["bounce"] = Save.get_bounce()
	last_result["bounce_gained"] = Save.get_bounce() > bounce_before


func _on_enemy_killed(_data: EnemyData, _position: Vector2) -> void:
	kills += 1


func _on_room_cleared(_coord: Vector2i) -> void:
	rooms_cleared += 1
