class_name Enemy
extends CharacterBody2D
## Shared enemy logic: HP, contact damage, knockback, loot and death.
## Each enemy type extends this and overrides _behaviour() (and optionally _animate()).

signal died(enemy: Enemy)

const ENEMY_BULLET_PATH := "res://scenes/projectiles/enemy_bullet.tscn"
const ASH_PICKUP_PATH := "res://scenes/pickups/ash_pickup.tscn"
const HEART_PICKUP_PATH := "res://scenes/pickups/heart_pickup.tscn"

@export var data: EnemyData
## 0 = immune to knockback (bosses).
@export var knockback_scale: float = 1.0

var room: Room
var target: Player
var knockback := Vector2.ZERO
var is_dying := false
var _time := 0.0

@onready var health: Health = $Health
@onready var visual: EntityVisual = $Visual
@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	if data == null:
		push_error("%s has no EnemyData" % name)
		data = EnemyData.new()
	target = get_tree().get_first_node_in_group("player") as Player
	health.died.connect(die)
	if health.max_hp <= 0.0:
		health.setup(data.max_hp)
	_on_ready()


## Called by Room right after spawning.
func setup(hp_multiplier: float) -> void:
	health.setup(maxf(1.0, roundf(data.max_hp * hp_multiplier)))


## Override for per-type setup.
func _on_ready() -> void:
	pass


## Override: return the velocity this enemy wants this frame.
func _behaviour(_delta: float) -> Vector2:
	return Vector2.ZERO


## Override for special animations. Default: walk while moving, idle otherwise.
func _animate() -> void:
	visual.play(EntityVisual.WALK if velocity.length() > 5.0 else EntityVisual.IDLE)
	if absf(velocity.x) > 1.0:
		visual.face(velocity.x)


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_time += delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player
	var desired := Vector2.ZERO
	if target and not target.is_dead:
		desired = _behaviour(delta)
	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 800.0 * delta)
	move_and_slide()
	_check_contact()
	_animate()


func _check_contact() -> void:
	if data.contact_damage <= 0:
		return
	for body in contact_area.get_overlapping_bodies():
		if body is Player:
			(body as Player).take_damage(data.contact_damage, data.display_name)


func take_damage(amount: float, from_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
	visual.flash()
	Audio.play_sfx("hit", 0.15, -3.0)
	knockback = from_dir * 120.0 * knockback_scale
	health.damage(amount)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	contact_area.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	_drop_loot()
	Events.enemy_killed.emit(data, global_position)
	died.emit(self)
	visual.play(EntityVisual.DEATH)
	var wait := maxf(visual.animation_length(EntityVisual.DEATH), 0.25)
	get_tree().create_timer(wait).timeout.connect(queue_free)


func _drop_loot() -> void:
	if room == null:
		return
	for i in data.ash_drop:
		if randf() <= data.ash_chance:
			room.spawn_pickup.call_deferred(load(ASH_PICKUP_PATH), global_position)
	if randf() < data.heart_chance:
		room.spawn_pickup.call_deferred(load(HEART_PICKUP_PATH), global_position)


# --- Helpers for subclasses ---------------------------------------------------------

func dir_to_target() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


func shoot_at(dir: Vector2, speed: float, damage: int) -> void:
	var bullet := (load(ENEMY_BULLET_PATH) as PackedScene).instantiate() as Projectile
	var layer := get_tree().get_first_node_in_group("projectile_layer")
	if layer == null:
		layer = get_parent()
	layer.add_child(bullet)
	bullet.setup(global_position + Vector2(0, -6), dir, speed, damage, 5.0, false, data.display_name)
