extends Node
## Autoload "Save": everything that survives death and quitting.
## Stored as readable JSON in user://save.json
## (Windows: %APPDATA%\Ashborn\save.json, Web: browser IndexedDB).

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const VERSION := 1
## Most Bounce stacks you can hold (one is gained per death). See Run.rebuild_stats().
const BOUNCE_MAX := 10

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"ash": 0,
		"bounce": 0,
		"upgrades": {},
		"stats": {"runs": 0, "wins": 0, "best_floor": 0, "total_ash": 0, "deaths_by": {}},
		"settings": {"music": 0.8, "sfx": 1.0, "fullscreen": false},
	}


# --- Load / save ---------------------------------------------------------------

func load_game() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable; starting fresh.")
		return
	_merge(data, parsed)
	# Future format changes: migrate here when int(data["version"]) < VERSION.
	data["version"] = VERSION


## Copies values from `from` into `into`. Keys missing from an old save keep their default.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for key in from:
		if into.has(key) and into[key] is Dictionary and from[key] is Dictionary:
			_merge(into[key], from[key])
		else:
			into[key] = from[key]


func save_game() -> void:
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Write a temp file first, then replace the real one, so a crash can't leave half a save.
	var err := DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Could not finalise save: %s" % error_string(err))


func reset_save() -> void:
	data = _defaults()
	save_game()
	Events.meta_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Accessors (JSON numbers load as floats, so always convert to int) ----------

func get_ash() -> int:
	return int(data["ash"])


## Bounce stacks: +1 every time you die, kept forever (until the save is reset).
func get_bounce() -> int:
	return int(data.get("bounce", 0))


func get_level(id: StringName) -> int:
	var ups: Dictionary = data["upgrades"]
	return int(ups.get(String(id), 0))


func get_stat(key: String) -> int:
	var stats: Dictionary = data["stats"]
	return int(stats.get(key, 0))


# --- Spending and earning ---------------------------------------------------------

func try_buy(up: UpgradeData) -> bool:
	var level := get_level(up.id)
	var cost := up.cost_for_next(level)
	if cost < 0 or get_ash() < cost:
		return false
	data["ash"] = get_ash() - cost
	var ups: Dictionary = data["upgrades"]
	ups[String(up.id)] = level + 1
	save_game()
	Events.meta_changed.emit()
	return true


func bank_run(ash_earned: int, floor_reached: int, won: bool, killer: String) -> void:
	var stats: Dictionary = data["stats"]
	data["ash"] = get_ash() + ash_earned
	stats["runs"] = get_stat("runs") + 1
	stats["total_ash"] = get_stat("total_ash") + ash_earned
	stats["best_floor"] = maxi(get_stat("best_floor"), floor_reached)
	if won:
		stats["wins"] = get_stat("wins") + 1
	else:
		data["bounce"] = mini(get_bounce() + 1, BOUNCE_MAX)
	if not won and killer != "":
		var deaths: Dictionary = stats["deaths_by"]
		deaths[killer] = int(deaths.get(killer, 0)) + 1
	save_game()
	Events.meta_changed.emit()


func add_ash_debug(amount: int) -> void:
	data["ash"] = get_ash() + amount
	save_game()
	Events.meta_changed.emit()
