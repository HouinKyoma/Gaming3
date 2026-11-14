extends Camera2D
## Fixed camera over the room, with screen shake on Events.camera_shake_requested.

var _strength := 0.0
var _duration := 0.0
var _time_left := 0.0


func _ready() -> void:
	Events.camera_shake_requested.connect(shake)


func shake(strength: float, duration: float) -> void:
	var remaining := _strength * (_time_left / _duration) if _duration > 0.0 else 0.0
	if strength >= remaining:
		_strength = strength
		_duration = maxf(duration, 0.01)
		_time_left = _duration


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		var k := maxf(_time_left / _duration, 0.0)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * k
	else:
		offset = Vector2.ZERO
