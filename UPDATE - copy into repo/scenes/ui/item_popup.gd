class_name ItemPopup
extends CanvasLayer
## "You found ..." card that slides down from the top of the screen for a few seconds.
## Does not pause the game. Use ItemPopup.show_item(get_tree(), ...).

const SHOW_TIME := 3.2

var header := "TREASURE"
var item_name := ""
var description := ""
var extra := ""
var icon: Texture2D

var _panel: PanelContainer


static func show_item(tree: SceneTree, p_name: String, p_desc: String, p_icon: Texture2D,
		p_extra: String = "", p_header: String = "TREASURE") -> ItemPopup:
	# Only one card at a time.
	for old in tree.get_nodes_in_group("item_popup"):
		old.queue_free()
	var p := ItemPopup.new()
	p.item_name = p_name
	p.description = p_desc
	p.icon = p_icon
	p.extra = p_extra
	p.header = p_header
	tree.current_scene.add_child(p)
	return p


func _ready() -> void:
	add_to_group("item_popup")
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.08, 0.94)
	style.border_color = UIKit.ACCENT
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	if icon:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(32, 32)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UIKit.label(header, 8, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_DIM))
	col.add_child(UIKit.label(item_name, 13, HORIZONTAL_ALIGNMENT_LEFT, UIKit.ACCENT))
	if description != "":
		col.add_child(UIKit.label(description, 9, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE))
	if extra != "":
		col.add_child(UIKit.label(extra, 8, HORIZONTAL_ALIGNMENT_LEFT, Color("#7dff8a")))
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_animate.call_deferred()


func _animate() -> void:
	var view := get_viewport().get_visible_rect().size
	_panel.reset_size()
	var w := _panel.size.x
	var shown_y := 20.0
	_panel.position = Vector2((view.x - w) / 2.0, -_panel.size.y - 4.0)
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", shown_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
