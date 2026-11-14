extends Enemy
## Small and fast. Chases with a sideways wobble so packs spread out.

var _phase := 0.0


func _on_ready() -> void:
	_phase = randf() * TAU


func _behaviour(_delta: float) -> Vector2:
	var wobble := sin(_time * 8.0 + _phase) * 0.6
	return dir_to_target().rotated(wobble) * data.move_speed
