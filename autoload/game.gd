extends Node
## Autoload "Game": scene switching, input map, global UI theme and debug keys.

const TITLE := "res://scenes/ui/title.tscn"
const HUB := "res://scenes/ui/hub.tscn"
const RUN := "res://scenes/run/run.tscn"
const DEATH := "res://scenes/ui/death_screen.tscn"
const VICTORY := "res://scenes/ui/victory.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_theme()
	Audio.play_music.call_deferred("menu_loop")


# --- Scene flow --------------------------------------------------------------------

func goto(path: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(path)
	if path == RUN:
		Audio.play_music("run_loop")
	elif path == DEATH:
		Audio.stop_music()
	else:
		Audio.play_music("menu_loop")


func start_run() -> void:
	Run.start_new_run()
	goto(RUN)


func goto_hub() -> void:
	goto(HUB)


func goto_title() -> void:
	goto(TITLE)


func show_death() -> void:
	goto(DEATH)


func show_victory() -> void:
	goto(VICTORY)


# --- Input map ---------------------------------------------------------------------
# Actions are registered in code so the project works without editing Project Settings.
# If you add an action in Project Settings > Input Map, that version is kept instead.

func _setup_input() -> void:
	_add_action(&"move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action(&"move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action(&"move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action(&"move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action(&"shoot", [], [MOUSE_BUTTON_LEFT], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action(&"dash", [KEY_SPACE, KEY_SHIFT], [MOUSE_BUTTON_RIGHT], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action(&"interact", [KEY_E], [], [])
	_add_action(&"pause", [KEY_ESCAPE, KEY_P], [], [])


func _add_action(action: StringName, keys: Array, mouse_buttons: Array, joy_axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in mouse_buttons:
		var mev := InputEventMouseButton.new()
		mev.button_index = button
		InputMap.action_add_event(action, mev)
	for axis_def in joy_axes:
		var jev := InputEventJoypadMotion.new()
		jev.axis = axis_def[0]
		jev.axis_value = axis_def[1]
		InputMap.action_add_event(action, jev)


func _setup_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 10
	get_tree().root.theme = ui_theme


# --- Debug keys (only in debug builds, i.e. when run from the editor) ---------------

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			Save.add_ash_debug(100)
			print("[debug] +100 Ash, total %d" % Save.get_ash())
		KEY_F2:
			get_tree().call_group("enemies", "die")
			print("[debug] killed all enemies")
		KEY_F3:
			if Run.active:
				Events.floor_exit_reached.emit()
				print("[debug] skip to next floor")
		KEY_F4:
			var player := get_tree().get_first_node_in_group("player") as Player
			if player:
				player.god_mode = not player.god_mode
				print("[debug] god mode: %s" % player.god_mode)
		KEY_F5:
			Save.reset_save()
			print("[debug] save reset")
