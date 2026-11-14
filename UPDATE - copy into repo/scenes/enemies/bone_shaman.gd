extends Boss
## THE NECROMANCER (floor 2 boss). Sprite: CreativeKind's "Necromancer (Free)".
## Keeps its distance, strafes while casting, blinks away, and fights with the dead.
## Bullets: purple = soul bolts (some home in), green = bouncing bones (used sparingly),
## big red-orange = HEAVY (full heart).
##   soul_bolts    a stream of homing bolts while it strafes; every fourth one is a heavy skull
##   skull_barrage 2-3 volleys of bouncing bones (2 bounces) fanned at you
##   raise_dead    graves burst open around you (shrapnel), Lost Spirits and goblins climb out
##   curse         poison pools under your feet, with a few soul bolts
##   blink         teleports away, bursts a ring and throws a heavy skull (twice in stage 2)
##   bone_prison   (P2+) graves close around you (one gap) and a heavy skull flies at the middle
##   death_nova    (P3+) bouncing ring + curving ring + heavy homing skulls
## STAGE 2 "The Necromancer, Undying": everything faster and denser, barely rests.
## Numbers not listed here are in data/enemies/bone_shaman.tres.

const MIN_RANGE := 100.0
const MAX_RANGE := 160.0
const SOUL := Color("#b46bff")
const CURSE := Color("#46d17c")

var _strafe := 1.0


func _boss_ready() -> void:
	muzzle = Vector2(0, -32)
	attack_gap = 0.75
	max_adds = 6
	_strafe = 1.0 if randf() < 0.5 else -1.0
	stage_hp = [data.max_hp, 170]
	stage_names = [data.display_name, "The Necromancer, Undying"]
	subtitle = "Lord of the Restless Dead"
	stage_tint = Color(1.15, 0.7, 1.35)


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.75, 0.65, 0.55][p - 1] * (0.85 if stage >= 2 else 1.0)
	_tint(ring(14, data.projectile_speed * 0.85), SOUL)


func _on_stage_changed(_stage: int) -> void:
	attack_gap = 0.6


func _attacks_for_phase(p: int) -> Array:
	if stage >= 2:
		return ["soul_bolts", "skull_barrage", "raise_dead", "curse", "blink", "bone_prison", "death_nova"]
	match p:
		1:
			return ["soul_bolts", "skull_barrage", "raise_dead", "curse", "blink"]
		2:
			return ["soul_bolts", "skull_barrage", "raise_dead", "curse", "blink", "bone_prison"]
	return ["soul_bolts", "skull_barrage", "raise_dead", "curse", "blink", "bone_prison", "death_nova"]


func _move(_delta: float) -> Vector2:
	var d := distance_to_target()
	var dir := dir_to_target()
	if d < MIN_RANGE:
		return -dir * data.move_speed * 1.2
	if d > MAX_RANGE:
		return dir * data.move_speed
	return dir.orthogonal() * data.move_speed * 0.6 * _strafe


func _tint(bullets: Array, c: Color) -> void:
	for b: Projectile in bullets:
		b.glow = c


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	var s2 := stage >= 2
	match attack_name:
		"soul_bolts":
			anim_state = EntityVisual.ATTACK
			var count := 4 + phase + (2 if s2 else 0)
			for i in count:
				move_vel = dir_to_target().orthogonal() * data.move_speed * 0.7 * _strafe
				if i % 4 == 3:
					var h := heavy_shot(aim(), sp * 0.9)
					h.homing = 1.6
					h.homing_time = 1.0
				else:
					homing_shot(aim().rotated(randf_range(-1.0, 1.0)), sp * 0.95, 1.7, 1.0, SOUL)
				await wait(0.18 if s2 else 0.22)
				if halted():
					return
			move_vel = Vector2.ZERO

		"skull_barrage":
			anim_state = EntityVisual.ATTACK
			for volley in 2 + (1 if s2 else 0):
				make_bouncy(spread(3 + phase, 0.26, sp), 2)
				await wait(0.4)
				if halted():
					return

		"raise_dead":
			anim_state = EntityVisual.SUMMON
			if room == null:
				await wait(0.3)
				return
			var count := 2 + (1 if phase >= 2 else 0) + (1 if s2 else 0)
			var graves: Array[Vector2] = []
			for i in count:
				var off := Vector2.from_angle(TAU * i / count + randf()) * randf_range(40.0, 65.0)
				var at_local := room.nearest_free(room.to_local(target_pos()) + off)
				graves.append(at_local)
				var c := circle_at(room.to_global(at_local) + Vector2(0, -4), 14.0, 0.95, 4, sp * 0.75)
				c.color = CURSE
			await wait(0.95)
			if halted():
				return
			for at_local in graves:
				var id := "spirit" if randf() < 0.6 else "crawler"
				var add := Content.get_enemy(id)
				if add and room.alive <= max_adds:
					room.spawn_enemy(add, at_local, 1.0)
			await wait(0.3)

		"curse":
			anim_state = EntityVisual.SUMMON
			var count := 3 + phase + (1 if s2 else 0)
			var size := 24.0 if s2 else 20.0
			for i in count:
				var at := target_pos()
				if i > 0:
					at += Vector2(randf_range(-50, 50), randf_range(-35, 35))
				pool(at + Vector2(0, -2), size, 0.7, 2.6, CURSE)
				if i % 3 == 0:
					_tint(spread(3, 0.35, sp), SOUL)
				await wait(0.32)
				if halted():
					return

		"blink":
			for i in (2 if s2 else 1):
				var to := room.random_free_point(room.to_local(target_pos()), 110.0) if room else position
				await blink_to(to, 0.18, 0.12)
				if halted():
					return
				anim_state = EntityVisual.ATTACK
				var r := ring(10 + 2 * phase, sp * 0.8)
				if s2 and i == 1:
					make_bouncy(r, 1)
				else:
					_tint(r, SOUL)
				heavy_shot(aim(), sp * 0.95)
				await wait(0.4)
				if halted():
					return

		"bone_prison":
			anim_state = EntityVisual.WINDUP
			var center := target_pos()
			var n := 12
			var gap := randi_range(0, n - 1)
			for k in n:
				if k == gap or k == (gap + 1) % n:
					continue   # the way out
				var at := center + Vector2.from_angle(TAU * k / n) * 46.0
				circle_at(at + Vector2(0, -4), 14.0, 1.15, 0, sp * 0.8)
			await wait(0.5)
			heavy_shot(((center + Vector2(0, -6)) - gpos()).normalized(), sp * 0.7)
			await wait(0.65)
			if halted():
				return
			anim_state = EntityVisual.ATTACK
			await wait(0.3)

		"death_nova":
			anim_state = EntityVisual.ATTACK
			make_bouncy(ring(12, sp * 0.85), 1)
			await wait(0.3)
			if halted():
				return
			var curl := ring(12, sp * 0.75)
			make_curvy(curl, 0.8 if randf() < 0.5 else -0.8)
			await wait(0.3)
			if halted():
				return
			for i in (2 if s2 else 1):
				var h := heavy_shot(aim().rotated((i - 0.5) * 0.5 if s2 else 0.0), sp * 0.8)
				h.homing = 1.4
				h.homing_time = 1.2
			await wait(0.5)
