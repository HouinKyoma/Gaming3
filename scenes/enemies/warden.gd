extends Boss
## The Hollow Warden (floor 3 boss).
##   P1:         ring bursts, aimed bullet streams, bouncing orbs, a charge
##   P2 (< 66%): + leap slam, cross beams, summons; charges twice in a row
##   P3 (< 33%): + spiral storm, rotating beams; charges three times; faster and shorter rests
## Numbers not listed here are in data/enemies/warden.tres.


func _boss_ready() -> void:
	muzzle = Vector2(0, -16)
	attack_gap = 0.65


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.65, 0.5, 0.35][p - 1]
	ring(22, data.projectile_speed * 0.8)


func _attacks_for_phase(p: int) -> Array:
	match p:
		1:
			return ["rings", "stream", "orbs", "charge"]
		2:
			return ["rings", "stream", "orbs", "charge", "slam", "beams", "summon"]
	return ["stream", "orbs", "charge", "slam", "beams", "spiral", "summon", "slam"]


func _move(_delta: float) -> Vector2:
	return dir_to_target() * data.move_speed * (1.35 if phase >= 3 else 1.0)


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
			for i in phase:
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
		"summon":
			var ids := ["swarmer", "swarmer", "swarmer"]
			if phase >= 3:
				ids.append("charger")
			summon(ids)
			await wait(0.6)
