extends Camera2D
## Follows the player inside the current room (rooms can be bigger than the screen; a
## screen-sized room just doesn't scroll), with screen shake on Events.camera_shake_requested.

var target: Node2D

var _strength := 0.0
var _duration := 0.0
var _time_left := 0.0


func _ready() -> void:
	Events.camera_shake_requested.connect(shake)
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0


## Run calls this on every room change. `rect` is in world coordinates.
func set_bounds(rect: Rect2) -> void:
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)


## Jump straight to the target (no smoothing), e.g. after entering a room.
func snap() -> void:
	if target and is_instance_valid(target):
		global_position = target.global_position
	reset_smoothing()


func shake(strength: float, duration: float) -> void:
	var remaining := _strength * (_time_left / _duration) if _duration > 0.0 else 0.0
	if strength >= remaining:
		_strength = strength
		_duration = maxf(duration, 0.01)
		_time_left = _duration


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = target.global_position
	if _time_left > 0.0:
		_time_left -= delta
		var k := maxf(_time_left / _duration, 0.0)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * k
	else:
		offset = Vector2.ZERO
