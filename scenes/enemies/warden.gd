extends Boss
## THE HOLLOW REAPER (floor 3 boss). Sprite: Kronovi's "Undead Executioner".
## Fast, aggressive, built around its scythe. Scythe hits take a FULL heart.
## Every swing shows a red pie-slice first, but not for long: keep moving.
##   reap        rushes you and chains sweeps (2, 3 at P3, 4 in stage 2); each sweep flings
##               a crescent of blade shards
##   throw       hurls 3 (P2+: 5) spinning scythes that come back to it, and fires bouncing
##               rings while they fly
##   dash_reap   2-3 fast dashes, each ending in a full spin and a ring of shards
##   whirl       chases you spinning the scythe, spraying a rotating cross of bullets
##   soul_wave   (P2+) crescents of shards with a heavy blade in the middle
##   execution   (P3+) vanishes, appears right next to you and spins the scythe all around:
##               dash out NOW
## STAGE 2 "The Reaper Unbound": longer combos, more scythes, faster everything.
## Numbers not listed here are in data/enemies/warden.tres.

const REACH := 66.0           ## how far a sweep reaches
const SWEEP_HALF := 1.2       ## half the sweep's angle (radians): ~140 degrees in total
const BLADE := Color("#c9d3ff")
const SCYTHE_DAMAGE := 2


func _boss_ready() -> void:
	muzzle = Vector2(0, -30)
	attack_gap = 0.45
	max_adds = 0
	stage_hp = [data.max_hp, 200]
	stage_names = [data.display_name, "The Reaper Unbound"]
	subtitle = "Harvester of Souls"
	stage_tint = Color(0.6, 0.8, 1.3)


func _on_phase_changed(p: int) -> void:
	attack_gap = [0.45, 0.35, 0.28][p - 1] * (0.75 if stage >= 2 else 1.0)
	make_bouncy(ring(14, data.projectile_speed), 1)


func _on_stage_changed(_stage: int) -> void:
	attack_gap = 0.3


func _attacks_for_phase(p: int) -> Array:
	if stage >= 2:
		return ["reap", "throw", "dash_reap", "whirl", "soul_wave", "execution", "reap"]
	match p:
		1:
			return ["reap", "throw", "dash_reap", "whirl"]
		2:
			return ["reap", "throw", "dash_reap", "whirl", "soul_wave"]
	return ["reap", "throw", "dash_reap", "whirl", "soul_wave", "execution"]


func _move(_delta: float) -> Vector2:
	return dir_to_target() * data.move_speed * (1.3 if stage >= 2 else 1.0)


## Where the blade swings from (the Reaper's chest).
func _blade_origin() -> Vector2:
	return global_position + Vector2(0, -22)


func _aim_from_blade() -> Vector2:
	var d := (target_pos() + Vector2(0, -6)) - _blade_origin()
	return d.normalized() if d.length() > 0.1 else Vector2.RIGHT


func _slash(dir: Vector2, radius: float, half: float, warn: float) -> void:
	var h := sweep(dir, radius, half, warn, 0.12, 0.0, BossHazard.WARN, _blade_origin())
	h.damage = SCYTHE_DAMAGE


func _shards(dir: Vector2, count: int, speed: float) -> void:
	for b in spread(count, 0.18, speed, dir):
		b.glow = BLADE


func _attack(attack_name: String) -> void:
	var sp := data.projectile_speed
	var s2 := stage >= 2
	match attack_name:
		"reap":
			var swings := 4 if s2 else (3 if phase >= 3 else 2)
			for i in swings:
				var d := distance_to_target()
				if d > REACH - 14.0:
					await charge(dir_to_target(), 300.0, clampf((d - 34.0) / 300.0, 0.05, 0.5))
					if halted():
						return
				anim_state = EntityVisual.WINDUP
				var dir := _aim_from_blade()
				var warn := 0.42 if i == 0 else 0.3
				_slash(dir, REACH, SWEEP_HALF, warn)
				await wait(warn)
				if halted():
					return
				anim_state = EntityVisual.ATTACK
				_shards(dir, 5, sp * 1.1)
				await wait(0.18)
				if halted():
					return
			await wait(0.35)

		"throw":
			anim_state = EntityVisual.WINDUP
			visual.flash(0.25)
			await wait(0.3)
			if halted():
				return
			anim_state = EntityVisual.ATTACK
			var dir := aim()
			var n := 5 if (phase >= 2 or s2) else 3
			for k in n:
				var off := (k - (n - 1) / 2.0) * 0.45
				var sc := throw_scythe(dir.rotated(off), 170.0 - absf(off) * 40.0, 215.0)
				sc.damage = SCYTHE_DAMAGE
			for i in 3:
				await wait(0.45)
				if halted():
					return
				make_bouncy(ring(10 + 2 * phase, sp * 0.9), 1)
			if s2:
				for k in 3:
					var sc2 := throw_scythe(aim().rotated((k - 1) * 0.35), 170.0, 230.0)
					sc2.damage = SCYTHE_DAMAGE
				await wait(0.9)

		"dash_reap":
			for i in (3 if s2 or phase >= 3 else 2):
				await telegraph(0.4 if i == 0 else 0.25)
				if halted():
					return
				var hit: bool = await charge(aim(), data.charge_speed, data.charge_time)
				if halted():
					return
				if hit:
					Events.camera_shake_requested.emit(4.0, 0.2)
				anim_state = EntityVisual.ATTACK
				_slash(Vector2.RIGHT, 48.0, PI, 0.28)
				await wait(0.28)
				if halted():
					return
				var shards := ring(12, sp)
				_tint(shards)
			await wait(0.4)

		"whirl":
			anim_state = EntityVisual.ATTACK
			var steps := 11 if s2 else 8
			var a := randf() * TAU
			for i in steps:
				move_vel = dir_to_target() * data.move_speed * 1.7
				_slash(Vector2.RIGHT, 40.0, PI, 0.32)
				for k in 4:
					var b := shoot(Vector2.from_angle(a + TAU * k / 4.0), sp * 0.9)
					b.glow = BLADE
				a += 0.35
				await wait(0.25)
				if halted():
					return
			move_vel = Vector2.ZERO
			await wait(0.3)

		"soul_wave":
			anim_state = EntityVisual.WINDUP
			await wait(0.25)
			if halted():
				return
			anim_state = EntityVisual.ATTACK
			for wave in (3 if s2 else 2):
				var dir := aim()
				_shards(dir.rotated(-0.1 if wave % 2 else 0.1), 9, sp * 1.05)
				heavy_shot(dir, sp * 1.15)
				await wait(0.35)
				if halted():
					return

		"execution":
			for i in (2 if s2 else 1):
				var behind := room.to_local(target_pos()) + Vector2.from_angle(randf() * TAU) * 30.0 if room else position
				await blink_to(behind, 0.2, 0.1)
				if halted():
					return
				anim_state = EntityVisual.WINDUP
				_slash(Vector2.RIGHT, 58.0, PI, 0.5)
				await wait(0.5)
				if halted():
					return
				anim_state = EntityVisual.ATTACK
				make_heavy(ring(8, sp * 0.9))
				make_bouncy(ring(12, sp), 1)
				await wait(0.35)
				if halted():
					return


func _tint(bullets: Array) -> void:
	for b: Projectile in bullets:
		b.glow = BLADE
