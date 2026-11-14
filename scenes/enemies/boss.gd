class_name Boss
extends Enemy
## Shared boss logic: boss bar, phases (by HP left), picking attacks, and helpers for writing
## attacks as short scripts (await wait(0.3) between steps).
##
## A boss script extends Boss and overrides:
##   _attacks_for_phase(phase) -> Array   names of the attacks it may use in that phase
##   _attack(name)                        runs one attack (a coroutine; use `await wait(t)` and
##                                        `if halted(): return` after every wait)
##   _move(delta) -> Vector2              how it moves between attacks
##   _on_phase_changed(phase)             optional
##
## While an attack runs (`busy`), the boss moves with `move_vel` (zero unless the attack sets it).

const BOUNCE_COLOR := Color(0.55, 1.0, 0.55)
const CURVE_COLOR := Color(0.7, 0.75, 1.0)

## Name used for the boss bar and the death screen ("Slain by").
var boss_name := ""
var phase := 1
var busy := false
var move_vel := Vector2.ZERO
## Rest between two attacks (subclasses lower it in later phases).
var attack_gap := 0.6
## Where bullets come out, relative to the feet.
var muzzle := Vector2(0, -16)
## Animation override while an attack runs (EntityVisual.WINDUP / ATTACK / SUMMON), &"" = normal.
var anim_state: StringName = &""
var max_adds := 6

var _next_attack := 1.2
var _last_attack := ""
var _charging := false
var _charge_hit := false
var _charge_elapsed := 0.0
var _anim_dir := 1.0
var _attack_token := 0
var _halt := false


func setup(hp_multiplier: float) -> void:
	super(hp_multiplier)
	if boss_name == "":
		boss_name = data.display_name
	Events.boss_spawned.emit(boss_name, int(health.max_hp))


func _on_ready() -> void:
	knockback_scale = 0.0
	health.changed.connect(_on_health_changed)
	_boss_ready()


# --- Overridables -------------------------------------------------------------------------

func _boss_ready() -> void:
	pass


func _attacks_for_phase(_phase: int) -> Array:
	return []


func _attack(_name: String) -> void:
	await wait(0.5)


func _move(_delta: float) -> Vector2:
	return dir_to_target() * data.move_speed


func _on_phase_changed(_phase: int) -> void:
	pass


# --- Core ---------------------------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	Events.boss_health_changed.emit(int(current), int(maximum))
	var r := health.ratio()
	var new_phase := 1
	if r < 0.33:
		new_phase = 3
	elif r < 0.66:
		new_phase = 2
	if new_phase > phase and r > 0.0 and not is_dying:
		phase = new_phase
		visual.flash(0.3)
		Events.camera_shake_requested.emit(6.0, 0.35)
		Audio.play_sfx("boss_roar", 0.1, -6.0)
		_on_phase_changed(phase)


func _behaviour(delta: float) -> Vector2:
	if _charging:
		_charge_elapsed += delta
		if _charge_elapsed > 0.08 and get_slide_collision_count() > 0:
			_charging = false
			_charge_hit = true
			move_vel = Vector2.ZERO
	if busy:
		return move_vel
	_next_attack -= delta
	if _next_attack <= 0.0:
		var options := _attacks_for_phase(phase).duplicate()
		if options.size() > 1:
			options.erase(_last_attack)   # never the same attack twice in a row
		if not options.is_empty():
			_last_attack = options.pick_random()
			_run_attack(_last_attack)
			return move_vel
	return _move(delta)


func _run_attack(attack_name: String) -> void:
	busy = true
	move_vel = Vector2.ZERO
	_attack_token += 1
	var token := _attack_token
	await _attack(attack_name)
	if is_dying or token != _attack_token:
		return
	anim_state = &""
	move_vel = Vector2.ZERO
	busy = false
	_next_attack = attack_gap


# --- Helpers for attacks ------------------------------------------------------------------

## True when the running attack must stop (boss died, or interrupt() was called).
## Attacks check it after every wait.
func halted() -> bool:
	return is_dying or _halt


## Stops the running attack (it ends at its next halted() check). Call resume_attacks() later.
func interrupt() -> void:
	_halt = true
	_attack_token += 1
	_charging = false
	move_vel = Vector2.ZERO


func resume_attacks() -> void:
	_halt = false

