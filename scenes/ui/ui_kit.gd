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


## Animated full-screen background (embers + glow + vignette). For menus that fill the screen.
static func ember_background(parent: Control, color: Color = BG_COLOR, embers: Color = ACCENT) -> EmberBackground:
	var bg := EmberBackground.new()
	bg.color = color
	bg.ember_color = embers
	parent.add_child(bg)
	return bg


## Big title text with a dark outline and a soft glow.
static func title(text: String, size: int, color: Color = ACCENT, outline: Color = Color("#3a1408")) -> Label:
	var l := label(text, size, HORIZONTAL_ALIGNMENT_CENTER, color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


## Keeps a Control's pivot at its centre so scale tweens grow from the middle (works inside containers).
static func center_pivot(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)


## Pops a Control in: big and transparent, then springs to normal size.
static func pop_in(c: Control, delay: float = 0.0, from_scale: float = 2.0) -> void:
	center_pivot(c)
	c.scale = Vector2(from_scale, from_scale)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)


## Slow breathing scale, for logos and titles.
static func breathe(c: Control, amount: float = 0.04, period: float = 2.4) -> void:
	center_pivot(c)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, period / 2.0).set_trans(Tween.TRANS_SINE)


## Fades a Control in after `delay` seconds (for staggered reveals).
static func fade_in(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, 0.3).set_delay(delay)


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
