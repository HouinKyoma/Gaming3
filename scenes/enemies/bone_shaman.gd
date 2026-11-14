extends Boss
## The Bone Shaman (floor 2 boss). Keeps its distance and blinks around the room.
##   P1:         bouncing skull volleys, blink + ring, bone rain (warning circles), crawler summons
##   P2 (< 66%): + aimed beams (3 in a row, re-aimed each time); bone rain spits bullets
##   P3 (< 33%): + skull storm (bouncing, curving ring), double blinks, shorter rests
## STAGE 2 "The Bone Shaman, Risen": skull walls (find the gap), beam fans, heavier bone rain,
##   storms from the start; triple blinks.
## Numbers not listed here are in data/enemies/bone_shaman.tres.

const MIN_RANGE := 110.0
const MAX_RANGE := 170.0

var _strafe := 1.0


func _boss_ready() -> void:
	muzzle = Vector2(0, -32)
	attack_gap = 0.7
	_strafe = 1.0 if randf() < 0.5 else -1.0
	stage_hp = [data.max_hp, 240]
	stage_names = [data.display_name, "The Bone Shaman, Risen"]
	subtitle = "Keeper of the Ossuary"
	stage_tint = Color(1.25, 0.6, 0.95)


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.7, 0.55, 0.4][p - 1] * (0.6 if stage >= 2 else 1.0)
	make_bouncy(ring(16, data.projectile_speed), 1)


func _on_stage_changed(_stage: int) -> void:
	attack_gap = 0.4


func _attacks_for_phase(p: int) -> Array:
	if stage >= 2:
		var list := ["skulls", "blink", "rain", "storm", "skull_wall", "beam_fan"]
		if p >= 2:
			list.append("summon")
		return list
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
			for i in (3 if stage >= 2 else (2 if phase >= 3 else 1)):
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
			var bullets := 0 if phase == 1 and stage == 1 else 6
			for i in 4 + phase * 2 + (4 if stage >= 2 else 0):
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
		"skull_wall":
			anim_state = EntityVisual.SUMMON
			var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			bullet_wall(sides.pick_random(), sp * 0.85, 4)
			await wait(0.7)
			if halted():
				return
			make_bouncy(spread(5, 0.3, sp), 2)
			await wait(0.6)
		"beam_fan":
			anim_state = EntityVisual.WINDUP
			var base := aim()
			for k in 5:
				beam_from(gpos(), base.rotated((k - 2) * 0.35), 0.75, 0.5, 7.0)
			await wait(1.3)
		"summon":
			summon(["crawler", "crawler", "crawler"] if phase < 3 else ["crawler", "crawler", "spitter"])
			await wait(0.6)
