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
## Steers toward the player at this many radians per second, for homing_time seconds (homing bolts).
var homing := 0.0
var homing_time := 0.0
var min_speed := 30.0
var max_speed := 400.0
## Enemy bullets are drawn in code for maximum contrast on every biome: a soft glow, a dark
## outline, a bright body and a white core. `glow` is the body colour (bosses tint bouncing
## bullets green and curving ones cyan). Set DRAW_ENEMY_BULLETS to false to use the PNG instead.
const DRAW_ENEMY_BULLETS := true
const ENEMY_GLOW := Color("#ff2bd6")
var glow := Color(0, 0, 0, 0)
var _pulse := 0.0

var _hit: Array[Node] = []
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_pulse = randf() * TAU
	if DRAW_ENEMY_BULLETS and collision_layer & 16:   # layer 5 = enemy bullets
		if glow.a == 0.0:
			glow = ENEMY_GLOW
		var visual := get_node_or_null("Visual") as CanvasItem
		if visual:
			visual.visible = false
		z_index = 3


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
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			var want := (p.global_position + Vector2(0, -6)) - global_position
			var da := velocity.angle_to(want)
			velocity = velocity.rotated(clampf(da, -homing * delta, homing * delta))
			rotation = velocity.angle()
	if turn != 0.0:
		velocity = velocity.rotated(turn * delta)
		rotation = velocity.angle()
	if accel != 0.0:
		velocity = velocity.normalized() * clampf(velocity.length() + accel * delta, min_speed, max_speed)
	var motion := velocity * delta
	if bounces <= 0 or not _try_bounce(motion):
		position += motion
	lifetime -= delta
	if glow.a > 0.0:
		_pulse += delta * 12.0
		queue_redraw()
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


func _draw() -> void:
	if glow.a == 0.0:
		return
	var p := 0.5 + 0.5 * sin(_pulse)
	draw_circle(Vector2.ZERO, 7.0 + p, Color(glow, 0.22 + 0.1 * p))
	draw_circle(Vector2.ZERO, 4.6, Color(0.04, 0.0, 0.07, 0.95))
	draw_circle(Vector2.ZERO, 3.4, glow)
	draw_circle(Vector2.ZERO, 1.6, Color(1, 1, 1, 0.95))
	if damage >= 2.0:
		# Heavy bullet (full heart): pulsing yellow warning ring.
		draw_arc(Vector2.ZERO, 6.0 + p, 0.0, TAU, 16, Color(1.0, 0.9, 0.3, 0.85), 1.0)


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
