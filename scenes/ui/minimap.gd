class_name Minimap
extends Control
## Small map in the HUD. Shows visited rooms, rooms next to them, and where you are.
## Reads the layout from the run scene (run.gd: layout, visited, cleared, current_coord).

const CELL := Vector2(7, 5)
const GAP := 1.0
const C_VISITED := Color(0.55, 0.5, 0.6)
const C_CLEARED := Color(0.42, 0.38, 0.46)
const C_UNKNOWN := Color(0.25, 0.22, 0.28)
const C_CURRENT := Color("#f2a65a")
const C_EXIT := Color("#5ad19a")
const C_BOSS := Color("#d9443c")
const C_TREASURE := Color("#e0c35a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.room_entered.connect(func(_c: Vector2i, _t: int) -> void: queue_redraw())
	Events.room_cleared.connect(func(_c: Vector2i) -> void: queue_redraw())
	Events.floor_started.connect(func(_i: int) -> void: queue_redraw())


func _draw() -> void:
	var run := get_tree().current_scene
	if run == null or not ("layout" in run):
		return
	var layout: Dictionary = run.get("layout")
	var visited: Dictionary = run.get("visited")
	var cleared: Dictionary = run.get("cleared")
	var current: Vector2i = run.get("current_coord")
	if layout.is_empty():
		return

	# Rooms worth drawing: visited ones and their neighbours.
	var shown: Dictionary = {}
	for c: Vector2i in visited:
		shown[c] = true
		for d: Vector2i in FloorGenerator.DIRS:
			if layout.has(c + d):
				shown[c + d] = true

	var origin := size / 2.0 - CELL / 2.0
	for c: Vector2i in shown:
		var rel := Vector2(c - current)
		var pos := origin + rel * (CELL + Vector2(GAP, GAP))
		var rect := Rect2(pos, CELL)
		if not Rect2(Vector2.ZERO, size).encloses(rect):
			continue
		var col := C_UNKNOWN
		if c == current:
			col = C_CURRENT
		elif visited.has(c):
			col = C_CLEARED if cleared.has(c) else C_VISITED
		draw_rect(rect, col)
		var room_kind := int(layout[c])
		var mark := Color(0, 0, 0, 0)
		match room_kind:
			FloorGenerator.RoomType.EXIT:
				mark = C_EXIT
			FloorGenerator.RoomType.BOSS:
				mark = C_BOSS
			FloorGenerator.RoomType.TREASURE:
				mark = C_TREASURE
		if mark.a > 0.0:
			draw_rect(Rect2(pos + CELL / 2.0 - Vector2(1.5, 1.5), Vector2(3, 3)), mark)
