class_name Health
extends Node
## Reusable hit points for the player and enemies.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

var max_hp := 0.0
var current := 0.0
var invulnerable := false
var _dead := false


func setup(maximum: float, start_value: float = -1.0) -> void:
	max_hp = maximum
	current = maximum if start_value < 0.0 else minf(start_value, maximum)
	_dead = false
	changed.emit(current, max_hp)


func damage(amount: float) -> void:
	if _dead or invulnerable or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount)
	changed.emit(current, max_hp)
	if current <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	current = minf(current + amount, max_hp)
	changed.emit(current, max_hp)


func revive(hp: float) -> void:
	_dead = false
	current = minf(hp, max_hp)
	changed.emit(current, max_hp)


func set_max(value: float) -> void:
	var diff := value - max_hp
	max_hp = value
	if diff > 0.0:
		current += diff
	current = minf(current, max_hp)
	changed.emit(current, max_hp)


func is_full() -> bool:
	return current >= max_hp


func is_dead() -> bool:
	return _dead


func ratio() -> float:
	return current / max_hp if max_hp > 0.0 else 0.0
