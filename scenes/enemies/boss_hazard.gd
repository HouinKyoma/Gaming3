class_name BossHazard
extends Node2D
## Telegraphed boss attacks, so every big hit is readable:
##   circle(): a ring fills up, then explodes (damage inside, optional ring of bullets)
##   beam():   a thin line flickers (aim warning), then a thick beam burns for `duration`; can rotate
## Lives in the projectile layer, so it is cleared on room change and when a boss dies.

enum Kind { CIRCLE, BEAM }

const WARN := Color("#ff5a3c")
const HOT := Color("#ffe08a")

var kind: Kind = Kind.CIRCLE
var radius := 24.0
var delay := 0.8
var duration := 0.6
var damage := 1
var source := "Boss"
var bullets := 0
var bullet_speed := 90.0
var dir := Vector2.RIGHT
var length := 900.0
var width := 10.0
var spin := 0.0

var _t := 0.0
var _exploded := false


static func circle(tree: SceneTree, pos: Vector2, p_radius: float, p_delay: float, p_source: String,
		p_bullets: int = 0, p_bullet_speed: float = 90.0) -> BossHazard:
	var h := BossHazard.new()
	h.kind = Kind.CIRCLE
	h.radius = p_radius
	h.delay = p_delay
	h.source = p_source
	h.bullets = p_bullets
	h.bullet_speed = p_bullet_speed
	BossHazard._add(tree, h, pos)
	return h


static func beam(tree: SceneTree, pos: Vector2, p_dir: Vector2, p_delay: float, p_duration: float,
		p_source: String, p_width: float = 10.0, p_spin: float = 0.0) -> BossHazard:
	var h := BossHazard.new()
	h.kind = Kind.BEAM
	h.dir = p_dir.normalized()
	h.delay = p_delay
	h.duration = p_duration
	h.source = p_source
	h.width = p_width
	h.spin = p_spin
	BossHazard._add(tree, h, pos)
	return h


static func _add(tree: SceneTree, h: BossHazard, pos: Vector2) -> void:
	var layer := tree.get_first_node_in_group("projectile_layer")
	if layer == null:
		layer = tree.current_scene
	layer.add_child(h)
	h.global_position = pos
	h.z_index = 4


func _physics_process(delta: float) -> void:
	_t += delta
	if spin != 0.0:
		dir = dir.rotated(spin * delta)
	match kind:
		Kind.CIRCLE:
			if not _exploded and _t >= delay:
				_explode()
			elif _exploded and _t >= delay + 0.3:
				queue_free()
		Kind.BEAM:
			if _t >= delay:
				_beam_damage()
			if _t >= delay + duration:
				queue_free()
	queue_redraw()


func _player() -> Player:
	var p := get_tree().get_first_node_in_group("player") as Player
	return p if p and not p.is_dead else null


func _explode() -> void:
	_exploded = true
	Events.camera_shake_requested.emit(3.0, 0.15)
	Audio.play_sfx("hit", 0.2, -2.0)
	var p := _player()
	if p and (p.global_position + Vector2(0, -4)).distance_to(global_position) <= radius:
		p.take_damage(damage, source)
	if bullets > 0:
		var offset := randf() * TAU
		for i in bullets:
			Enemy.spawn_bullet(get_tree(), global_position, Vector2.from_angle(offset + TAU * i / bullets),
					bullet_speed, damage, source)


func _beam_damage() -> void:
	var p := _player()
	if p == null:
		return
	var point := p.global_position + Vector2(0, -4)
	var closest := Geometry2D.get_closest_point_to_segment(point, global_position, global_position + dir * length)
	if closest.distance_to(point) <= width * 0.5 + 3.0:
		p.take_damage(damage, source)


func _draw() -> void:
	match kind:
		Kind.CIRCLE:
			if not _exploded:
				var k := clampf(_t / delay, 0.0, 1.0)
				draw_circle(Vector2.ZERO, radius, Color(WARN, 0.12))
				draw_circle(Vector2.ZERO, radius * k, Color(WARN, 0.25 + 0.2 * k))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(WARN, 0.9), 1.0)
			else:
				var e := clampf((_t - delay) / 0.3, 0.0, 1.0)
				draw_circle(Vector2.ZERO, radius * (1.0 + 0.25 * e), Color(HOT, 1.0 - e))
				draw_arc(Vector2.ZERO, radius * (1.0 + 0.6 * e), 0.0, TAU, 40, Color(1, 1, 1, 1.0 - e), 3.0 * (1.0 - e))
		Kind.BEAM:
			var end := dir * length
			if _t < delay:
				var flicker := 0.5 + 0.5 * sin(_t * 40.0)
				draw_line(Vector2.ZERO, end, Color(WARN, 0.25 + 0.35 * flicker), 1.0)
			else:
				var life := clampf((_t - delay) / maxf(duration, 0.01), 0.0, 1.0)
				var w := width * (1.0 - 0.3 * life) * (0.85 + 0.15 * sin(_t * 50.0))
				draw_line(Vector2.ZERO, end, Color(WARN, 0.55), w + 4.0)
				draw_line(Vector2.ZERO, end, Color(HOT, 0.95), w)
				draw_line(Vector2.ZERO, end, Color(1, 1, 1, 0.9), w * 0.35)
				draw_circle(Vector2.ZERO, w * 0.9, Color(HOT, 0.9))
