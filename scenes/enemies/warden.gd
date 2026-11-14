extends Boss
## The Hollow Warden (floor 3 boss). Two stages.
## STAGE 1 "The Hollow Warden":
##   P1:         ring bursts, aimed bullet streams, bouncing orbs, a charge
##   P2 (< 66%): + leap slam, cross beams, summons; charges twice in a row
##   P3 (< 33%): + spiral storm, rotating beams; charges three times; faster and shorter rests
## STAGE 2 "The Warden Unchained": everything at once, plus grave rain (warning circles +
##   bouncing orbs) and crossfire (bullet walls from two sides). Rests half as long.
## Numbers not listed here are in data/enemies/warden.tres.


func _boss_ready() -> void:
	muzzle = Vector2(0, -40)
	attack_gap = 0.65
	stage_hp = [data.max_hp, 280]
	stage_names = [data.display_name, "The Warden Unchained"]
	subtitle = "Jailer of the Damned"
	stage_tint = Color(0.6, 0.8, 1.3)


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.65, 0.5, 0.35][p - 1] * (0.5 if stage >= 2 else 1.0)
	ring(22, data.projectile_speed * 0.8)


func _on_stage_changed(_stage: int) -> void:
	attack_gap = 0.35


func _attacks_for_phase(p: int) -> Array:
	if stage >= 2:
		var list := ["stream", "orbs", "charge", "slam", "beams", "spiral", "grave_rain", "crossfire"]
		if p >= 2:
			list.append("summon")
		return list
	match p:
		1:
			return ["rings", "stream", "orbs", "charge"]
		2:
			return ["rings", "stream", "orbs", "charge", "slam", "beams", "summon"]
	return ["stream", "orbs", "charge", "slam", "beams", "spiral", "summon", "slam"]


func _move(_delta: float) -> Vector2:
	return dir_to_target() * data.move_speed * (1.35 if phase >= 3 or stage >= 2 else 1.0)


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	match attack_name:
		"rings":
			anim_state = EntityVisual.ATTACK
			var offset := randf() * TAU
			for i in 2 + phase:
				ring(14 + 2 * phase, sp, offset + i * 0.13)
				await wait(0.3)
				if halted():
					return
		"stream":
			anim_state = EntityVisual.ATTACK
			for i in 6 + phase * 2:
				spread(3, 0.2, sp * 1.5)
				await wait(0.13)
				if halted():
					return
		"orbs":
			anim_state = EntityVisual.ATTACK
			var n := 6 + phase * 2
			make_bouncy(ring(n, sp * 0.9), 2)
			await wait(0.5)
		"charge":
			for i in (phase if stage == 1 else 3):
				await telegraph(0.55 if i == 0 else 0.3)
				if halted():
					return
				var hit: bool = await charge(aim(), data.charge_speed, data.charge_time)
				if hit:
					ring(10, sp)
				if halted():
					return
			await wait(0.6)   # the moment to punish it
		"slam":
			# Leap: a warning circle where the player stands, the Warden vanishes and lands on it.
			var land_local := room.nearest_free(room.to_local(target_pos())) if room else position
			var land := room.to_global(land_local) if room else global_position
			circle_at(land + Vector2(0, -6), 36.0, 0.9, 12 + 4 * phase, sp)
			anim_state = EntityVisual.WINDUP
			await blink_to(land_local, 0.3, 0.15)
			if halted():
				return
			await wait(0.5)
		"beams":
			anim_state = EntityVisual.WINDUP
			var base := aim().angle() + PI / 4.0
			var spin := 0.0
			if phase >= 3:
				spin = 0.7 if randf() < 0.5 else -0.7
			for k in 4:
				beam_from(gpos(), Vector2.from_angle(base + k * PI / 2.0), 0.8, 1.0, 9.0, spin)
			await wait(0.8)
			anim_state = EntityVisual.ATTACK
			await wait(1.0)
		"spiral":
			anim_state = EntityVisual.ATTACK
			var a := randf() * TAU
			for i in 34:
				for arm in 3:
					shoot(Vector2.from_angle(a + TAU * arm / 3.0), sp)
				a += 0.24
				await wait(0.07)
				if halted():
					return
		"grave_rain":
			anim_state = EntityVisual.SUMMON
			for i in 8:
				var at := target_pos() + (Vector2.ZERO if i % 2 == 0 else Vector2(randf_range(-60, 60), randf_range(-40, 40)))
				circle_at(at + Vector2(0, -4), 26.0, 0.75, 0, sp)
				if i % 3 == 0:
					make_bouncy(spread(3, 0.4, sp * 0.9), 2)
				await wait(0.2)
				if halted():
					return
			await wait(0.4)
		"crossfire":
			anim_state = EntityVisual.ATTACK
			var pairs := [[Vector2i.LEFT, Vector2i.UP], [Vector2i.RIGHT, Vector2i.DOWN], [Vector2i.LEFT, Vector2i.RIGHT]]
			var pair: Array = pairs.pick_random()
			bullet_wall(pair[0], sp * 0.9, 4)
			await wait(0.5)
			if halted():
				return
			bullet_wall(pair[1], sp * 0.9, 4)
			await wait(1.0)
		"summon":
			var ids := ["spirit", "spirit", "spirit", "spirit"]
			if phase >= 3:
				ids.append("charger")
			summon(ids)
			await wait(0.6)
