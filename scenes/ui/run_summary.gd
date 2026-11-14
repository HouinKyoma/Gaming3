extends Control
## Death screen and victory screen (same script, `won` set in the .tscn).
## Shows the run's result from Run.last_result. The Ash is already banked by then.

@export var won := false

var _earned_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UIKit.background(self)
	var r: Dictionary = Run.last_result
	var box := UIKit.center_box(self, 5)

	var title := "VICTORY" if won else "YOU BURNED OUT"
	box.add_child(UIKit.label(title, 20, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))
	if won:
		box.add_child(UIKit.label("The Hollow Warden is ash. For now.", 10, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))
	else:
		box.add_child(UIKit.label("Slain by: %s" % str(r.get("killer", "?")), 10, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))

	var stats_text := "Floor %d  -  %d rooms  -  %d kills  -  %s" % [
			int(r.get("floor", 1)), int(r.get("rooms", 0)), int(r.get("kills", 0)),
			UIKit.format_time(float(r.get("time", 0.0)))]
	box.add_child(UIKit.label(stats_text, 9, HORIZONTAL_ALIGNMENT_CENTER))

	var earned := int(r.get("ash", 0))
	_earned_label = UIKit.label("+0 ash", 14, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT)
	box.add_child(_earned_label)
	var tween := create_tween()
	tween.tween_method(_set_earned_text, 0.0, float(earned), 0.8)

	box.add_child(UIKit.label("Banked: %d ash" % Save.get_ash(), 10, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := _next_upgrade_hint()
	if hint != "":
		box.add_child(UIKit.label(hint, 9, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var shop := UIKit.button("Return to the Threshold", Game.goto_hub, 11)
	buttons.add_child(shop)
	buttons.add_child(UIKit.button("Title", Game.goto_title))
	shop.grab_focus.call_deferred()


func _set_earned_text(value: float) -> void:
	_earned_label.text = "+%d ash" % int(value)


## "You can afford: Ember Dash (15)" or "Next: Vitality, 20 ash".
func _next_upgrade_hint() -> String:
	var cheapest: UpgradeData = null
	var cheapest_cost := 0
	for up in Content.upgrades:
		var cost: int = up.cost_for_next(Save.get_level(up.id))
		if cost >= 0 and (cheapest == null or cost < cheapest_cost):
			cheapest = up
			cheapest_cost = cost
	if cheapest == null:
		return ""
	if Save.get_ash() >= cheapest_cost:
		return "You can afford: %s (%d ash)" % [cheapest.display_name, cheapest_cost]
	return "Next: %s, %d ash" % [cheapest.display_name, cheapest_cost]
