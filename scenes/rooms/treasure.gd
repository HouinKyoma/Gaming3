class_name Treasure
extends Area2D
## Pedestal in the treasure room. Fully heals the player once (only when they're hurt).
## Later: replace the heal with a boon choice.

signal used

var available := true

var _visual: EntityVisual


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)

	_visual = EntityVisual.new()
	_visual.name = "Visual"
	_visual.art_key = "pedestal"
	_visual.start_animation = EntityVisual.FULL if available else EntityVisual.EMPTY
	add_child(_visual)


func _physics_process(_delta: float) -> void:
	if not available:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and not player.is_dead and not player.health.is_full():
			player.heal_full()
			available = false
			_visual.play(EntityVisual.EMPTY)
			Events.camera_shake_requested.emit(1.5, 0.1)
			used.emit()
			return
