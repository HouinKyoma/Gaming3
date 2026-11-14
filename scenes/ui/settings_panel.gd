class_name SettingsPanel
extends PanelContainer
## Music / SFX volume and fullscreen. Used by the title screen and the pause menu.
## Changes apply immediately and are saved when the panel closes.

signal closed


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(UIKit.label("Settings", 14, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))

	var s: Dictionary = Save.data["settings"]
	box.add_child(_slider_row("Music", float(s.get("music", 0.8)), "music"))
	box.add_child(_slider_row("Sound", float(s.get("sfx", 1.0)), "sfx"))

	if not OS.has_feature("web"):
		var full := CheckBox.new()
		full.text = "Fullscreen"
		full.button_pressed = bool(s.get("fullscreen", false))
		full.toggled.connect(func(on: bool) -> void: Audio.set_setting("fullscreen", on))
		box.add_child(full)

	var back := UIKit.button("Back", _on_back)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _slider_row(text: String, value: float, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UIKit.label(text, 10)
	l.custom_minimum_size = Vector2(48, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(120, 12)
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	return row


func _on_slider_changed(value: float, key: String) -> void:
	Audio.set_setting(key, value)
	if key == "sfx":
		Audio.play_sfx("ui_click", 0.0)


func _on_back() -> void:
	Save.save_game()
	closed.emit()
	queue_free()