## Waits `t` seconds. The timer belongs to the boss, so a dead boss simply never resumes.
func wait(t: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(t, 0.01)
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()


func gpos() -> Vector2:
	return global_position + muzzle


## Unit vector from the muzzle to the player's chest.
func aim() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.DOWN
	var d := (target.global_position + Vector2(0, -6)) - gpos()
	return d.normalized() if d.length() > 0.1 else Vector2.DOWN


func target_pos() -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position
	return target.global_position


func shoot(dir: Vector2, speed: float) -> Projectile:
	return Enemy.spawn_bullet(get_tree(), gpos(), dir, speed, data.projectile_damage, boss_name, 6.0)


func ring(count: int, speed: float, offset: float = -1.0) -> Array[Projectile]:
	var out: Array[Projectile] = []
	if offset < 0.0:
		offset = randf() * TAU
	for i in count:
		out.append(shoot(Vector2.from_angle(offset + TAU * i / count), speed))
	return out


func spread(count: int, step: float, speed: float, base: Vector2 = Vector2.ZERO) -> Array[Projectile]:
	var out: Array[Projectile] = []
	if base == Vector2.ZERO:
		base = aim()
	for i in count:
		out.append(shoot(base.rotated((i - (count - 1) / 2.0) * step), speed))
	return out


## Makes bullets bounce off walls (and tints them so the player can tell).
func make_bouncy(bullets: Array, times: int) -> void:
	for b: Projectile in bullets:
		b.bounces = times
		b.lifetime = 8.0
		b.modulate = BOUNCE_COLOR


func make_curvy(bullets: Array, turn: float) -> void:
	for b: Projectile in bullets:
		b.turn = turn
		b.modulate = CURVE_COLOR


## Flashing wind-up before a big move.
func telegraph(t: float) -> void:
	anim_state = EntityVisual.WINDUP
	visual.flash(t * 0.6)
	await wait(t)
	anim_state = &""


## Charges in a straight line until it hits a wall or `time` runs out. Returns true on a wall hit.
func charge(dir: Vector2, speed: float, time: float) -> bool:
	anim_state = EntityVisual.ATTACK
	_anim_dir = dir.x
	_charging = true
	_charge_hit = false
	_charge_elapsed = 0.0
	move_vel = dir * speed
	var left := time
	while left > 0.0 and _charging and not halted():
		await wait(0.03)
		left -= 0.03
	_charging = false
	move_vel = Vector2.ZERO
	anim_state = &""
	if _charge_hit:
		Events.camera_shake_requested.emit(4.0, 0.2)
	return _charge_hit


## Fades out, appears at `local_pos` (room-local, moved to free floor), fades back in.
## No contact damage and no damage taken while gone.
func blink_to(local_pos: Vector2, out_time: float = 0.25, in_time: float = 0.2) -> void:
	contact_enabled = false
	health.invulnerable = true
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, out_time)
	await wait(out_time)
	if is_dying:
		return
	position = room.nearest_free(local_pos) if room else local_pos
	var tw2 := create_tween()
	tw2.tween_property(visual, "modulate:a", 1.0, in_time)
	await wait(in_time)
	contact_enabled = true
	health.invulnerable = false


func circle_at(global_pos: Vector2, radius: float, delay: float, bullets: int = 0, bullet_speed: float = 90.0) -> BossHazard:
	return BossHazard.circle(get_tree(), global_pos, radius, delay, boss_name, bullets, bullet_speed)


func beam_from(global_pos: Vector2, dir: Vector2, delay: float, duration: float, width: float = 10.0, spin: float = 0.0) -> BossHazard:
	return BossHazard.beam(get_tree(), global_pos, dir, delay, duration, boss_name, width, spin)


## A wall of bullets sweeping across the room from one side, with a gap to slip through.
## side: Vector2i.LEFT = starts at the left wall and moves right, etc.
func bullet_wall(side: Vector2i, speed: float, gap_slots: int = 4) -> void:
	if room == null:
		return
	var r := room.inner_rect_global()
	var step := 13.0
	var vertical := side == Vector2i.LEFT or side == Vector2i.RIGHT
	var span := r.size.y if vertical else r.size.x
	var slots := int(span / step)
	var gap := randi_range(1, maxi(1, slots - gap_slots - 1))
	var dir := -Vector2(side)
	for i in slots:
		if i >= gap and i < gap + gap_slots:
			continue
		var along := (i + 0.5) * step
		var pos: Vector2
		match side:
			Vector2i.LEFT:
				pos = Vector2(r.position.x + 4.0, r.position.y + along)
			Vector2i.RIGHT:
				pos = Vector2(r.end.x - 4.0, r.position.y + along)
			Vector2i.UP:
				pos = Vector2(r.position.x + along, r.position.y + 4.0)
			_:
				pos = Vector2(r.position.x + along, r.end.y - 4.0)
		Enemy.spawn_bullet(get_tree(), pos, dir, speed, data.projectile_damage, boss_name, 10.0)


## Summons enemies around the boss (skipped if the room already has too many).
func summon(ids: Array, radius: float = 32.0) -> void:
	if room == null or room.alive > max_adds:
		return
	anim_state = EntityVisual.SUMMON
	for i in ids.size():
		var add: EnemyData = Content.get_enemy(String(ids[i]))
		if add:
			var offset := Vector2.from_angle(TAU * i / ids.size() + randf()) * radius
			room.spawn_enemy(add, position + offset, 1.0)


## Removes every enemy bullet and hazard (on death / stage change).
func clear_bullets() -> void:
	var layer := get_tree().get_first_node_in_group("projectile_layer")
	if layer == null:
		return
	for child in layer.get_children():
		if child is BossHazard:
			child.queue_free()
		elif child is Projectile and (child as Projectile).source != "Player":
			child.queue_free()


func die() -> void:
	if is_dying:
		return
	super()
	busy = true
	_charging = false
	Events.camera_shake_requested.emit(9.0, 0.6)
	Events.boss_defeated.emit()
	clear_bullets()
	get_tree().call_group.call_deferred("enemies", "die")


func _animate() -> void:
	if anim_state != &"":
		visual.play(anim_state)
		if anim_state == EntityVisual.ATTACK and _charging:
			visual.face(_anim_dir)
		else:
			visual.face(dir_to_target().x)
	else:
		super()
