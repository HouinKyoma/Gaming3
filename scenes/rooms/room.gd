class_name Room
extends Node2D
## One screen-sized room (30 x 16 tiles = 480 x 256 px) built from a text layout (RoomTemplates).
## Builds its own floor, walls, obstacles, doors and spawn points, then runs its encounter.
##
## Tile atlas res://art/tiles/dungeon_tiles.png (4 x 3 tiles of 16 x 16):
##   row 0: floor A, floor B, floor C (cracked), floor D (detail)
##   row 1: wall top/bottom, (spare), wall corner, wall left/right
##   row 2: rock, pillar, crate, (spare)

signal cleared
signal door_entered(direction: Vector2i)

const TILE := 16
const COLS := 30
const ROWS := 16
const SIZE := Vector2(COLS * TILE, ROWS * TILE)
const CENTER := Vector2(COLS * TILE / 2.0, ROWS * TILE / 2.0)
const ENTRY_OFFSET := 20.0
const TILES_PATH := "res://art/tiles/dungeon_tiles.png"
const ASH_PICKUP_PATH := "res://scenes/pickups/ash_pickup.tscn"

const FLOOR_TILES := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const WALL_H := Vector2i(0, 1)
const WALL_CORNER := Vector2i(2, 1)
const WALL_V := Vector2i(3, 1)
const OBSTACLE_TILES := {"R": Vector2i(0, 2), "P": Vector2i(1, 2), "C": Vector2i(2, 2)}

const SPAWN_DELAY := 0.7
const BOSS_SPAWN_DELAY := 1.2

var coord := Vector2i.ZERO
var room_type: int = FloorGenerator.RoomType.COMBAT
var floor_data: FloorData
var is_cleared := false
var alive := 0

var enemies_layer: Node2D
var pickups_layer: Node2D
var special_layer: Node2D

var _grid: Array[String] = []
var _tiles: Texture2D
var _doors: Dictionary = {}       # Vector2i -> Door
var _has_door: Dictionary = {}    # Vector2i -> bool
var _spawn_points: Array[Vector2] = []
var _pending: Array = []          # [EnemyData, Vector2, hp_multiplier] waiting to spawn
var _markers: Array[Node] = []


## Run calls this right after add_child() and after connecting `cleared` / `door_entered`.
func setup(p_coord: Vector2i, type: int, neighbours: Dictionary, already_cleared: bool,
		fd: FloorData, template: Array) -> void:
	coord = p_coord
	room_type = type
	floor_data = fd
	_tiles = load(TILES_PATH) as Texture2D
	for dir: Vector2i in FloorGenerator.DIRS:
		_has_door[dir] = bool(neighbours.get(dir, false))
	_build_grid(template)
	_build_layers()
	_build_doors()
	queue_redraw()

	match room_type:
		FloorGenerator.RoomType.COMBAT, FloorGenerator.RoomType.EXIT:
			if already_cleared:
				_set_cleared_state()
			else:
				_begin_combat()
		FloorGenerator.RoomType.BOSS:
			if already_cleared:
				_set_cleared_state()
			else:
				_begin_boss()
		FloorGenerator.RoomType.TREASURE:
			is_cleared = true
			_set_doors(Door.State.OPEN)
			_spawn_treasure(not already_cleared)
		_:
			_set_cleared_state()


## Room-local position where the player appears when entering from `side`.
func get_entry_position(side: Vector2i) -> Vector2:
	match side:
		Vector2i.UP:
			return Vector2(CENTER.x, TILE + ENTRY_OFFSET)
		Vector2i.DOWN:
			return Vector2(CENTER.x, SIZE.y - TILE - ENTRY_OFFSET)
		Vector2i.LEFT:
			return Vector2(TILE + ENTRY_OFFSET, CENTER.y + 8.0)
		Vector2i.RIGHT:
			return Vector2(SIZE.x - TILE - ENTRY_OFFSET, CENTER.y + 8.0)
	return CENTER + Vector2(0, 8)


# --- Building ------------------------------------------------------------------------

func _build_grid(template: Array) -> void:
	_grid.clear()
	for row in ROWS:
		var line := ""
		for col in COLS:
			var ch := "."
			if row == 0 or row == ROWS - 1 or col == 0 or col == COLS - 1:
				ch = "#"
			else:
				var t_row := row - 1
				var t_col := col - 1
				if t_row < template.size():
					var tline: String = template[t_row]
					if t_col < tline.length():
						ch = tline[t_col]
			line += ch
		_grid.append(line)


