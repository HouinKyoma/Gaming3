class_name EmberBackground
extends Control
## Animated menu background: dark base, warm glow from below, rising embers and a vignette.
## Pure code, no art. Used by the title, death, victory and shop screens (UIKit.ember_background).

const EMBER_COUNT := 70

## Base colour of the screen.
var color := Color("#0e0b10")
## Colour of the embers and the bottom glow.
var ember_color := Color("#f2a65a")

var _embers: Array[Dictionary] = []
var _t := 0.0
var _vignette: GradientTexture2D
var _glow: GradientTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vignette = EmberBackground.make_vignette(0.8)
	var g := Gradient.new()
	g.set_color(0, Color(ember_color, 0.0))
	g.set_color(1, Color(ember_color, 0.16))
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill_from = Vector2(0, 0)
	_glow.fill_to = Vector2(0, 1)
	_glow.width = 4
	_glow.height = 64
	for i in EMBER_COUNT:
		_embers.append(_new_ember(true))


## Radial texture: clear in the middle, dark at the corners. Stretch it over the screen.
static func make_vignette(strength: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 128
	tex.height = 72
	return tex


func _screen() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _new_ember(anywhere: bool) -> Dictionary:
	var s := _screen()
	return {
		"p": Vector2(randf() * s.x, randf() * s.y if anywhere else s.y + randf() * 10.0),
		"speed": randf_range(8.0, 30.0),
		"size": randf_range(1.0, 2.0),
		"phase": randf() * TAU,
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _embers.size():
		var e := _embers[i]
		var p: Vector2 = e["p"]
		p.y -= float(e["speed"]) * delta
		p.x += sin(_t * 1.3 + float(e["phase"])) * 6.0 * delta
		if p.y < -4.0:
			_embers[i] = _new_ember(false)
		else:
			e["p"] = p
	queue_redraw()


func _draw() -> void:
	var s := _screen()
	draw_rect(Rect2(Vector2.ZERO, s), color)
	draw_texture_rect(_glow, Rect2(0, s.y * 0.35, s.x, s.y * 0.65), false)
	for e in _embers:
		var p: Vector2 = e["p"]
		var flicker := 0.55 + 0.45 * sin(_t * 5.0 + float(e["phase"]))
		var sz: float = e["size"]
		draw_circle(p, sz * 2.5, Color(ember_color, 0.10 * flicker))
		draw_rect(Rect2(p.floor(), Vector2(sz, sz).ceil()), Color(ember_color.lightened(0.3), flicker))
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, s), false)
