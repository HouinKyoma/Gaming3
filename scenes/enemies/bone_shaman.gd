extends Boss
## The Bone Shaman (floor 2 boss). Keeps its distance and blinks around the room.
##   P1:         bouncing skull volleys, blink + ring, bone rain (warning circles), crawler summons
##   P2 (< 66%): + aimed beams (3 in a row, re-aimed each time); bone rain spits bullets
##   P3 (< 33%): + skull storm (bouncing, curving ring), double blinks, shorter rests
## Numbers not listed here are in data/enemies/bone_shaman.tres.

const MIN_RANGE := 110.0
const MAX_RANGE := 170.0

var _strafe := 1.0


func _boss_ready() -> void:
	muzzle = Vector2(0, -22)
	attack_gap = 0.7
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.7, 0.55, 0.4][p - 1]
	make_bouncy(ring(16, data.projectile_speed), 1)


func _attacks_for_phase(p: int) -> Array:
	match p:
		1:
			return ["skulls", "blink", "rain", "summon"]
		2:
			return ["skulls", "blink", "rain", "beam", "summon"]
	return ["skulls", "blink", "rain", "beam", "storm", "summon"]


func _move(_delta: float) -> Vector2:
	var d := distance_to_target()
	var dir := dir_to_target()
	if d < MIN_RANGE:
		return -dir * data.move_speed
	if d > MAX_RANGE:
		return dir * data.move_speed
	return dir.orthogonal() * data.move_speed * 0.6 * _strafe


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	match attack_name:
		"skulls":
			anim_state = EntityVisual.ATTACK
			for volley in 2:
				make_bouncy(spread(3 + phase * 2, 0.22, sp), 3)
				await wait(0.45)
				if halted():
					return
		"blink":
			for i in (2 if phase >= 3 else 1):
				var to := room.random_free_point(room.to_local(target_pos()), 120.0) if room else position
				await blink_to(to)
				if halted():
					return
				anim_state = EntityVisual.ATTACK
				ring(14 + 2 * phase, sp)
				await wait(0.25)
				ring(14 + 2 * phase, sp * 0.7)
				await wait(0.3)
				if halted():
					return
		"rain":
			anim_state = EntityVisual.SUMMON
			var bullets := 0 if phase == 1 else 6
			for i in 4 + phase * 2:
				var at := target_pos() + Vector2(randf_range(-40, 40), randf_range(-30, 30))
				if i == 0:
					at = target_pos()
				circle_at(at + Vector2(0, -4), 22.0, 0.75, bullets, sp * 0.9)
				await wait(0.16)
				if halted():
					return
			await wait(0.5)
		"beam":
			anim_state = EntityVisual.WINDUP
			for i in 3:
				beam_from(gpos(), aim(), 0.6, 0.45, 8.0)
				await wait(0.75)
				if halted():
					return
		"storm":
			anim_state = EntityVisual.ATTACK
			var bullets := ring(18, sp)
			make_bouncy(bullets, 2)
			make_curvy(bullets, 0.9)
			await wait(0.4)
			var more := ring(18, sp * 0.8)
			make_curvy(more, -0.9)
			await wait(0.6)
		"summon":
			summon(["crawler", "crawler", "crawler"] if phase < 3 else ["crawler", "crawler", "spitter"])
			await wait(0.6)
