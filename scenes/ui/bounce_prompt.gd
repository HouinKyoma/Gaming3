class_name BouncePrompt
extends Control
## "PRESS [SPACE] TO / BOUNCE BACK": the keycap taps itself, the letters bounce like balls.
## Space (or gamepad A) launches the letters and plays BounceTransition; `pressed` is emitted
## when the screen is fully covered, so the scene change is hidden behind the effect.

signal pressed

const TOP := "PRESS"
const KEY := "SPACE"
const MID := "TO"
const BIG := "BOUNCE BACK"
const SMALL_SIZE := 9
const BIG_SIZE := 22
const HOT := Color("#ffe08a")
const DARK := Color("#3a1408")

var enabled := true
## Ignore input for this long after appearing, so mashing Space in a fight can't skip the screen.
var input_delay := 0.0

var _font: Font
var _t := 0.0
var _fired := false
var _fire_t := 0.0
var _key_top: StyleBoxFlat
var _key_side: StyleBoxFlat


func _ready() -> void:
	_font = get_theme_default_font()
	custom_minimum_size = Vector2(260, 58)
	mouse_filter = MOUSE_FILTER_IGNORE
	_key_top = StyleBoxFlat.new()
	_key_top.bg_color = Color("#3b2b33")
	_key_top.border_color = Color("#7a5a4a")
	_key_top.set_border_width_all(1)
	_key_top.set_corner_radius_all(2)
	_key_side = StyleBoxFlat.new()
	_key_side.bg_color = Color("#160e12")
	_key_side.set_corner_radius_all(2)


func _process(delta: float) -> void:
	_t += delta
	input_delay = maxf(input_delay - delta, 0.0)
	if _fired:
		_fire_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled or input_delay > 0.0 or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var is_space := key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_SPACE or key.keycode == KEY_SPACE)
	var is_pad_a := pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A
	if is_space or is_pad_a:
		get_viewport().set_input_as_handled()
		_trigger()


func _trigger() -> void:
	enabled = false
	_fired = true
	_fire_t = 0.0
	Audio.play_sfx("dash", 0.0)
	Audio.play_sfx("buy", 0.0)
	BounceTransition.play(get_tree(), global_position + Vector2(size.x / 2.0, 40.0), _on_cover)


func _on_cover() -> void:
	pressed.emit()


func _text_w(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _draw() -> void:
	if _font == null:
		return
	var accent := UIKit.ACCENT

	# --- Row 1: PRESS [SPACE] TO --------------------------------------------------
	var y1 := 14.0
	var gap := 6.0
	var w_press := _text_w(TOP, SMALL_SIZE)
	var w_key := _text_w(KEY, SMALL_SIZE) + 14.0
	var w_to := _text_w(MID, SMALL_SIZE)
	var x := (size.x - (w_press + w_key + w_to + gap * 2.0)) / 2.0
	draw_string(_font, Vector2(x, y1), TOP, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, UIKit.TEXT_DIM)
	x += w_press + gap
	var down := _fired or fmod(_t, 1.2) < 0.14
	var top_rect := Rect2(x, y1 - 10.0 + (2.0 if down else 0.0), w_key, 11.0)
	draw_style_box(_key_side, Rect2(x, y1 - 8.0, w_key, 11.0))
	draw_style_box(_key_top, top_rect)
	var key_base := top_rect.position.y + (top_rect.size.y + _font.get_ascent(SMALL_SIZE) - _font.get_descent(SMALL_SIZE)) / 2.0
	draw_string(_font, Vector2(x + 7.0, key_base), KEY, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE,
			HOT if down else Color.WHITE)
	x += w_key + gap
	draw_string(_font, Vector2(x, y1), MID, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, UIKit.TEXT_DIM)

	# --- Row 2: BOUNCE BACK, every letter a bouncing ball ----------------------------
	var y2 := 48.0
	draw_set_transform(Vector2(size.x / 2.0, y2 - 8.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 110.0, Color(accent, 0.07 + 0.04 * sin(_t * 3.0)))
	x = (size.x - _text_w(BIG, BIG_SIZE)) / 2.0
	for i in BIG.length():
		var ch := BIG[i]
		var cw := _text_w(ch, BIG_SIZE)
		if ch != " ":
			var h := absf(sin(_t * 3.4 - i * 0.42))     # 0 = on the floor, 1 = top of the bounce
			var lift := h * 8.0
			var squash := clampf((0.18 - h) / 0.18, 0.0, 1.0)
			var sc := Vector2(1.0 + 0.3 * squash, 1.0 - 0.3 * squash)
			var col := accent.lerp(HOT, h)
			if _fired:   # launch upward, stretched, staggered left to right
				var ft := maxf(_fire_t - i * 0.025, 0.0)
				lift += 600.0 * ft * ft + 120.0 * ft
				sc = Vector2(0.8, 1.35) if ft > 0.0 else Vector2(1.3, 0.7)
				col = HOT.lerp(Color.WHITE, clampf(ft * 5.0, 0.0, 1.0))
			var foot := Vector2(x + cw / 2.0, y2)
			draw_set_transform(foot + Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, cw * 0.5 * (1.0 - minf(lift / 16.0, 0.6)), Color(0, 0, 0, 0.45 * (1.0 - h * 0.6)))
			draw_set_transform(foot - Vector2(0, lift), 0.0, sc)
			var p := Vector2(-cw / 2.0, 0.0)
			draw_string_outline(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG_SIZE, 7, Color(accent, 0.18))
			draw_string_outline(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG_SIZE, 3, DARK)
			draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG_SIZE, col)
		x += cw
	draw_set_transform_matrix(Transform2D.IDENTITY)
