class_name UpgradeCard
extends Button
## One upgrade tile in the shop. Built in code by hub.gd.

signal selected(up: UpgradeData)

var upgrade: UpgradeData

var _name_label: Label
var _level_label: Label
var _cost_label: Label


func setup(up: UpgradeData) -> void:
	upgrade = up
	custom_minimum_size = Vector2(108, 40)
	focus_mode = Control.FOCUS_ALL

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 3
	row.offset_right = -4
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.texture = up.get_icon()
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	_name_label = UIKit.label(up.display_name, 9)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_label)
	_level_label = UIKit.label("", 8, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_DIM)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_level_label)
	_cost_label = UIKit.label("", 8, HORIZONTAL_ALIGNMENT_LEFT, UIKit.ACCENT)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_cost_label)

	pressed.connect(_on_pressed)
	refresh()


func refresh() -> void:
	var level: int = Save.get_level(upgrade.id)
	var cost: int = upgrade.cost_for_next(level)
	_level_label.text = "Lv %d/%d" % [level, upgrade.max_level()]
	if cost < 0:
		_cost_label.text = "MAX"
		modulate = Color(0.75, 1.0, 0.75)
	else:
		_cost_label.text = "%d ash" % cost
		modulate = Color.WHITE if Save.get_ash() >= cost else Color(0.6, 0.6, 0.6)


func _on_pressed() -> void:
	selected.emit(upgrade)
