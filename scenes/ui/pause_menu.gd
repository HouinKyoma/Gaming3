extends CanvasLayer
## Esc / P pauses. Abandoning a run still banks the Ash collected so far.

var _root: Control


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	UIKit.background(_root, Color(0, 0, 0, 0.6))

	var box := UIKit.center_box(_root, 6)
	box.add_child(UIKit.label("Paused", 16, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))
	box.add_child(UIKit.button("Resume", _on_resume))
	box.add_child(UIKit.button("Settings", _open_settings))
	box.add_child(UIKit.button("Abandon run (keeps your Ash)", _on_abandon))
	box.add_child(UIKit.button("Quit to title", _on_quit_to_title))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if not Run.active:
			return
		if get_tree().paused and not _root.visible:
			return   # something else (the boon choice) has paused the game
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_HIDDEN


func _open_settings() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := SettingsPanel.new()
	panel.closed.connect(center.queue_free)
	center.add_child(panel)


func _on_resume() -> void:
	_set_open(false)


func _on_abandon() -> void:
	Run.end_run(false, "Gave up")
	Game.show_death()


func _on_quit_to_title() -> void:
	Run.end_run(false, "Gave up")
	Game.goto_title()
