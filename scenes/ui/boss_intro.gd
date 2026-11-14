class_name BossIntro
extends CanvasLayer
## Boss intro card: black bars slide in, the screen darkens at the edges, the boss's name is
## typed out in big blood-red letters with a slash under it, then the subtitle fades in.
## Run creates it on Events.boss_intro_started and zooms the camera onto the boss meanwhile.
## Space / click skips (after a moment). Emits `finished` (and Events.boss_intro_finished).

signal finished

const DURATION := 3.0
const BAR_H := 40.0
const BLOOD := Color("#e0303a")
const BONE := Color("#efe6d6")

var title := "BOSS"
var subtitle := ""

var _t := 0.0
var _done := false
var _canvas: Control
var _font: Font


func _ready() -> void:
	layer = 7
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_card)
	add_child(_canvas)
	_font = _canvas.get_theme_default_font()
	Audio.play_sfx("boss_roar", 0.0)
	Events.camera_shake_requested.emit(3.0, 0.4)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		_finish()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _t < 0.6 or _done:
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if (key and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE) \
			or (mouse and mouse.pressed):
		get_viewport().set_input_as_handled()
		_t = maxf(_t, DURATION - 0.35)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	Events.boss_intro_finished.emit()
	queue_free()


func _draw_card() -> void:
	var s := _canvas.size
	var t_in := clampf(_t / 0.35, 0.0, 1.0)
	var t_out := clampf((DURATION - _t) / 0.35, 0.0, 1.0)
	var k := ease(minf(t_in, t_out), 0.4)

	# Darken + letterbox bars
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.0, 0.02, 0.35 * k))
	var bar := BAR_H * k
	_canvas.draw_rect(Rect2(0, 0, s.x, bar), Color.BLACK)
	_canvas.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color.BLACK)
	_canvas.draw_rect(Rect2(0, bar - 1, s.x, 1), Color(BLOOD, 0.6 * k))
	_canvas.draw_rect(Rect2(0, s.y - bar, s.x, 1), Color(BLOOD, 0.6 * k))
	if _font == null:
		return

	# Name, typed out letter by letter, with a flicker
	var shown := clampi(int((_t - 0.3) / 0.045), 0, title.length())
	var text := title.substr(0, shown).to_upper()
	var fs := 22
	var full_w := _font.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (s.x - full_w) / 2.0
	var y := s.y - 66.0
	var flicker := 0.85 + 0.15 * sin(_t * 37.0) * sin(_t * 11.0)
	var a := t_out
	if text != "":
		var jitter := Vector2(randf_range(-1, 1), 0) if _t < 0.3 + title.length() * 0.045 + 0.1 else Vector2.ZERO
		_canvas.draw_string_outline(_font, Vector2(x, y) + jitter, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(BLOOD, 0.25 * a))
		_canvas.draw_string_outline(_font, Vector2(x, y) + jitter, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.08, 0.0, 0.02, a))
		_canvas.draw_string(_font, Vector2(x, y) + jitter, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BLOOD.lightened(0.15) * flicker, a))

	# Slash line under the name
	var slash := clampf((_t - 0.25) / 0.4, 0.0, 1.0)
	var lw := (full_w + 40.0) * ease(slash, 0.3)
	_canvas.draw_rect(Rect2(s.x / 2.0 - lw / 2.0, y + 5.0, lw, 1.0), Color(BLOOD, 0.9 * a))
	_canvas.draw_rect(Rect2(s.x / 2.0 - lw / 4.0, y + 7.0, lw / 2.0, 1.0), Color(BLOOD, 0.4 * a))

	# Subtitle
	var sub_a := clampf((_t - 0.3 - title.length() * 0.045) / 0.4, 0.0, 1.0) * a
	if subtitle != "" and sub_a > 0.0:
		var sub_text := "~ %s ~" % subtitle
		var sw := _font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		_canvas.draw_string(_font, Vector2((s.x - sw) / 2.0, y + 20.0), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(BONE, 0.85 * sub_a))

	if _t > 0.6:
		var hint := "Space to skip"
		var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_canvas.draw_string(_font, Vector2(s.x - hw - 6.0, s.y - 6.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.35 * a))
