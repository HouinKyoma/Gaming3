extends Control
## Main scene. PRESS SPACE TO BOUNCE BACK starts a run straight away.
## The upgrade shop (the Threshold) is one click away once you have played a run.

const LOGO_PATH := "res://art/ui/logo.png"

var _prompt: BouncePrompt


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UIKit.background(self)
	var box := UIKit.center_box(self, 8)

	if ResourceLoader.exists(LOGO_PATH):
		box.add_child(UIKit.icon(LOGO_PATH))
	else:
		box.add_child(UIKit.label("ASHBORN", 24, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))
	box.add_child(UIKit.label("Die. Bounce back. Rise stronger.", 10, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))

	_prompt = BouncePrompt.new()
	_prompt.pressed.connect(Game.start_run)
	box.add_child(_prompt)
	var bounce_line := Run.bounce_text(Save.get_bounce())
	if bounce_line != "":
		box.add_child(UIKit.label(bounce_line, 8, HORIZONTAL_ALIGNMENT_CENTER))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	if Save.get_stat("runs") > 0:
		buttons.add_child(UIKit.button("Upgrades", Game.goto_hub))
	buttons.add_child(UIKit.button("Settings", _open_settings))
	if OS.is_debug_build():
		buttons.add_child(UIKit.button("Reset save (debug)", _reset_save))
	if not OS.has_feature("web"):
		buttons.add_child(UIKit.button("Quit", get_tree().quit))

	var help := UIKit.label("WASD move  -  Mouse aim, hold to shoot  -  Space dash (once unlocked)  -  Esc pause",
			8, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM)
	add_child(help)
	help.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	help.offset_top = -18
	help.offset_bottom = -4
	var credit := UIKit.label("Art: 0x72 - DungeonTileset II (CC0)", 7, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.TEXT_DIM)
	add_child(credit)
	credit.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	credit.offset_top = 4
	credit.offset_right = -6


func _open_settings() -> void:
	_prompt.enabled = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := SettingsPanel.new()
	panel.closed.connect(center.queue_free)
	panel.closed.connect(func() -> void: _prompt.enabled = true)
	center.add_child(panel)


func _reset_save() -> void:
	Save.reset_save()
	Game.goto_title()   # rebuild the screen (Upgrades button and Bounce line depend on the save)
