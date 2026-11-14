extends Boss
## THE ASHEN TYRANT (final boss, floor 4). Sprite: 0x72's big demon (CC0).
## A fire demon. Big red-orange bullets are HEAVY (full heart); meteors also hit for a full heart.
##   breath        a turning cone of fire while embers spray out of it
##   meteors       rocks fall on you and burst into embers
##   lava_pools    lava appears around you while heavy fireballs are thrown at you
##   stomp_charge  2-4 charges; slamming a wall throws a ring of embers and bouncing rocks
##   fireballs     heavy bouncing fireballs that ricochet around the room
##   fire_wall     (P2+) walls of fire sweep across the room: find the gap
##   eruption      (P2+) two rings of eruptions around the Tyrant, then a heavy burst
##   summon_imps   (P3+) calls imps
## At 0 HP it BOUNCES BACK (see Boss._bounce_back) into STAGE 2 "The Tyrant Reborn":
##   wider breath that turns faster, meteor storms, walls from three sides, more of everything.
## Numbers not listed here are in data/enemies/tyrant.tres.

const FIRE := Color("#ff8a2a")
const LAVA := Color("#ff5a14")


func _boss_ready() -> void:
	muzzle = Vector2(0, -30)
	attack_gap = 0.45
	max_adds = 5
	stage_hp = [data.max_hp, 360]
	stage_names = [data.display_name, "The Tyrant Reborn"]
	subtitle = "Lord of the Ashen Throne"
	stage_tint = Color(1.0, 0.55, 0.45)


func _on_stage_changed(_stage: int) -> void:
	attack_gap = 0.3


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.45, 0.35, 0.28][p - 1] * (0.7 if stage >= 2 else 1.0)
	_embers(ring(18, data.projectile_speed * 0.8))


func _attacks_for_phase(p: int) -> Array:
	if stage >= 2:
		return ["breath", "meteors", "lava_pools", "stomp_charge", "fireballs", "fire_wall", "eruption", "summon_imps"]
	match p:
		1:
			return ["breath", "meteors", "lava_pools", "stomp_charge", "fireballs"]
		2:
			return ["breath", "meteors", "lava_pools", "stomp_charge", "fireballs", "fire_wall", "eruption"]
	return ["breath", "meteors", "lava_pools", "stomp_charge", "fireballs", "fire_wall", "eruption", "summon_imps"]


func _move(_delta: float) -> Vector2:
	var speed := data.move_speed * (1.3 if phase >= 3 else 1.0) * (1.25 if stage == 2 else 1.0)
	return dir_to_target() * speed


func _embers(bullets: Array) -> void:
	for b: Projectile in bullets:
		b.glow = FIRE


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	var s2 := stage >= 2
	match attack_name:
		"breath":
			anim_state = EntityVisual.WINDUP
			var dir := aim()
			var spin := (0.75 if randf() < 0.5 else -0.75) * (1.5 if s2 else 1.0)
			var length := 2.0 if s2 else 1.5
			var radius := 135.0 if s2 else 115.0
			var half := 0.5 if s2 else 0.42
			sweep(dir, radius, half, 0.55, length, spin, FIRE, gpos())
			await wait(0.55)
			if halted():
				return
			anim_state = EntityVisual.ATTACK
			Audio.play_sfx("boss_roar", 0.1, -8.0)
			var t := 0.0
			var cur := dir
			while t < length:
				cur = cur.rotated(spin * 0.2)
				_embers(spread(3, 0.3, sp * 1.1, cur.rotated(PI)))   # embers fly out the back
				make_bouncy(spread(2, 0.6, sp, cur), 1)
				await wait(0.2)
				if halted():
					return
				t += 0.2

		"meteors":
			anim_state = EntityVisual.SUMMON
			var count := 6 + phase + (4 if s2 else 0)
			var bullets := 8 if s2 else (6 if phase >= 2 else 4)
			for i in count:
				var at := target_pos() + (Vector2.ZERO if i % 2 == 0 else Vector2(randf_range(-45, 45), randf_range(-30, 30)))
				var c := circle_at(at + Vector2(0, -4), 26.0, 0.75, bullets, sp * 0.75)
				c.color = FIRE
				c.damage = 2
				await wait(0.2 if s2 else 0.24)
				if halted():
					return
			await wait(0.3)

		"lava_pools":
			anim_state = EntityVisual.SUMMON
			var count := 4 + (2 if s2 else 0)
			for i in count:
				var at := target_pos()
				if i > 0:
					at += Vector2.from_angle(randf() * TAU) * randf_range(30.0, 65.0)
				pool(at, 24.0, 0.6, 4.5, LAVA)
				if i % 2 == 1:
					heavy_shot(aim(), sp * 1.1)
				await wait(0.22)
				if halted():
					return
			await wait(0.3)

		"stomp_charge":
			var count := (3 if phase >= 3 else 2) + (1 if s2 else 0)
			for i in count:
				await telegraph(0.45 if i == 0 else 0.3)
				if halted():
					return
				var hit: bool = await charge(aim(), data.charge_speed, data.charge_time)
				if halted():
					return
				if hit:
					_embers(ring(14, sp * 0.85))
					for k in 3:
						heavy_bouncer(Vector2.from_angle(randf() * TAU), sp * 0.8, 2)
			await wait(0.5)

		"fireballs":
			anim_state = EntityVisual.ATTACK
			for v in (3 if s2 else 2):
				for k in 3:
					heavy_bouncer(aim().rotated((k - 1) * 0.45), sp * 0.95, 3)
				await wait(0.5)
				if halted():
					return

		"fire_wall":
			anim_state = EntityVisual.SUMMON
			var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			if s2:
				bullet_wall(Vector2i.LEFT, sp * 0.9, 4)
				bullet_wall(Vector2i.RIGHT, sp * 0.9, 4)
				await wait(1.1)
				if halted():
					return
				bullet_wall(sides.pick_random(), sp, 4)
				await wait(1.0)
			else:
				var first: Vector2i = sides.pick_random()
				bullet_wall(first, sp * 0.9, 4)
				await wait(0.9)
				if halted():
					return
				sides.erase(first)
				bullet_wall(sides.pick_random(), sp * 0.9, 4)
				await wait(0.9)

		"eruption":
			anim_state = EntityVisual.SUMMON
			for k in 8:
				var c := circle_at(global_position + Vector2.from_angle(TAU * k / 8.0) * 40.0 + Vector2(0, -6), 21.0, 0.7)
				c.color = FIRE
			await wait(0.4)
			if halted():
				return
			for k in 12:
				var c := circle_at(global_position + Vector2.from_angle(TAU * (k + 0.5) / 12.0) * 92.0 + Vector2(0, -6), 21.0, 0.7)
				c.color = FIRE
			await wait(0.7)
			if halted():
				return
			make_heavy(ring(10, sp * 0.8))
			await wait(0.3)

		"summon_imps":
			summon(["swarmer", "swarmer", "swarmer", "swarmer"] if s2 else ["swarmer", "swarmer", "swarmer"], 44.0)
			_embers(ring(16, sp * 0.85))
			await wait(0.4)
