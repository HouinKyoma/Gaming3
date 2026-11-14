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
		Audio.play_hall_music()
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
	var t := Theme.new()
	t.default_font_size = 10
	var accent := UIKit.ACCENT

	# Buttons: dark ember panels with a warm border that lights up on hover / focus.
	t.set_stylebox("normal", "Button", _box(Color("#1c1419"), Color("#5a3a2e")))
	t.set_stylebox("hover", "Button", _box(Color("#2b1b1e"), accent))
	t.set_stylebox("pressed", "Button", _box(Color("#3d2216"), accent.lightened(0.3)))
	t.set_stylebox("disabled", "Button", _box(Color("#141014"), Color("#2e2428")))
	var focus := _box(Color(0, 0, 0, 0), accent)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color("#e8dcd4"))
	t.set_color("font_hover_color", "Button", accent.lightened(0.2))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", accent.lightened(0.2))
	t.set_color("font_disabled_color", "Button", Color("#6a5e64"))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 2)

	# Panels
	var panel := _box(Color(0.07, 0.05, 0.08, 0.92), Color("#4a3028"))
	panel.set_content_margin_all(6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# Labels get a soft shadow so they read over the animated backgrounds.
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# Sliders / checkboxes in Settings
	t.set_stylebox("slider", "HSlider", _box(Color("#1c1419"), Color("#5a3a2e")))
	t.set_stylebox("grabber_area", "HSlider", _box(accent.darkened(0.3), accent))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(accent, accent.lightened(0.3)))

	get_tree().root.theme = t


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


# --- Admin keys (F1-F5) -----------------------------------------------------------
## Admin controls (F1-F5 keys and the "Reset save" button on the title screen).
## On in every build, including the itch.io export. Set to false to hide them from players.
const ADMIN_CONTROLS := true


func _unhandled_input(event: InputEvent) -> void:
	if not ADMIN_CONTROLS:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			Save.add_ash_debug(100)
			print("[admin] +100 Ash, total %d" % Save.get_ash())
		KEY_F2:
			get_tree().call_group("enemies", "die")
			print("[admin] killed all enemies")
		KEY_F3:
			if Run.active:
				Events.floor_exit_reached.emit()
				print("[admin] skip to next floor")
		KEY_F4:
			var player := get_tree().get_first_node_in_group("player") as Player
			if player:
				player.god_mode = not player.god_mode
				print("[admin] god mode: %s" % player.god_mode)
		KEY_F5:
			Save.reset_save()
			print("[admin] save reset")
