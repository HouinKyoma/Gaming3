class_name Treasure
extends Area2D
## The chest on the pedestal in the treasure room. Walk into it to open it (no dash needed,
## works at any HP). It gives a random item (a run boon the player doesn't have yet, lasts
## until death), heals to full, and shows a popup saying what you got.

signal used

const BOB_SPEED := 3.0

var available := true

var _visual: EntityVisual
var _label: Label
var _t := 0.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)

	_visual = EntityVisual.new()
	_visual.name = "Visual"
	_visual.art_key = "pedestal"
	_visual.start_animation = EntityVisual.FULL if available else EntityVisual.EMPTY
	add_child(_visual)

	# Floating name tag so it's obvious what this is.
	_label = Label.new()
	_label.text = "? TREASURE ?" if available else "(empty)"
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", UIKit.ACCENT if available else UIKit.TEXT_DIM)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 12)
	_label.position = Vector2(-40, -36)
	_label.z_index = 5
	add_child(_label)


func _process(delta: float) -> void:
	if not available:
		return
	_t += delta
	_label.position.y = -36.0 + sin(_t * BOB_SPEED) * 2.0
	queue_redraw()


func _draw() -> void:
	if not available:
		return
	# Soft pulsing glow under the chest.
	var p := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2(0, -6), 13.0 + 2.0 * p, Color(UIKit.ACCENT, 0.10 + 0.08 * p))


func _physics_process(_delta: float) -> void:
	if not available:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and not player.is_dead:
			_open(player)
			return


func _open(player: Player) -> void:
	available = false
	_visual.play(EntityVisual.EMPTY)
	_label.text = "(empty)"
	_label.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	queue_redraw()
	Events.camera_shake_requested.emit(2.0, 0.15)
	Audio.play_sfx("buy", 0.0)

	var boon := _pick_item()
	var was_hurt := not player.health.is_full()
	if boon:
		Run.add_boon(boon)
		player.apply_new_stats()
	player.heal_full()

	var extra := "Healed to full!" if was_hurt else "Lasts until you die."
	if boon:
		ItemPopup.show_item(get_tree(), boon.display_name, boon.description, boon.get_icon(), extra, "YOU FOUND")
	else:
		ItemPopup.show_item(get_tree(), "Healing Ember", "Restores all your hearts.", null, "", "YOU FOUND")
	used.emit()


## A random boon the player doesn't have yet (any boon if they have them all).
func _pick_item() -> UpgradeData:
	var fresh: Array[UpgradeData] = []
	for b in Content.boons:
		if not (b in Run.boons):
			fresh.append(b)
	if fresh.is_empty():
		fresh.assign(Content.boons)
	if fresh.is_empty():
		return null
	return fresh[Run.rng.randi_range(0, fresh.size() - 1)]
