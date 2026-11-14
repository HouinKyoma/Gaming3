extends Node2D
## The gameplay scene: builds floors, swaps rooms, and ends the run (death or victory).

const CROSSHAIR_PATH := "res://art/ui/crosshair.png"

var layout: Dictionary = {}       # Vector2i -> FloorGenerator.RoomType
var templates: Dictionary = {}    # Vector2i -> Array (layout text, fixed per floor)
var cleared: Dictionary = {}      # Vector2i -> true
var visited: Dictionary = {}      # Vector2i -> true (for the minimap)
var current_coord := Vector2i.ZERO
var current_room: Room

var _switching := false
var _ending := false
var _fade: ColorRect
var _crosshair: Sprite2D

@onready var room_holder: Node2D = $RoomHolder
@onready var projectiles: Node2D = $Projectiles
@onready var player: Player = $Player


func _ready() -> void:
	if not Run.active:
		Run.start_new_run()
	projectiles.add_to_group("projectile_layer")
	Events.floor_exit_reached.connect(_on_floor_exit_reached)
	Events.player_died.connect(_on_player_died)
	Events.boss_defeated.connect(_on_boss_defeated)
	_build_overlay()
	start_floor()


func _process(_delta: float) -> void:
	if _crosshair:
		_crosshair.global_position = get_global_mouse_position()


func start_floor() -> void:
	var fd := _floor_data()
	layout = FloorGenerator.generate(fd.room_count, fd.is_boss_floor, Run.rng)
	templates.clear()
	for c: Vector2i in layout:
		templates[c] = RoomTemplates.pick(layout[c], Run.rng)
	cleared = {Vector2i.ZERO: true}
	visited = {}
	enter_room(Vector2i.ZERO, Vector2i.ZERO)
	Events.floor_started.emit(Run.floor_index)


## Always called deferred from door signals: never swap rooms inside a physics callback.
func enter_room(coord: Vector2i, moved_dir: Vector2i) -> void:
	if current_room and is_instance_valid(current_room):
		room_holder.remove_child(current_room)
		current_room.queue_free()
	for bullet in projectiles.get_children():
		bullet.queue_free()

	current_coord = coord
	visited[coord] = true
	var room := Room.new()
	room.name = "Room_%d_%d" % [coord.x, coord.y]
	room_holder.add_child(room)
	current_room = room
	room.cleared.connect(_on_room_cleared.bind(coord))
	room.door_entered.connect(_on_room_door_entered)

	var neighbours := {}
	for d: Vector2i in FloorGenerator.DIRS:
		neighbours[d] = layout.has(coord + d)
	room.setup(coord, layout[coord], neighbours, cleared.has(coord), _floor_data(), templates[coord])

	# Moving RIGHT means arriving at the new room's LEFT door, hence -moved_dir.
	player.global_position = room.to_global(room.get_entry_position(-moved_dir))
	player.velocity = Vector2.ZERO
	_switching = false
	_fade_in()
	Events.room_entered.emit(coord, layout[coord])


func _floor_data() -> FloorData:
	return Content.floors[clampi(Run.floor_index, 0, Content.floors.size() - 1)]


func _on_room_cleared(coord: Vector2i) -> void:
	cleared[coord] = true


func _on_room_door_entered(dir: Vector2i) -> void:
	if _switching or _ending:
		return
	_switching = true
	enter_room.call_deferred(current_coord + dir, dir)


func _on_floor_exit_reached() -> void:
	if _ending or Run.floor_index + 1 >= Content.floors.size():
		return
	_offer_boon.call_deferred()


## Pick 1 of 3 boons, then go down to the next floor.
func _offer_boon() -> void:
	var choice := BoonChoice.new()
	choice.chosen.connect(_on_boon_chosen)
	add_child(choice)


func _on_boon_chosen(boon: UpgradeData) -> void:
	if boon:
		Run.add_boon(boon)
		player.apply_new_stats()
	Run.floor_index += 1
	start_floor()


func _on_player_died(killer: String) -> void:
	if _ending:
		return
	_ending = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(1.0).timeout
	Run.end_run(false, killer)
	Game.show_death()


func _on_boss_defeated() -> void:
	if _ending:
		return
	_ending = true
	await get_tree().create_timer(2.0).timeout
	Run.end_run(true, "")
	Game.show_victory()


# --- Overlay: fade between rooms + crosshair ------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 10
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

	if ResourceLoader.exists(CROSSHAIR_PATH):
		_crosshair = Sprite2D.new()
		_crosshair.name = "Crosshair"
		_crosshair.texture = load(CROSSHAIR_PATH)
		_crosshair.z_index = 100
		add_child(_crosshair)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _fade_in() -> void:
	if _fade == null:
		return
	_fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, 0.18)
