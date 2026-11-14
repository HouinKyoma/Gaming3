extends Control
## The Threshold: spend banked Ash on permanent upgrades, then start the next run.

var _selected: UpgradeData
var _cards: Array[UpgradeCard] = []

var _ash_label: Label
var _name_label: Label
var _desc_label: Label
var _info_label: Label
var _buy_button: Button
var _stats_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UIKit.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# Header
	var header := HBoxContainer.new()
	col.add_child(header)
	header.add_child(UIKit.label("The Threshold", 14, HORIZONTAL_ALIGNMENT_LEFT, UIKit.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UIKit.icon("res://art/ui/ash_icon.png"))
	_ash_label = UIKit.label("", 12, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.ACCENT)
	header.add_child(_ash_label)

	# Upgrade grid
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for up in Content.upgrades:
		var card := UpgradeCard.new()
		grid.add_child(card)
		card.setup(up)
		card.selected.connect(_on_card_selected)
		_cards.append(card)

	# Detail panel
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	panel.add_child(detail)
	_name_label = UIKit.label("", 12)
	detail.add_child(_name_label)
	_desc_label = UIKit.label("", 9, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_desc_label)
	var buy_row := HBoxContainer.new()
	detail.add_child(buy_row)
	_info_label = UIKit.label("", 9)
	_info_label.size_flags_horizontal = SIZE_EXPAND_FILL
	buy_row.add_child(_info_label)
	_buy_button = UIKit.button("Buy", _on_buy_pressed)
	buy_row.add_child(_buy_button)

	# Footer
	var footer := HBoxContainer.new()
	col.add_child(footer)
	_stats_label = UIKit.label("", 8, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_DIM)
	_stats_label.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(_stats_label)
	footer.add_child(UIKit.button("Title", Game.goto_title))
	var descend := UIKit.button("Descend", Game.start_run, 12)
	footer.add_child(descend)

	Events.meta_changed.connect(_refresh)
	if not _cards.is_empty():
		_on_card_selected(_cards[0].upgrade)
		_cards[0].grab_focus.call_deferred()
	_refresh()


func _on_card_selected(up: UpgradeData) -> void:
	_selected = up
	_refresh()


func _on_buy_pressed() -> void:
	if _selected and Save.try_buy(_selected):
		Audio.play_sfx("buy", 0.0)


func _refresh() -> void:
	_ash_label.text = " %d" % Save.get_ash()
	for card in _cards:
		card.refresh()
	_stats_label.text = "Runs %d   Wins %d   Best floor %d" % [
			Save.get_stat("runs"), Save.get_stat("wins"), Save.get_stat("best_floor")]
	if _selected == null:
		_name_label.text = ""
		_desc_label.text = ""
		_info_label.text = ""
		_buy_button.disabled = true
		return
	var level: int = Save.get_level(_selected.id)
	var cost: int = _selected.cost_for_next(level)
	_name_label.text = _selected.display_name
	_desc_label.text = _selected.description
	if cost < 0:
		_info_label.text = "Level %d / %d  -  maxed" % [level, _selected.max_level()]
		_buy_button.disabled = true
	else:
		_info_label.text = "Level %d / %d  -  next: %d ash" % [level, _selected.max_level(), cost]
		_buy_button.disabled = Save.get_ash() < cost
