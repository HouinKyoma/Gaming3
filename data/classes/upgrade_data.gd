class_name UpgradeData
extends Resource
## One permanent shop upgrade. Also usable as a run-only boon (leave costs empty).
## It changes one property on PlayerStats, chosen by name in `stat`.

enum Mode { ADD, MULTIPLY, ENABLE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Optional. If empty, res://art/ui/icons/<id>.png is used.
@export var icon: Texture2D
## Property name on PlayerStats, e.g. &"max_hp".
@export var stat: StringName
@export var mode: Mode = Mode.ADD
## ADD: added per level. MULTIPLY: 0.2 means x1.2 per level, -0.12 means x0.88 per level.
@export var value_per_level: float = 0.0
## One entry per level; the array size is the max level.
@export var costs: Array[int] = []
@export var sort_order: int = 0


func max_level() -> int:
	return costs.size()


## Cost of the next level, or -1 if already maxed.
func cost_for_next(current_level: int) -> int:
	if current_level >= costs.size():
		return -1
	return costs[current_level]


func get_icon() -> Texture2D:
	if icon:
		return icon
	var path := "res://art/ui/icons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Applies `level` levels of this upgrade to `stats` (a run's duplicate, never the .tres).
func apply(stats: PlayerStats, level: int) -> void:
	if level <= 0 or stat == &"":
		return
	if not (stat in stats):
		push_error("UpgradeData %s: PlayerStats has no property '%s'" % [id, stat])
		return
	var current: Variant = stats.get(stat)
	var result: Variant = current
	match mode:
		Mode.ADD:
			result = current + value_per_level * level
		Mode.MULTIPLY:
			result = current * pow(1.0 + value_per_level, level)
		Mode.ENABLE:
			result = true
	if typeof(current) == TYPE_INT:
		result = roundi(result)
	stats.set(stat, result)
