class_name BouncePrompt
extends Label
## The blinking "PRESS SPACE TO BOUNCE BACK" line (title screen and death screen).
## Emits `pressed` when Space (or gamepad A) is pressed. Set `enabled = false` to ignore input.

signal pressed

const TEXT := "PRESS SPACE TO BOUNCE BACK"

var enabled := true
## Ignore input for this long after appearing, so mashing Space in a fight can't skip the screen.
var input_delay := 0.0


func _ready() -> void:
	text = TEXT
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", UIKit.ACCENT)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.25, 0.55)
	tween.tween_property(self, "modulate:a", 1.0, 0.55)


func _process(delta: float) -> void:
	input_delay = maxf(input_delay - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not enabled or input_delay > 0.0 or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var is_space := key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_SPACE or key.keycode == KEY_SPACE)
	var is_pad_a := pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A
	if is_space or is_pad_a:
		get_viewport().set_input_as_handled()
		enabled = false
		Audio.play_sfx("ui_click", 0.0)
		pressed.emit()
