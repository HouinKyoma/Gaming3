extends Enemy
## Keeps its distance and fires a slow bullet. Plays "attack" for 0.3 s before firing.

const TELEGRAPH := 0.3

var _attack_cd := 0.0
var _telegraph_left := 0.0
var _strafe_sign := 1.0


func _on_ready() -> void:
	_attack_cd = randf_range(0.8, data.attack_cooldown)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0


func _behaviour(delta: float) -> Vector2:
	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		if _telegraph_left <= 0.0:
			shoot_at(dir_to_target(), data.projectile_speed, data.projectile_damage)
		return Vector2.ZERO

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_attack_cd = data.attack_cooldown
		_telegraph_left = TELEGRAPH
		return Vector2.ZERO

	var dir := dir_to_target()
	var dist := distance_to_target()
	if dist < data.preferred_min_range:
		return -dir * data.move_speed
	if dist > data.preferred_max_range:
		return dir * data.move_speed
	return dir.orthogonal() * data.move_speed * 0.5 * _strafe_sign


func _animate() -> void:
	if _telegraph_left > 0.0:
		visual.play(EntityVisual.ATTACK)
		visual.face(dir_to_target().x)
	else:
		super()
