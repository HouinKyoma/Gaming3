class_name Pickup
extends Area2D
## Ash or a heart. Pops out when dropped, then flies to the player inside the magnet radius
## (or from anywhere once the room is cleared).

enum Kind { ASH, HEART }

@export var kind: Kind = Kind.ASH
@export var value: int = 1

const ROOM_BOUNDS := Rect2(20, 20, 440, 216)   # room-local area pickups stay inside

var homing := false
var _homing_delay := 0.0
var _pop := Vector2.ZERO
var _player: Player


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_pop = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)


## Fly to the player from anywhere after `delay` seconds (used when a room is cleared).
func start_homing(delay: float = 0.4) -> void:
	if kind == Kind.ASH:
		homing = true
		_homing_delay = delay


func _physics_process(delta: float) -> void:
	position += _pop * delta
	_pop = _pop.move_toward(Vector2.ZERO, 200.0 * delta)
	position = position.clamp(ROOM_BOUNDS.position, ROOM_BOUNDS.end)

	if _player == null or not is_instance_valid(_player) or _player.is_dead:
		return

	var wants_player := kind == Kind.ASH or not _player.health.is_full()
	var to_player := _player.global_position + Vector2(0, -4) - global_position
	var magnet: float = Run.stats.magnet_radius if Run.stats else 24.0
	if homing:
		_homing_delay -= delta
	var pulled := (homing and _homing_delay <= 0.0) or to_player.length() < magnet
	if wants_player and pulled:
		global_position += to_player.normalized() * minf(220.0 * delta, to_player.length())

	for body in get_overlapping_bodies():
		if body is Player:
			_collect(body as Player)
			return


func _collect(player: Player) -> void:
	match kind:
		Kind.ASH:
			Run.add_ash(value)
			Audio.play_sfx("pickup", 0.1, -6.0)
			queue_free()
		Kind.HEART:
			if player.heal(value):
				Audio.play_sfx("pickup", 0.0)
				queue_free()
