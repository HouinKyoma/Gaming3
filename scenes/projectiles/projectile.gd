class_name Projectile
extends Area2D
## A bullet. The scene decides the team through its collision layers:
## player_bullet.tscn hits walls + enemies, enemy_bullet.tscn hits walls + the player.

var velocity := Vector2.ZERO
var damage := 1.0
var lifetime := 1.0
var piercing := false
var source := ""

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
	position += velocity * delta
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
	else:
		_finish()   # walls, obstacles, closed doors


func _finish() -> void:
	_done = true
	queue_free()
