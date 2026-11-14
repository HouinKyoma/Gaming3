class_name Player
extends CharacterBody2D
## Input, movement, aiming, shooting, dash, taking damage, death and Second Wind.
## All numbers come from Run.stats (PlayerStats), never from this script.

@export var bullet_scene: PackedScene

var stats: PlayerStats
var god_mode := false
## True during cutscenes (boss intro): no moving, no shooting, can't be hurt.
var locked := false
var is_dead := false

var _shoot_cd := 0.0
var _dash_cd := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _invuln_left := 0.0
var _last_hit_by := ""

@onready var health: Health = $Health
@onready var visual: EntityVisual = $Visual
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	if not Run.active or Run.stats == null:
		Run.start_new_run()   # lets you run the scene directly (F6) for testing
	stats = Run.stats
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	health.setup(stats.max_hp, Run.current_hp)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	if locked:
		velocity = Vector2.ZERO
		health.invulnerable = true
		visual.play(EntityVisual.IDLE)
		return

	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_invuln_left = maxf(_invuln_left - delta, 0.0)

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * stats.dash_speed
	else:
		velocity = input * stats.move_speed
		if Input.is_action_just_pressed(&"dash") and stats.can_dash and _dash_cd <= 0.0:
			_start_dash(input)
	move_and_slide()

	var aim := get_global_mouse_position() - muzzle.global_position
	if aim.length() < 1.0:
		aim = Vector2.RIGHT
	if Input.is_action_pressed(&"shoot") and _shoot_cd <= 0.0:
		_shoot(aim.normalized())

	health.invulnerable = god_mode or _invuln_left > 0.0 or _dash_left > 0.0

	visual.face(aim.x)
	if _dash_left > 0.0:
		visual.play(EntityVisual.DASH)
	elif input != Vector2.ZERO:
		visual.play(EntityVisual.WALK)
	else:
		visual.play(EntityVisual.IDLE)


func _start_dash(input: Vector2) -> void:
	_dash_dir = input.normalized() if input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	_dash_left = stats.dash_time
	Audio.play_sfx("dash")
	_dash_cd = stats.dash_cooldown


func _shoot(dir: Vector2) -> void:
	if bullet_scene == null:
		return
	_shoot_cd = stats.fire_cooldown
	Audio.play_sfx("shoot", 0.1, -4.0)
	var bullet := bullet_scene.instantiate() as Projectile
	var layer := get_tree().get_first_node_in_group("projectile_layer")
	if layer == null:
		layer = get_parent()
	layer.add_child(bullet)
	bullet.setup(muzzle.global_position, dir, stats.bullet_speed, stats.damage,
			stats.bullet_lifetime, stats.piercing, "Player")


## Called by enemies, enemy bullets and hazards.
func take_damage(amount: int, source: String) -> void:
	if is_dead or health.invulnerable:
		return
	_last_hit_by = source
	health.damage(amount)
	Audio.play_sfx("player_hurt", 0.05)
	Events.camera_shake_requested.emit(3.0, 0.15)
	if not health.is_dead():
		_invuln_left = stats.invuln_time
		visual.flash()
		visual.blink(stats.invuln_time)


## Returns false when already at full health (so the pickup stays on the floor).
func heal(amount: int) -> bool:
	if is_dead or health.is_full():
		return false
	health.heal(amount)
	return true


func heal_full() -> void:
	health.heal(health.max_hp)


## Call after Run.add_boon() so new stats take effect mid-run.
func apply_new_stats() -> void:
	stats = Run.stats
	health.set_max(stats.max_hp)


func _on_health_changed(current: float, maximum: float) -> void:
	Run.current_hp = int(current)
	Events.player_health_changed.emit(int(current), int(maximum))


func _on_died() -> void:
	if stats.second_wind and not Run.second_wind_used:
		Run.second_wind_used = true
		health.revive(2)
		_invuln_left = 2.0
		visual.flash(0.2)
		visual.blink(2.0)
		Events.camera_shake_requested.emit(6.0, 0.3)
		return
	is_dead = true
	visual.play(EntityVisual.DEATH)
	Events.camera_shake_requested.emit(6.0, 0.3)
	Events.player_died.emit(_last_hit_by if _last_hit_by != "" else "Unknown")
