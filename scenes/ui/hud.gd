extends CanvasLayer
## In-run HUD: hearts, Ash, floor name, boss bar and a floor banner.

const HEART_FULL := "res://art/ui/heart_full.png"
const HEART_HALF := "res://art/ui/heart_half.png"
const HEART_EMPTY := "res://art/ui/heart_empty.png"
const BAR_HEIGHT := 14.0

var _hearts: HBoxContainer
var _ash_label: Label
var _floor_label: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _banner: Label
var _banner_sub: Label
var _tex_full: Texture2D
var _tex_half: Texture2D
var _tex_empty: Texture2D


func _ready() -> void:
	layer = 5
	_tex_full = _load_tex(HEART_FULL)
	_tex_half = _load_tex(HEART_HALF)
	_tex_empty = _load_tex(HEART_EMPTY)

	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2.ZERO
	bar.size = Vector2(480, BAR_HEIGHT)
	root.add_child(bar)

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 1)
	_hearts.position = Vector2(4, 1)
	root.add_child(_hearts)

	_floor_label = UIKit.label("", 9, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_DIM)
	_floor_label.position = Vector2(180, 0)
	_floor_label.size = Vector2(120, BAR_HEIGHT)
	root.add_child(_floor_label)

	var ash_box := HBoxContainer.new()
	ash_box.position = Vector2(400, 0)
	ash_box.size = Vector2(76, BAR_HEIGHT)
	ash_box.alignment = BoxContainer.ALIGNMENT_END
	ash_box.add_theme_constant_override("separation", 2)
	root.add_child(ash_box)
	ash_box.add_child(UIKit.icon("res://art/ui/ash_icon.png"))
	_ash_label = UIKit.label("0", 10, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.ACCENT)
	ash_box.add_child(_ash_label)

	_boss_box = VBoxContainer.new()
	_boss_box.position = Vector2(140, 244)
	_boss_box.size = Vector2(200, 20)
	_boss_box.add_theme_constant_override("separation", 0)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = UIKit.label("", 8, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(200, 5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.1, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d9443c")
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_box.add_child(_boss_bar)

	var minimap := Minimap.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(418, 18)
	minimap.size = Vector2(58, 42)
	root.add_child(minimap)

	_banner = UIKit.title("", 18)
	_banner.position = Vector2(0, 96)
	_banner.size = Vector2(480, 28)
	_banner.pivot_offset = _banner.size / 2.0
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_sub = UIKit.label("", 9, HORIZONTAL_ALIGNMENT_CENTER, Color("#8fe38f"))
	_banner_sub.position = Vector2(0, 124)
	_banner_sub.size = Vector2(480, 14)
	_banner_sub.modulate.a = 0.0
	root.add_child(_banner_sub)

	Events.player_health_changed.connect(_update_hearts)
	Events.run_ash_changed.connect(_on_ash_changed)
	Events.floor_started.connect(_on_floor_started)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(_on_boss_defeated)

	var max_hp: int = Run.stats.max_hp if Run.stats else 6
	_update_hearts(Run.current_hp, max_hp)
	_on_ash_changed(Run.ash)


func _load_tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _update_hearts(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	var heart_count := ceili(maximum / 2.0)
	for i in heart_count:
		var rect := TextureRect.new()
		var hp_here := current - i * 2
		if hp_here >= 2:
			rect.texture = _tex_full
		elif hp_here == 1:
			rect.texture = _tex_half
		else:
			rect.texture = _tex_empty
		_hearts.add_child(rect)


func _on_ash_changed(total: int) -> void:
	_ash_label.text = str(total)


func _on_floor_started(floor_index: int) -> void:
	var name_text := "Floor %d" % (floor_index + 1)
	if floor_index < Content.floors.size():
		name_text = Content.floors[floor_index].display_name
	_floor_label.text = name_text
	var sub := ""
	if floor_index == 0:
		sub = Run.bounce_text(Save.get_bounce())
	_show_banner(name_text, sub)


func _show_banner(text: String, sub: String = "", hold: float = 1.2) -> void:
	_banner.text = text
	_banner_sub.text = sub
	_banner.scale = Vector2(1.8, 1.8)
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0 if sub != "" else 0.0
	var pop := create_tween()
	pop.tween_property(_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tween := create_tween().set_parallel()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6).set_delay(hold)
	tween.tween_property(_banner_sub, "modulate:a", 0.0, 0.6).set_delay(hold + 0.4)


func _on_boss_spawned(boss_name: String, max_hp: int) -> void:
	_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_box.visible = true
	_show_banner(boss_name, "", 1.4)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.value = current


func _on_boss_defeated() -> void:
	_boss_box.visible = false
	_show_banner("%s falls" % _boss_name.text, "", 1.8)
