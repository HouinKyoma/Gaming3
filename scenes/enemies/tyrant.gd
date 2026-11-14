extends Boss
## The Ashen Tyrant (final boss, floor 4). Two stages.
## STAGE 1 "The Ashen Tyrant":
##   P1:         walking spiral, aimed spread bursts, bouncing bombs, chain charges
##   P2 (< 66%): + bullet walls (find the gap), meteor rain, summons
##   P3 (< 33%): + double rings, faster
## At 0 HP it BOUNCES BACK: clears the screen, heals to STAGE2_HP and becomes
## STAGE 2 "The Tyrant Reborn" (new boss bar, phases start again):
##   twin curving spirals, rotating beams, crushing bullet walls from both sides, meteor storms,
##   blink slams next to you, bouncing bullet storms, 4-hit charge chains. Barely rests.
## Numbers not listed here are in data/enemies/tyrant.tres.

const STAGE2_HP := 520
const STAGE2_NAME := "The Tyrant Reborn"
const STAGE2_TINT := Color(1.0, 0.55, 0.45)

var stage := 1


func _boss_ready() -> void:
	muzzle = Vector2(0, -30)
	attack_gap = 0.5
	max_adds = 5


func _on_phase_changed(p: int) -> void:
	if stage == 1:
		attack_gap = [0.5, 0.4, 0.3][p - 1]
	else:
		attack_gap = [0.3, 0.25, 0.18][p - 1]
	ring(24, data.projectile_speed * 0.8)


func _attacks_for_phase(p: int) -> Array:
	if stage == 1:
		match p:
			1:
				return ["spiral_walk", "bursts", "bombs", "charges"]
			2:
				return ["spiral_walk", "bursts", "bombs", "charges", "wall", "meteors", "summon"]
		return ["spiral_walk", "bombs", "charges", "wall", "meteors", "double_rings", "summon"]
	match p:
		1:
			return ["twin_spiral", "beams", "crush", "meteor_storm", "blink_slam", "charges"]
		2:
			return ["twin_spiral", "beams", "crush", "meteor_storm", "blink_slam", "bounce_storm", "charges"]
	return ["twin_spiral", "beams", "crush", "meteor_storm", "blink_slam", "bounce_storm", "charges", "summon"]


