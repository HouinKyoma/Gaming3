extends Control
## Main scene. On the very first launch, Play goes straight into a run (no shop to explain yet).

const LOGO_PATH := "res://art/ui/logo.png"


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UIKit.background(self)
	var box := UIKit.center_box(self, 8)

	if ResourceLoader.exists(LOGO_PATH):
		box.add_child(UIKit.icon(LOGO_PATH))
	else:
		box.add_child(UIKit.label("ASHBORN", 24, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))
	box.add_child(UIKit.label("Die. Return as ash. Rise stronger.", 10, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))

	var play := UIKit.button("Play", _on_play, 12)
	box.add_child(play)
	box.add_child(UIKit.button("Settings", _open_settings))
	if OS.is_debug_build():
		box.add_child(UIKit.button("Reset save (debug)", Save.reset_save))
	if not OS.has_feature("web"):
		box.add_child(UIKit.button("Quit", get_tree().quit))

	var help := UIKit.label("WASD move  -  Mouse aim, hold to shoot  -  Space dash (once unlocked)  -  Esc pause",
			8, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM)
	add_child(help)
	help.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	help.offset_top = -18
	help.offset_bottom = -4
	play.grab_focus.call_deferred()


func _open_settings() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := SettingsPanel.new()
	panel.closed.connect(center.queue_free)
	center.add_child(panel)


func _on_play() -> void:
	if Save.get_stat("runs") == 0:
		Game.start_run()
	else:
		Game.goto_hub()
