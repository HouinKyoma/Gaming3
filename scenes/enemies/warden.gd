extends Enemy
## The Hollow Warden (boss). Three phases by HP left:
##   P1 (> 66%): slow walk, ring of 12 bullets every 2.5 s
##   P2 (66-33%): adds a charge; alternates ring and an aimed 3-bullet spread
##   P3 (< 33%): summons 3 Swarmers every 6 s, ring of 16 every 1.8 s

enum State { WALK, WINDUP, CHARGE, RECOVER, SUMMON }

const SWARMER_ID := "swarmer"

var phase := 1
var state: State = State.WALK
var _state_left := 0.0
var _attack_cd := 2.0
var _summon_cd := 3.0
var _charge_cd := 4.0
var _charge_dir := Vector2.RIGHT
var _charge_elapsed := 0.0
var _use_spread := false


func setup(hp_multiplier: float) -> void:
	super(hp_multiplier)
	Events.boss_spawned.emit(data.display_name, int(health.max_hp))


func _on_ready() -> void:
	knockback_scale = 0.0
	health.changed.connect(_on_health_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	Events.boss_health_changed.emit(int(current), int(maximum))
	var r := health.ratio()
	var new_phase := 1
	if r < 0.33:
		new_phase = 3
	elif r < 0.66:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		visual.flash(0.3)
		Events.camera_shake_requested.emit(5.0, 0.3)


func _behaviour(delta: float) -> Vector2:
	_state_left -= delta
	match state:
		State.WINDUP:
			if _state_left <= 0.0:
				state = State.CHARGE
				_state_left = data.charge_time
				_charge_elapsed = 0.0
			return Vector2.ZERO
		State.CHARGE:
			_charge_elapsed += delta
			var hit_wall := _charge_elapsed > 0.1 and get_slide_collision_count() > 0
			if _state_left <= 0.0 or hit_wall:
				if hit_wall:
					Events.camera_shake_requested.emit(4.0, 0.2)
					_ring(8, data.projectile_speed)
				state = State.RECOVER
				_state_left = 0.8
				return Vector2.ZERO
			return _charge_dir * data.charge_speed
		State.RECOVER, State.SUMMON:
			if _state_left <= 0.0:
				state = State.WALK
			return Vector2.ZERO

	# WALK: attacks run on their own cooldowns
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_attack()
	if phase >= 2:
		_charge_cd -= delta
		if _charge_cd <= 0.0:
			_charge_cd = 5.0
			_charge_dir = dir_to_target()
			state = State.WINDUP
			_state_left = data.windup_time
			visual.flash(data.windup_time * 0.5)
			return Vector2.ZERO
	if phase >= 3:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = 6.0
			_summon()
			state = State.SUMMON
			_state_left = 0.6
			return Vector2.ZERO
	return dir_to_target() * data.move_speed


func _attack() -> void:
	match phase:
		1:
			_attack_cd = 2.5
			_ring(12, data.projectile_speed)
		2:
			_attack_cd = 2.0
			if _use_spread:
				_spread(3, 0.25, data.projectile_speed * 1.3)
			else:
				_ring(12, data.projectile_speed)
			_use_spread = not _use_spread
		_:
			_attack_cd = 1.8
			_ring(16, data.projectile_speed)


func _ring(count: int, speed: float) -> void:
	var offset := randf() * TAU
	for i in count:
		shoot_at(Vector2.from_angle(offset + TAU * i / count), speed, data.projectile_damage)


func _spread(count: int, angle_step: float, speed: float) -> void:
	var base := dir_to_target()
	for i in count:
		var a := (i - (count - 1) / 2.0) * angle_step
		shoot_at(base.rotated(a), speed, data.projectile_damage)


func _summon() -> void:
	if room == null:
		return
	var swarmer: EnemyData = Content.get_enemy(SWARMER_ID)
	if swarmer == null:
		return
	for i in 3:
		var offset := Vector2.from_angle(TAU * i / 3.0) * 28.0
		room.spawn_enemy(swarmer, position + offset, 1.0)


func die() -> void:
	if is_dying:
		return
	super()
	Events.camera_shake_requested.emit(8.0, 0.5)
	Events.boss_defeated.emit()
	# Clear any remaining summons.
	get_tree().call_group.call_deferred("enemies", "die")


func _animate() -> void:
	match state:
		State.WINDUP:
			visual.play(EntityVisual.WINDUP)
			visual.face(_charge_dir.x)
		State.CHARGE:
			visual.play(EntityVisual.ATTACK)
			visual.face(_charge_dir.x)
		State.SUMMON:
			visual.play(EntityVisual.SUMMON)
		State.RECOVER:
			visual.play(EntityVisual.IDLE)
		_:
			super()