func _build_layers() -> void:
	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	add_child(solids)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)

	for row in ROWS:
		for col in COLS:
			var ch := _grid[row][col]
			var solid := ch == "#" or OBSTACLE_TILES.has(ch)
			if solid and _gap_side(col, row) == Vector2i.ZERO:
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = _cell_center(col, row)
				solids.add_child(cs)
			elif ch == "S":
				_spawn_points.append(_cell_center(col, row) + Vector2(0, 4))

	special_layer = Node2D.new()
	special_layer.name = "Special"
	add_child(special_layer)
	pickups_layer = Node2D.new()
	pickups_layer.name = "Pickups"
	add_child(pickups_layer)
	enemies_layer = Node2D.new()
	enemies_layer.name = "Enemies"
	add_child(enemies_layer)


func _build_doors() -> void:
	var doors_node := Node2D.new()
	doors_node.name = "Doors"
	add_child(doors_node)
	for dir: Vector2i in FloorGenerator.DIRS:
		var door := Door.new()
		door.name = "Door_%d_%d" % [dir.x, dir.y]
		door.direction = dir
		door.position = _door_position(dir)
		doors_node.add_child(door)
		door.entered.connect(_on_door_entered)
		_doors[dir] = door
		door.set_state(Door.State.LOCKED if _has_door[dir] else Door.State.WALL)


func _door_position(dir: Vector2i) -> Vector2:
	match dir:
		Vector2i.UP:
			return Vector2(CENTER.x, TILE / 2.0)
		Vector2i.DOWN:
			return Vector2(CENTER.x, SIZE.y - TILE / 2.0)
		Vector2i.LEFT:
			return Vector2(TILE / 2.0, CENTER.y)
		_:
			return Vector2(SIZE.x - TILE / 2.0, CENTER.y)


## Which wall gap (door opening) a cell belongs to, or ZERO.
func _gap_side(col: int, row: int) -> Vector2i:
	if (col == 14 or col == 15) and row == 0:
		return Vector2i.UP
	if (col == 14 or col == 15) and row == ROWS - 1:
		return Vector2i.DOWN
	if (row == 7 or row == 8) and col == 0:
		return Vector2i.LEFT
	if (row == 7 or row == 8) and col == COLS - 1:
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE / 2.0, row * TILE + TILE / 2.0)


func _draw() -> void:
	if _tiles == null or _grid.is_empty():
		return
	for row in ROWS:
		for col in COLS:
			var ch := _grid[row][col]
			var pos := Vector2(col * TILE, row * TILE)
			var side := _gap_side(col, row)
			var is_open_gap := side != Vector2i.ZERO and bool(_has_door.get(side, false))
			if ch == "#" and not is_open_gap:
				_draw_tile(_wall_tile(col, row), pos)
				continue
			_draw_tile(_floor_tile(col, row), pos)
			if OBSTACLE_TILES.has(ch):
				_draw_tile(OBSTACLE_TILES[ch], pos)


func _draw_tile(atlas: Vector2i, pos: Vector2) -> void:
	var size := Vector2(TILE, TILE)
	draw_texture_rect_region(_tiles, Rect2(pos, size), Rect2(Vector2(atlas) * TILE, size))


func _wall_tile(col: int, row: int) -> Vector2i:
	var on_x_edge := col == 0 or col == COLS - 1
	var on_y_edge := row == 0 or row == ROWS - 1
	if on_x_edge and on_y_edge:
		return WALL_CORNER
	if on_y_edge:
		return WALL_H
	return WALL_V


func _floor_tile(col: int, row: int) -> Vector2i:
	var h := absi((col * 73856093) ^ (row * 19349663) ^ (coord.x * 83492791) ^ (coord.y * 2654435)) % 20
	if h < 14:
		return FLOOR_TILES[0]
	if h < 17:
		return FLOOR_TILES[1]
	if h < 19:
		return FLOOR_TILES[2]
	return FLOOR_TILES[3]


# --- Encounters -----------------------------------------------------------------------

func _set_doors(state: Door.State) -> void:
	for dir: Vector2i in _doors:
		var door: Door = _doors[dir]
		door.set_state(state if _has_door[dir] else Door.State.WALL)


func _set_cleared_state() -> void:
	is_cleared = true
	_set_doors(Door.State.OPEN)
	_spawn_special()


func _begin_combat() -> void:
	is_cleared = false
	_set_doors(Door.State.LOCKED)
	_plan_wave()
	if _pending.is_empty():
		_clear()
		return
	_show_markers()
	get_tree().create_timer(SPAWN_DELAY, false).timeout.connect(_spawn_wave)


func _begin_boss() -> void:
	is_cleared = false
	_set_doors(Door.State.LOCKED)
	var boss: EnemyData = Content.get_enemy(floor_data.boss_id)
	if boss == null:
		push_error("Room: no boss EnemyData with id '%s'" % floor_data.boss_id)
		_clear()
		return
	_pending = [[boss, CENTER + Vector2(0, -16), 1.0]]
	_show_markers()
	get_tree().create_timer(BOSS_SPAWN_DELAY, false).timeout.connect(_spawn_wave)


