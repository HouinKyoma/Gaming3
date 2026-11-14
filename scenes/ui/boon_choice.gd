class_name BoonChoice
extends CanvasLayer
## Between floors: pick 1 of 3 random boons. Boons last until the end of the run.
## Pauses the game while open. Emits `chosen` (null if there were no boons to offer).

signal chosen(boon: UpgradeData)

const CHOICES := 3


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	var options := _pick_options()
	if options.is_empty():
		_finish.call_deferred(null)
		return

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UIKit.background(root, Color(0, 0, 0, 0.75))
	var box := UIKit.center_box(root, 8)
	box.add_child(UIKit.label("The ash stirs. Choose a boon.", 14, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))
	box.add_child(UIKit.label("Boons last until you die.", 9, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var first: Button = null
	for boon in options:
		var card := _make_card(boon)
		row.add_child(card)
		if first == null:
			first = card
	first.grab_focus.call_deferred()


func _pick_options() -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []
	for b in Content.boons:
		pool.append(b)
	pool.shuffle()
	var picked: Array[UpgradeData] = []
	for b in pool:
		if picked.size() >= CHOICES:
			break
		picked.append(b)
	return picked


func _make_card(boon: UpgradeData) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(120, 84)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_top = 6
	col.offset_right = -6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	var icon := TextureRect.new()
	icon.texture = boon.get_icon()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var title := UIKit.label(boon.display_name, 11, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var desc := UIKit.label(boon.description, 9, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)

	card.pressed.connect(_finish.bind(boon))
	return card


func _finish(boon: UpgradeData) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if boon:
		Audio.play_sfx("buy", 0.0)
	chosen.emit(boon)
	queue_free()
