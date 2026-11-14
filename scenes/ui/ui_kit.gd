class_name UIKit
extends RefCounted
## Small helpers so every menu is built the same way.

const BG_COLOR := Color("#0e0b10")
const TEXT_DIM := Color(0.7, 0.66, 0.72)
const ACCENT := Color("#f2a65a")   # ash / ember orange


static func label(text: String, size: int = 10, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable, size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void: Audio.play_sfx("ui_click", 0.0))
	b.pressed.connect(on_pressed)
	return b


static func background(parent: Control, color: Color = BG_COLOR) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


## A full-screen CenterContainer holding a VBox; returns the VBox.
static func center_box(parent: Control, separation: int = 6) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box


static func icon(path: String) -> TextureRect:
	var rect := TextureRect.new()
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return rect


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
