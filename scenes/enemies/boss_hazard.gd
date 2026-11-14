class_name BossHazard
extends Node2D
## Telegraphed boss attacks, so every big hit is readable:
##   circle(): a ring fills up, then explodes (damage inside, optional ring of bullets)
##   beam():   a thin line flickers (aim warning), then a thick beam burns for `duration`; can rotate
##   arc():    a pie-slice warning (scythe sweep / fire breath), then it hits everything inside;
##             with a longer `duration` it keeps burning (breath) and can rotate (spin)
##   zone():   a puddle that warns, then hurts while you stand in it for `duration` (lava, curses)
##   scythe(): a spinning scythe thrown out to `reach` that flies back to its owner (boomerang)
## Lives in the projectile layer, so it is cleared on room change and when a boss dies.

enum Kind { CIRCLE, BEAM, ARC, ZONE, SCYTHE }

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
## ARC: half the opening angle (radians). ZONE / CIRCLE / ARC colour.
var half_angle := 1.2
var color := WARN
## SCYTHE: who it returns to, how far it flies out, how fast.
var owner_node: Node2D
var reach := 140.0
var speed := 200.0
var _returning := false
var _blade_angle := 0.0

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


static func arc(tree: SceneTree, pos: Vector2, p_dir: Vector2, p_radius: float, p_half_angle: float,
		p_delay: float, p_source: String, p_duration: float = 0.12, p_spin: float = 0.0,
		p_color: Color = WARN) -> BossHazard:
	var h := BossHazard.new()
	h.kind = Kind.ARC
	h.dir = p_dir.normalized()
	h.radius = p_radius
	h.half_angle = p_half_angle
	h.delay = p_delay
	h.duration = p_duration
	h.source = p_source
	h.spin = p_spin
	h.color = p_color
	BossHazard._add(tree, h, pos)
	return h


static func zone(tree: SceneTree, pos: Vector2, p_radius: float, p_delay: float, p_duration: float,
		p_source: String, p_color: Color = WARN) -> BossHazard:
	var h := BossHazard.new()
	h.kind = Kind.ZONE
	h.radius = p_radius
	h.delay = p_delay
	h.duration = p_duration
	h.source = p_source
	h.color = p_color
	BossHazard._add(tree, h, pos)
	h.z_index = 1   # under the characters
	return h


static func scythe(tree: SceneTree, pos: Vector2, p_dir: Vector2, p_owner: Node2D, p_source: String,
		p_reach: float = 140.0, p_speed: float = 200.0) -> BossHazard:
	var h := BossHazard.new()
	h.kind = Kind.SCYTHE
	h.dir = p_dir.normalized()
	h.owner_node = p_owner
	h.source = p_source
	h.reach = p_reach
	h.speed = p_speed
	h.delay = 0.0
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
		Kind.ARC:
			if _t >= delay and not _exploded:
				_exploded = true
				Audio.play_sfx("dash", 0.15, -2.0)
				Events.camera_shake_requested.emit(2.5, 0.12)
			if _t >= delay and _t < delay + duration:
				_arc_damage()
			if _t >= delay + duration + 0.2:
				queue_free()
		Kind.ZONE:
			if _t >= delay:
				_zone_damage()
			if _t >= delay + duration:
				queue_free()
		Kind.SCYTHE:
			_scythe_move(delta)
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


func _arc_damage() -> void:
	var p := _player()
	if p == null:
		return
	var to := (p.global_position + Vector2(0, -4)) - global_position
	if to.length() > radius + 4.0:
		return
	if to.length() < 8.0 or absf(dir.angle_to(to)) <= half_angle:
		p.take_damage(damage, source)


func _zone_damage() -> void:
	var p := _player()
	if p and p.global_position.distance_to(global_position) <= radius:
		p.take_damage(damage, source)


func _scythe_move(delta: float) -> void:
	_blade_angle += 16.0 * delta
	if _t > 6.0:
		queue_free()
		return
	if not _returning:
		global_position += dir * speed * delta
		reach -= speed * delta
		if reach <= 0.0:
			_returning = true
	else:
		if owner_node == null or not is_instance_valid(owner_node):
			queue_free()
			return
		var home := owner_node.global_position + Vector2(0, -20)
		var to := home - global_position
		speed = minf(speed + 260.0 * delta, 320.0)
		if to.length() < 10.0:
			queue_free()
			return
		global_position += to.normalized() * minf(speed * delta, to.length())
	var p := _player()
	if p and (p.global_position + Vector2(0, -4)).distance_to(global_position) <= 11.0:
		p.take_damage(damage, source)


