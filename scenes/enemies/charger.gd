extends Enemy
## Walks, stops and winds up (flashing), then charges in a straight line until it hits a wall.
## Briefly stunned afterwards: the moment to punish it.

enum State { WALK, WINDUP, CHARGE, RECOVER }

var state: State = State.WALK
var _state_left := 0.0
var _charge_dir := Vector2.RIGHT
var _charge_elapsed := 0.0


func _on_ready() -> void:
	_state_left = randf_range(1.5, 2.5)


func _behaviour(delta: float) -> Vector2:
	_state_left -= delta
	match state:
		State.WALK:
			if _state_left <= 0.0:
				_enter(State.WINDUP, data.windup_time)
				_charge_dir = dir_to_target()
				visual.flash(data.windup_time * 0.5)
				return Vector2.ZERO
			return dir_to_target() * data.move_speed
		State.WINDUP:
			if _state_left <= 0.0:
				_enter(State.CHARGE, data.charge_time)
				_charge_elapsed = 0.0
			return Vector2.ZERO
		State.CHARGE:
			_charge_elapsed += delta
			var hit_wall := _charge_elapsed > 0.08 and get_slide_collision_count() > 0
			if _state_left <= 0.0 or hit_wall:
				if hit_wall:
					Events.camera_shake_requested.emit(2.0, 0.1)
				_enter(State.RECOVER, 0.5)
				return Vector2.ZERO
			return _charge_dir * data.charge_speed
		State.RECOVER:
			if _state_left <= 0.0:
				_enter(State.WALK, randf_range(1.5, 2.5))
			return Vector2.ZERO
	return Vector2.ZERO


func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_state_left = duration


func _animate() -> void:
	match state:
		State.WINDUP:
			visual.play(EntityVisual.WINDUP)
			visual.face(_charge_dir.x)
		State.CHARGE:
			visual.play(EntityVisual.ATTACK)
			visual.face(_charge_dir.x)
		State.RECOVER:
			visual.play(EntityVisual.IDLE)
		_:
			super()