## Spends the floor's budget on random enemies from its pool.
func _plan_wave() -> void:
	_pending.clear()
	var pool: Array = []
	for id in floor_data.enemy_pool:
		var e: EnemyData = Content.get_enemy(id)
		if e:
			pool.append(e)
	if pool.is_empty():
		return

	var points: Array[Vector2] = []
	points.append_array(_spawn_points)
	if points.is_empty():
		for i in 6:
			points.append(Vector2(randf_range(80, SIZE.x - 80), randf_range(60, SIZE.y - 60)))
	points.shuffle()

	var budget := floor_data.combat_budget
	var point_index := 0
	var guard := 0
	while budget > 0 and guard < 50:
		guard += 1
		var affordable := pool.filter(func(e: EnemyData) -> bool: return e.budget_cost <= budget)
		if affordable.is_empty():
			break
		var choice: EnemyData = affordable.pick_random()
		budget -= choice.budget_cost
		var base: Vector2 = points[point_index % points.size()]
		point_index += 1
		for i in choice.spawn_count:
			var jitter := Vector2.ZERO if i == 0 else Vector2(randf_range(-12, 12), randf_range(-12, 12))
			_pending.append([choice, base + jitter, floor_data.hp_multiplier])


func _show_markers() -> void:
	for entry in _pending:
		var marker := EntityVisual.new()
		marker.art_key = "spawn_marker"
		marker.feet_origin = false
		marker.position = entry[1]
		special_layer.add_child(marker)
		_markers.append(marker)


func _spawn_wave() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
	var wave := _pending.duplicate()
	_pending.clear()
	for entry in wave:
		spawn_enemy(entry[0], entry[1], entry[2])
	if alive <= 0 and not is_cleared:
		_clear()


## Spawns one enemy at a room-local position. Also used by the boss to summon.
func spawn_enemy(data: EnemyData, pos: Vector2, hp_multiplier: float = 1.0) -> Enemy:
	if data == null or data.scene == null:
		push_error("Room: cannot spawn enemy, missing data or scene")
		return null
	var enemy := data.scene.instantiate() as Enemy
	if enemy == null:
		push_error("Room: %s scene root is not an Enemy" % data.id)
		return null
	enemy.data = data
	enemy.room = self
	enemy.position = pos
	enemies_layer.add_child(enemy)
	enemy.setup(hp_multiplier)
	enemy.died.connect(_on_enemy_died)
	alive += 1
	return enemy


## `pos` is a global position (where the enemy died).
func spawn_pickup(scene: PackedScene, pos: Vector2) -> void:
	if scene == null or not is_inside_tree():
		return
	var pickup := scene.instantiate() as Node2D
	pickups_layer.add_child(pickup)
	pickup.global_position = pos
	if is_cleared and pickup is Pickup:
		(pickup as Pickup).start_homing(0.5)


func _on_enemy_died(_enemy: Enemy) -> void:
	alive -= 1
	if alive <= 0 and _pending.is_empty() and not is_cleared:
		_clear.call_deferred()


func _clear() -> void:
	if is_cleared:
		return
	is_cleared = true
	_set_doors(Door.State.OPEN)
	cleared.emit()
	Events.room_cleared.emit(coord)
	if room_type == FloorGenerator.RoomType.EXIT:
		_spawn_bonus_ash()
	_spawn_special()
	for child in pickups_layer.get_children():
		if child is Pickup:
			(child as Pickup).start_homing(0.4)


func _spawn_special() -> void:
	# A boss room that is not on the last floor also gets stairs once the boss is dead.
	var boss_exit := room_type == FloorGenerator.RoomType.BOSS and Run.floor_index + 1 < Content.floors.size()
	if room_type == FloorGenerator.RoomType.EXIT or boss_exit:
		var stairs := ExitStairs.new()
		stairs.name = "ExitStairs"
		stairs.position = CENTER
		special_layer.add_child(stairs)


func _spawn_treasure(available: bool) -> void:
	var treasure := Treasure.new()
	treasure.name = "Treasure"
	treasure.available = available
	treasure.position = CENTER + Vector2(0, 8)
	special_layer.add_child(treasure)
	treasure.used.connect(func() -> void: cleared.emit())


func _spawn_bonus_ash() -> void:
	var scene := load(ASH_PICKUP_PATH) as PackedScene
	var pieces := 5
	var per_piece := maxi(1, roundi(floor_data.clear_bonus_ash / float(pieces)))
	for i in pieces:
		var pickup := scene.instantiate() as Pickup
		pickup.value = per_piece
		pickups_layer.add_child(pickup)
		pickup.position = CENTER + Vector2.from_angle(TAU * i / pieces) * 10.0


func _on_door_entered(dir: Vector2i) -> void:
	if is_cleared:
		door_entered.emit(dir)
