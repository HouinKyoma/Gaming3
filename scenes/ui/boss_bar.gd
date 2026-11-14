class_name BossBar
extends Control
## Boss health bar with one segment per stage. The current stage is the rightmost segment
## (it empties first); later stages sit to the left in their own colour, so you can SEE that the
## boss will come back. A white trail shows recent damage; the bar fills up during the intro.

const STAGE_COLORS := [Color("#d9443c"), Color("#9b4dff"), Color("#3dd6ff")]

var stage_hp: Array = [100]
var total := 100.0
var current := 100.0

var _shown := 0.0
var _trail := 0.0
var _flash := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 7)


## Called when a boss appears: the bar fills up from empty.
func start(stages: Array, p_total: int) -> void:
	stage_hp = stages if not stages.is_empty() else [p_total]
	total = maxf(1.0, float(p_total))
	current = total
	_shown = 0.0
	_trail = 0.0


func set_hp(value: int, p_total: int) -> void:
	total = maxf(1.0, float(p_total))
	current = clampf(float(value), 0.0, total)


func flash() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	if _shown < current:
		_shown = minf(current, _shown + total * delta / 1.4)   # filling up
	else:
		_shown = current
	_trail = maxf(_shown, move_toward(_trail, _shown, total * delta * 0.35))
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


## Stage i occupies [start, end] of the bar (0-1). Stage 0 is rightmost.
func _stage_span(i: int) -> Vector2:
	var later := 0.0
	for j in range(i + 1, stage_hp.size()):
		later += float(stage_hp[j])
	return Vector2(later / total, (later + float(stage_hp[i])) / total)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(0, 0, w, h), Color(0.12, 0.07, 0.1))
	for i in stage_hp.size():
		var span := _stage_span(i)
		var col: Color = STAGE_COLORS[i % STAGE_COLORS.size()]
		var x0 := span.x * w
		var x1 := span.y * w
		draw_rect(Rect2(x0, 0, x1 - x0, h), Color(col, 0.18))   # empty part, tinted: a stage still to come
		var trail_x := minf(x1, _trail / total * w)
		if trail_x > x0:
			draw_rect(Rect2(x0, 0, trail_x - x0, h), Color(1, 0.95, 0.9, 0.8))
		var fill_x := minf(x1, _shown / total * w)
		if fill_x > x0:
			var c := col.lightened(0.5 * _flash)
			draw_rect(Rect2(x0, 0, fill_x - x0, h), c)
			draw_rect(Rect2(x0, 0, fill_x - x0, 1), c.lightened(0.35))
	# Dividers between stages, with a little diamond
	for i in range(1, stage_hp.size()):
		var x := _stage_span(i).y * w
		draw_rect(Rect2(x - 1, -2, 2, h + 4), Color(0.05, 0, 0.05))
		draw_colored_polygon(PackedVector2Array([Vector2(x, -4), Vector2(x + 3, -1), Vector2(x, 2), Vector2(x - 3, -1)]), Color("#efe6d6"))
