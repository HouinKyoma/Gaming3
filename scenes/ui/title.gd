extends Control
## Main scene. PRESS SPACE TO BOUNCE BACK starts a run straight away.
## The upgrade shop (the Threshold) is one click away once you have played a run.

const LOGO_PATH := "res://art/ui/logo.png"

var _prompt: BouncePrompt


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UIKit.ember_background(self)
	var box := UIKit.center_box(self, 6)

	var logo: Control
	if ResourceLoader.exists(LOGO_PATH):
		logo = UIKit.icon(LOGO_PATH)
	else:
		logo = UIKit.title("ASHBORN", 30)
	box.add_child(logo)
	UIKit.pop_in(logo, 0.0, 1.6)
	logo.create_tween().tween_callback(func() -> void: UIKit.breathe(logo)).set_delay(0.5)
	var tagline := UIKit.label("Die. Bounce back. Rise stronger.", 10, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM)
	box.add_child(tagline)
	UIKit.fade_in(tagline, 0.35)

	_prompt = BouncePrompt.new()
	_prompt.pressed.connect(Game.start_run)
	box.add_child(_prompt)
	UIKit.fade_in(_prompt, 0.55)
	var bounce_line := Run.bounce_text(Save.get_bounce())
	if bounce_line != "":
		var bl := UIKit.label(bounce_line, 8, HORIZONTAL_ALIGNMENT_CENTER, Color("#8fe38f"))
		box.add_child(bl)
		UIKit.fade_in(bl, 0.7)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	UIKit.fade_in(buttons, 0.8)
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
	var credit := UIKit.label("Art: 0x72 (CC0), Kronovi, CreativeKind", 7, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.TEXT_DIM)
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