func _beam_damage() -> void:
	var p := _player()
	if p == null:
		return
	var point := p.global_position + Vector2(0, -4)
	var closest := Geometry2D.get_closest_point_to_segment(point, global_position, global_position + dir * length)
	if closest.distance_to(point) <= width * 0.5 + 3.0:
		p.take_damage(damage, source)


## Filled pie slice (a full circle when the slice is (almost) all the way round).
func _fill_sector(r: float, a0: float, a1: float, c: Color) -> void:
	if r < 1.0:
		return
	if a1 - a0 >= TAU - 0.05:
		draw_circle(Vector2.ZERO, r, c)
	else:
		draw_colored_polygon(_sector(r, a0, a1), c)


func _sector(r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var n := 18
	for i in n + 1:
		pts.append(Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	return pts


func _draw() -> void:
	match kind:
		Kind.ARC:
			var a := dir.angle()
			if _t < delay:
				var k := clampf(_t / delay, 0.0, 1.0)
				_fill_sector(radius, a - half_angle, a + half_angle, Color(color, 0.12))
				_fill_sector(radius * k, a - half_angle, a + half_angle, Color(color, 0.22 + 0.2 * k))
				draw_arc(Vector2.ZERO, radius, a - half_angle, a + half_angle, 24, Color(color, 0.9), 1.0)
			else:
				var life := clampf((_t - delay) / maxf(duration + 0.2, 0.01), 0.0, 1.0)
				var fade := 1.0 - life if duration < 0.3 else 0.85 + 0.15 * sin(_t * 40.0)
				_fill_sector(radius, a - half_angle, a + half_angle, Color(HOT, 0.35 * fade))
				# The sweep itself: bright crescents along the edge.
				for i in 3:
					draw_arc(Vector2.ZERO, radius - i * 4.0, a - half_angle, a + half_angle, 24,
							Color(1, 1, 1, fade * (0.9 - i * 0.25)), 3.0 - i)
		Kind.ZONE:
			if _t < delay:
				var k := clampf(_t / delay, 0.0, 1.0)
				draw_circle(Vector2.ZERO, radius * k, Color(color, 0.2 + 0.15 * k))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.8), 1.0)
			else:
				var left := clampf((delay + duration - _t) / 0.4, 0.0, 1.0)
				var bub := 0.5 + 0.5 * sin(_t * 9.0)
				draw_circle(Vector2.ZERO, radius, Color(color, (0.45 + 0.1 * bub) * left))
				draw_circle(Vector2.ZERO, radius * 0.6, Color(HOT, 0.25 * bub * left))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(HOT, 0.7 * left), 1.0)
		Kind.SCYTHE:
			# A spinning scythe drawn in code: a crescent blade on a short shaft.
			var ang := _blade_angle
			draw_circle(Vector2.ZERO, 13.0, Color(0.6, 0.5, 1.0, 0.18))
			draw_line(Vector2.from_angle(ang + PI) * 9.0, Vector2.from_angle(ang) * 9.0, Color("#5a3d2a"), 2.0)
			draw_arc(Vector2.from_angle(ang) * 3.0, 9.0, ang + 0.2, ang + 2.4, 14, Color(0.05, 0.03, 0.08), 4.0)
			draw_arc(Vector2.from_angle(ang) * 3.0, 9.0, ang + 0.2, ang + 2.4, 14, Color("#d8dce8"), 2.0)
			draw_arc(Vector2.from_angle(ang) * 3.0, 10.0, ang + 0.4, ang + 2.2, 10, Color(1, 1, 1), 1.0)
		Kind.CIRCLE:
			if not _exploded:
				var k := clampf(_t / delay, 0.0, 1.0)
				draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
				draw_circle(Vector2.ZERO, radius * k, Color(color, 0.25 + 0.2 * k))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.9), 1.0)
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
