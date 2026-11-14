extends Enemy
## The Ashen Tyrant (final boss, floor 4). Built to be much harder than the Warden.
## A rotating bullet spiral runs almost all the time; the only rest is right after its charges.
##   P1 (> 66%): 2-arm spiral + aimed 5-bullet spread
##   P2 (66-33%): 3-arm spiral, spread / ring volleys, 2 charges in a row, summons a Charger
##   P3 (< 33%): 4-arm spiral, 7-spread + double rings, 3 charges in a row, summons a pack, moves faster
## Each new phase starts with a 24-bullet burst. All numbers not listed here are in data/enemies/tyrant.tres.

enum State { WALK, WINDUP, CHARGE, RECOVER, SUMMON }

const SPIRAL_ARMS := [2, 3, 4]              # per phase
const SPIRAL_INTERVAL := [0.16, 0.13, 0.11] # seconds between spiral shots, per phase
const SPIRAL_TURN := [1.7, 2.0, 2.4]        # radians per second, per phase
const VOLLEY_CD := [1.8, 1.7, 1.5]
const CHARGE_CHAIN := [0, 2, 3]             # charges in a row, per phase
const CHARGE_CD := 6.0
const CHAIN_WINDUP := 0.35                  # shorter warning for the 2nd / 3rd charge
const RECOVER_TIME := 1.1                   # the player's window to hit back
const SUMMON_CD := [0.0, 9.0, 7.0]
const MAX_ADDS := 6
const PHASE_BURST := 24
const P3_SPEED_MULT := 1.35

var phase := 1
var state: State = State.WALK
var _state_left := 0.0
var _spiral_angle := 0.0
var _spiral_cd := 1.0
var _volley_cd := 2.0
var _volley_index := 0
var _charge_cd := 3.0
var _charges_left := 0
var _charge_dir := Vector2.RIGHT
var _charge_elapsed := 0.0
var _summon_cd := 4.0


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
	if new_phase > phase and not is_dying and r > 0.0:
		phase = new_phase
		visual.flash(0.3)
		Events.camera_shake_requested.emit(6.0, 0.35)
		_ring(PHASE_BURST, data.projectile_speed * 0.8, randf() * TAU)


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
				Events.camera_shake_requested.emit(4.0, 0.2)
				_ring(10, data.projectile_speed, randf() * TAU)
				_charges_left -= 1
				if _charges_left > 0:
					_begin_windup(CHAIN_WINDUP)
				else:
					state = State.RECOVER
					_state_left = RECOVER_TIME
				return Vector2.ZERO
			return _charge_dir * data.charge_speed
		State.RECOVER, State.SUMMON:
			if _state_left <= 0.0:
				state = State.WALK
			return Vector2.ZERO

	# WALK: the spiral never stops, everything else runs on its own cooldown.
	_spiral(delta)
	_volley_cd -= delta
	if _volley_cd <= 0.0:
		_volley()
	if phase >= 2:
		_charge_cd -= delta
		if _charge_cd <= 0.0:
			_charge_cd = CHARGE_CD
			_charges_left = CHARGE_CHAIN[phase - 1]
			_begin_windup(data.windup_time)
			return Vector2.ZERO
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = SUMMON_CD[phase - 1]
			_summon()
			state = State.SUMMON
			_state_left = 0.5
			return Vector2.ZERO
	var speed := data.move_speed * (P3_SPEED_MULT if phase >= 3 else 1.0)
	return dir_to_target() * speed


func _begin_windup(time: float) -> void:
	_charge_dir = dir_to_target()
	if _charge_dir == Vector2.ZERO:
		_charge_dir = Vector2.RIGHT
	state = State.WINDUP
	_state_left = time
	visual.flash(time * 0.5)


func _spiral(delta: float) -> void:
	_spiral_angle = fmod(_spiral_angle + SPIRAL_TURN[phase - 1] * delta, TAU)
	_spiral_cd -= delta
	if _spiral_cd > 0.0:
		return
	_spiral_cd = SPIRAL_INTERVAL[phase - 1]
	var arms: int = SPIRAL_ARMS[phase - 1]
	for i in arms:
		shoot_at(Vector2.from_angle(_spiral_angle + TAU * i / arms), data.projectile_speed, data.projectile_damage)


func _volley() -> void:
	_volley_cd = VOLLEY_CD[phase - 1]
	_volley_index += 1
	var fast := data.projectile_speed * 1.3
	match phase:
		1:
			_spread(5, 0.22, fast)
		2:
			if _volley_index % 2 == 0:
				_ring(14, data.projectile_speed, randf() * TAU)
			else:
				_spread(5, 0.22, fast)
		_:
			if _volley_index % 2 == 0:
				var offset := randf() * TAU
				_ring(12, data.projectile_speed * 1.1, offset)
				_ring(12, data.projectile_speed * 0.6, offset + TAU / 24.0)
			else:
				_spread(7, 0.2, fast)


func _ring(count: int, speed: float, offset: float) -> void:
	for i in count:
		shoot_at(Vector2.from_angle(offset + TAU * i / count), speed, data.projectile_damage)


func _spread(count: int, angle_step: float, speed: float) -> void:
	var base := dir_to_target()
	if base == Vector2.ZERO:
		base = Vector2.RIGHT
	for i in count:
		var a := (i - (count - 1) / 2.0) * angle_step
		shoot_at(base.rotated(a), speed, data.projectile_damage)


func _summon() -> void:
	if room == null or room.alive > MAX_ADDS:
		return
	var ids: Array[String] = ["charger"]
	if phase >= 3:
		ids = ["swarmer", "swarmer", "swarmer", "spitter"]
	for i in ids.size():
		var add: EnemyData = Content.get_enemy(ids[i])
		if add == null:
			continue
		var offset := Vector2.from_angle(TAU * i / ids.size()) * 40.0
		var pos := (position + offset).clamp(Vector2(32, 40), Room.SIZE - Vector2(32, 32))
		room.spawn_enemy(add, pos, 1.0)


func die() -> void:
	if is_dying:
		return
	super()
	Events.camera_shake_requested.emit(10.0, 0.6)
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
