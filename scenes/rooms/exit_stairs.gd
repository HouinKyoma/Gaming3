class_name ExitStairs
extends Area2D
## Appears when the exit room is cleared. Walking onto it goes to the next floor.

const ARM_DELAY := 0.6   # so you don't fall through the instant it appears

var _used := false
var _armed_in := ARM_DELAY


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)

	var visual := EntityVisual.new()
	visual.name = "Visual"
	visual.art_key = "stairs"
	visual.feet_origin = false
	add_child(visual)


func _physics_process(delta: float) -> void:
	if _used:
		return
	if _armed_in > 0.0:
		_armed_in -= delta
		return
	for body in get_overlapping_bodies():
		if body is Player:
			_used = true
			Events.floor_exit_reached.emit()
			return
