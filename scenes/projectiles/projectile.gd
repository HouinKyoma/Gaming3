class_name Projectile
extends Area2D
## A bullet. The scene decides the team through its collision layers:
## player_bullet.tscn hits walls + enemies, enemy_bullet.tscn hits walls + the player.

var velocity := Vector2.ZERO
var damage := 1.0
var lifetime := 1.0
var piercing := false
var source := ""
## Bounces off walls this many times before breaking (bouncing boss bullets).
var bounces := 0
## Turns this many radians per second (curving bullets).
var turn := 0.0
## Speeds up (or slows down if negative) this many px/s per second, between min_speed and max_speed.
var accel := 0.0
var min_speed := 30.0
var max_speed := 400.0

var _hit: Array[Node] = []
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(pos: Vector2, dir: Vector2, speed: float, dmg: float, life: float,
		pierce: bool = false, src: String = "") -> void:
	global_position = pos
	velocity = dir * speed
	rotation = dir.angle()
	damage = dmg
	lifetime = life
	piercing = pierce
	source = src


func _physics_process(delta: float) -> void:
	if turn != 0.0:
		velocity = velocity.rotated(turn * delta)
		rotation = velocity.angle()
	if accel != 0.0:
		velocity = velocity.normalized() * clampf(velocity.length() + accel * delta, min_speed, max_speed)
	var motion := velocity * delta
	if bounces <= 0 or not _try_bounce(motion):
		position += motion
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body is Enemy:
		if body in _hit:
			return
		_hit.append(body)
		(body as Enemy).take_damage(damage, velocity.normalized())
		if not piercing:
			_finish()
	elif body is Player:
		(body as Player).take_damage(int(damage), source)
		_finish()
	elif bounces <= 0:
		_finish()   # walls, obstacles, closed doors (bouncing bullets reflect in _try_bounce)


## Reflects off a wall the bullet is about to hit. Returns true if it bounced.
func _try_bounce(motion: Vector2) -> bool:
	if motion == Vector2.ZERO:
		return false
	var space := get_world_2d().direct_space_state
	var to := global_position + motion + motion.normalized() * 3.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to, 1))
	if hit.is_empty():
		return false
	var normal: Vector2 = hit["normal"]
	if normal == Vector2.ZERO:
		return false
	velocity = velocity.bounce(normal)
	rotation = velocity.angle()
	global_position = (hit["position"] as Vector2) + normal * 3.0
	bounces -= 1
	return true


func _finish() -> void:
	_done = true
	queue_free()
