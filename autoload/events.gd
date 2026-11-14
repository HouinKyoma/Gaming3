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
## A boss wants its intro: Run locks the player, points the camera at it and shows BossIntro.
signal boss_intro_started(boss: Node2D, title: String, subtitle: String)
## Emitted by BossIntro when the intro ends (or is skipped); the boss starts fighting.
signal boss_intro_finished()
## HP of each stage of the boss (the boss bar draws one segment per stage).
signal boss_stages_set(stage_hp: Array)
## The boss bounced back into its next stage, under a new name.
signal boss_stage_changed(boss_name: String, stage: int)
signal camera_shake_requested(strength: float, duration: float)
## Banked Ash or upgrade levels changed (shop purchase, run banked, save reset).
signal meta_changed()