func _move(_delta: float) -> Vector2:
	var speed := data.move_speed * (1.35 if phase >= 3 else 1.0) * (1.25 if stage == 2 else 1.0)
	return dir_to_target() * speed


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	match attack_name:
		# --- Stage 1 -----------------------------------------------------------------
		"spiral_walk":
			anim_state = EntityVisual.ATTACK
			var a := randf() * TAU
			var arms := 2 + phase
			for i in 30:
				for k in arms:
					shoot(Vector2.from_angle(a + TAU * k / arms), sp)
				a += 0.21
				move_vel = dir_to_target() * data.move_speed * 0.6
				await wait(0.1)
				if halted():
					return
		"bursts":
			anim_state = EntityVisual.ATTACK
			for i in 3 + phase:
				spread(5 + phase, 0.18, sp * 1.35)
				await wait(0.3)
				if halted():
					return
		"bombs":
			anim_state = EntityVisual.ATTACK
			for i in 2:
				make_bouncy(spread(6, 0.5, sp * 1.1, Vector2.from_angle(randf() * TAU)), 2)
				await wait(0.35)
				if halted():
					return
		"charges":
			var count := phase + 1 if stage == 1 else 4
			for i in count:
				await telegraph(0.5 if i == 0 else 0.28)
				if halted():
					return
				var hit: bool = await charge(aim(), data.charge_speed * (1.15 if stage == 2 else 1.0), data.charge_time)
				if halted():
					return
				if hit:
					ring(12, sp)
			await wait(0.8)   # tired: punish it now
		"wall":
			anim_state = EntityVisual.SUMMON
			var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			for i in 2:
				bullet_wall(sides.pick_random(), sp, 4)
				await wait(1.1)
				if halted():
					return
		"meteors":
			anim_state = EntityVisual.SUMMON
			for i in 6:
				var at := target_pos() + (Vector2.ZERO if i % 2 == 0 else Vector2(randf_range(-50, 50), randf_range(-35, 35)))
				circle_at(at + Vector2(0, -4), 26.0, 0.8, 8, sp * 0.8)
				await wait(0.22)
				if halted():
					return
			await wait(0.4)
		"double_rings":
			anim_state = EntityVisual.ATTACK
			for i in 3:
				var offset := randf() * TAU
				ring(16, sp * 1.1, offset)
				ring(16, sp * 0.65, offset + TAU / 32.0)
				await wait(0.45)
				if halted():
					return
		"summon":
			summon(["charger", "swarmer", "swarmer", "swarmer"] if phase >= 3 else ["charger", "spitter"], 44.0)
			await wait(0.5)

		# --- Stage 2 -----------------------------------------------------------------
		"twin_spiral":
			anim_state = EntityVisual.ATTACK
			var a := randf() * TAU
			for i in 36:
				for k in 3:
					make_curvy([shoot(Vector2.from_angle(a + TAU * k / 3.0), sp)], 0.6)
					make_curvy([shoot(Vector2.from_angle(-a + TAU * k / 3.0), sp)], -0.6)
				a += 0.19
				await wait(0.09)
				if halted():
					return
		"beams":
			anim_state = EntityVisual.WINDUP
			var spin := 0.85 if randf() < 0.5 else -0.85
			var base := randf() * TAU
			var count := 3 + mini(phase, 2)
			for k in count:
				beam_from(gpos(), Vector2.from_angle(base + TAU * k / count), 0.9, 3.0, 9.0, spin)
			await wait(0.9)
			anim_state = EntityVisual.ATTACK
			for i in 5:
				ring(10, sp * 0.7)
				await wait(0.6)
				if halted():
					return
		"crush":
			anim_state = EntityVisual.SUMMON
			for i in 2:
				bullet_wall(Vector2i.LEFT, sp, 4)
				bullet_wall(Vector2i.RIGHT, sp, 4)
				await wait(1.3)
				if halted():
					return
				bullet_wall(Vector2i.UP if i == 0 else Vector2i.DOWN, sp * 1.1, 5)
				await wait(0.9)
				if halted():
					return
		"meteor_storm":
			anim_state = EntityVisual.SUMMON
			for i in 12:
				var at := target_pos() + (Vector2.ZERO if i % 3 == 0 else Vector2(randf_range(-80, 80), randf_range(-50, 50)))
				circle_at(at + Vector2(0, -4), 24.0, 0.7, 6, sp * 0.8)
				await wait(0.14)
				if halted():
					return
			await wait(0.4)
		"blink_slam":
			for i in 3:
				var near := room.to_local(target_pos()) + Vector2.from_angle(randf() * TAU) * 40.0 if room else position
				await blink_to(near, 0.2, 0.12)
				if halted():
					return
				circle_at(global_position + Vector2(0, -10), 44.0, 0.45, 16, sp)
				await wait(0.55)
				if halted():
					return
		"bounce_storm":
			anim_state = EntityVisual.ATTACK
			make_bouncy(ring(18, sp), 3)
			await wait(0.5)
			make_bouncy(spread(7, 0.15, sp * 1.4), 2)
			await wait(0.6)


## Instead of dying in stage 1, the Tyrant bounces back.
func die() -> void:
	if stage == 1 and not is_dying:
		_bounce_back()
		return
	super()


func _bounce_back() -> void:
	stage = 2
	busy = true
	interrupt()
	health.invulnerable = true
	contact_enabled = false
	clear_bullets()
	get_tree().call_group("enemies", "_kill_if_add", self)
	anim_state = EntityVisual.HURT
	visual.flash(0.8)
	Events.camera_shake_requested.emit(8.0, 0.8)
	Audio.play_sfx("boss_roar", 0.0)
	await wait(0.8)
	if room:
		await blink_to(room.center + Vector2(0, 10), 0.3, 0.3)
	if is_dying:
		return
	health.invulnerable = true
	contact_enabled = false
	anim_state = EntityVisual.SUMMON
	var tw := create_tween().set_parallel()
	tw.tween_property(visual, "modulate", STAGE2_TINT, 0.6)
	tw.tween_property(visual, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_BACK)
	await wait(0.6)
	# New boss bar: the HUD and music react to boss_spawned.
	phase = 1
	boss_name = STAGE2_NAME
	health.setup(STAGE2_HP)
	Events.boss_spawned.emit(boss_name, STAGE2_HP)
	Events.camera_shake_requested.emit(10.0, 0.6)
	ring(32, data.projectile_speed)
	ring(32, data.projectile_speed * 0.6)
	attack_gap = 0.3
	await wait(0.8)
	health.invulnerable = false
	contact_enabled = true
	anim_state = &""
	resume_attacks()
	busy = false
	_next_attack = 0.4
