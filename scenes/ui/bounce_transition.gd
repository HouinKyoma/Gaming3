class_name BounceTransition
extends Control
## The full-screen "bounce back" burst: an ember shockwave swells from the prompt and covers the
## screen, sparks fly out and bounce off the bottom, then the flash fades to reveal the new run.
## It lives on its own CanvasLayer under the tree root, so it keeps playing across the scene change.

const COVER_AT := 0.42      # seconds until the screen is fully covered (on_cover is called here)
const DURATION := 1.3
const SPARKS := 56
const RIM := Color("#ffb066")
const COVER := Color("#1c0907")
const HOT := Color("#ffe08a")

var origin := Vector2(240, 135)
var on_cover: Callable

var _t := 0.0
var _covered := false
var _font: Font
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []


static func play(tree: SceneTree, at: Vector2, cover_callback: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.name = "BounceTransition"
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	var fx := BounceTransition.new()
	fx.origin = at
	fx.on_cover = cover_callback
	layer.add_child(fx)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	for i in 3:
		_rings.append({"center": origin, "start": i * 0.07, "reach": 320.0, "color": RIM})
	for i in SPARKS:
		var dir := Vector2.from_angle(randf() * TAU)
		_sparks.append({
			"p": origin,
			"v": dir * randf_range(120.0, 380.0) + Vector2(0, -120.0),
			"life": randf_range(0.9, 1.4),
			"size": randf_range(1.0, 2.5),
		})


func _process(delta: float) -> void:
	_t += delta
	var s := get_viewport_rect().size
	for sp in _sparks:
		var p: Vector2 = sp["p"]
		var v: Vector2 = sp["v"]
		v.y += 520.0 * delta
		p += v * delta
		if p.y > s.y - 2.0 and v.y > 0.0:   # the sparks bounce back too
			p.y = s.y - 2.0
			v.y *= -0.62
			v.x *= 0.8
		if (p.x < 0.0 and v.x < 0.0) or (p.x > s.x and v.x > 0.0):
			v.x *= -0.8
		sp["p"] = p
		sp["v"] = v
		sp["life"] = float(sp["life"]) - delta
	if not _covered and _t >= COVER_AT:
		_covered = true
		Events.camera_shake_requested.emit(5.0, 0.3)
		_rings.append({"center": s / 2.0, "start": _t, "reach": 300.0, "color": Color.WHITE})
		if on_cover.is_valid():
			on_cover.call()
	if _t >= DURATION:
		get_parent().queue_free()
	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size

	# Cover: a disc with a bright rim that swells until it fills the screen, then fades.
	if _t < COVER_AT:
		var k := clampf((_t - 0.08) / (COVER_AT - 0.08), 0.0, 1.0)
		var r := k * k * s.length()
		if r > 0.0:
			draw_circle(origin, r, RIM)
			draw_circle(origin, maxf(r - 8.0, 0.0), COVER)
	else:
		var after := _t - COVER_AT
		var a := 1.0 - clampf((after - 0.1) / 0.5, 0.0, 1.0)
		if a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, s), Color(COVER, a))
		var flash := 1.0 - clampf(after / 0.18, 0.0, 1.0)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash * 0.8))

	# Shockwave rings
	for ring in _rings:
		var age := _t - float(ring["start"])
		if age <= 0.0:
			continue
		var k := clampf(age / 0.7, 0.0, 1.0)
		var r := (1.0 - pow(1.0 - k, 3.0)) * float(ring["reach"])
		var w := 8.0 * (1.0 - k)
		if w > 0.3:
			var center: Vector2 = ring["center"]
			var col: Color = ring["color"]
			draw_arc(center, r, 0.0, TAU, 64, Color(col, 1.0 - k), w)

	# Sparks with short trails
	for sp in _sparks:
		var life: float = sp["life"]
		if life <= 0.0:
			continue
		var a := clampf(life / 0.4, 0.0, 1.0)
		var p: Vector2 = sp["p"]
		var v: Vector2 = sp["v"]
		var sz: float = sp["size"]
		draw_line(p, p - v * 0.03, Color(UIKit.ACCENT, a * 0.6), 1.0)
		draw_rect(Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(HOT, a))

	# "BOUNCE BACK!" slams in while the screen is covered
	var tt := _t - 0.3
	if tt > 0.0 and tt < 0.6 and _font:
		var text := "BOUNCE BACK!"
		var fs := 28
		var a := 1.0 - clampf((tt - 0.35) / 0.25, 0.0, 1.0)
		var sc := lerpf(1.8, 1.0, ease(clampf(tt / 0.15, 0.0, 1.0), 0.4))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(s / 2.0 + Vector2(0, 10), 0.0, Vector2(sc, sc))
		var p := Vector2(-w / 2.0, 0.0)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.2, 0.05, 0.02, a))
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(HOT, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)
