extends Node
## Autoload "Events": global signals only, no logic.
## Systems talk through these so they never need to find each other
## (the HUD never looks for the player, enemies never look for RunState).

@warning_ignore_start("unused_signal")

signal player_health_changed(current: int, maximum: int)
signal player_died(killer: String)
signal enemy_killed(data: EnemyData, position: Vector2)
signal run_ash_changed(total: int)
signal room_entered(coord: Vector2i, room_type: int)
signal room_cleared(coord: Vector2i)
signal floor_started(floor_index: int)
signal floor_exit_reached()
signal boss_spawned(boss_name: String, max_hp: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_defeated()
signal camera_shake_requested(strength: float, duration: float)
## Banked Ash or upgrade levels changed (shop purchase, run banked, save reset).
signal meta_changed()
