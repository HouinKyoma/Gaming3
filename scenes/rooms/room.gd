class_name Room
extends Node2D
## One room of a floor, built from a text layout (RoomTemplates). Rooms come in several sizes;
## the camera follows the player in rooms bigger than the screen. Builds its own floor, walls,
## obstacles, pits, hazards, doors and spawn points, then runs its encounter.
##
## Tile atlas = FloorData.tiles_path (biome sheet, 8 x 3 tiles of 16 x 16; the old 4 x 3 sheet still works):
##   row 0: floor A, floor B, floor C (cracked), floor D (detail), spikes down, spikes up, lava 1, lava 2
##   row 1: wall top/bottom, (spare), wall corner, wall left/right, pit (with lit top edge), pit (inside), (spare), (spare)
##   row 2: rock, pillar, crate, (spare)
##
## Soft-lock safety (every 0.4 s): enemies stuck in a wall / obstacle / pit are moved to the nearest
## free floor, the alive counter is re-counted from the real enemies, and a player who ends up
## outside the room is sent through the door they were heading for (or put back inside).

signal cleared
signal door_entered(direction: Vector2i)

const TILE := 16
const ENTRY_OFFSET := 20.0
const DEFAULT_TILES := "res://art/tiles/dungeon_tiles.png"
const ASH_PICKUP_PATH := "res://scenes/pickups/ash_pickup.tscn"
## Physics layer 8: pits. Walkers (player, enemies) collide with it, bullets don't.
const PIT_LAYER := 128

const FLOOR_TILES := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const WALL_H := Vector2i(0, 1)
const WALL_CORNER := Vector2i(2, 1)
const WALL_V := Vector2i(3, 1)
const OBSTACLE_TILES := {"R": Vector2i(0, 2), "P": Vector2i(1, 2), "C": Vector2i(2, 2)}
const SPIKES_DOWN := Vector2i(4, 0)
const SPIKES_UP := Vector2i(5, 0)
const LAVA := [Vector2i(6, 0), Vector2i(7, 0)]
const PIT := Vector2i(4, 1)
const PIT_DEEP := Vector2i(5, 1)

const SOLID := "#RPC"
const WALKABLE := ".S^~"

const SPAWN_DELAY := 0.45
const BOSS_SPAWN_DELAY := 1.0
const SPIKE_CYCLE := 1.8
const SPIKE_UP_TIME := 0.7
const SAFETY_INTERVAL := 0.4

var coord := Vector2i.ZERO
var room_type: int = FloorGenerator.RoomType.COMBAT
var floor_data: FloorData
var is_cleared := false
var alive := 0
var cols := 30
var rows := 16
var room_size := Vector2(480, 256)
var center := Vector2(240, 128)

var enemies_layer: Node2D
var pickups_layer: Node2D
var special_layer: Node2D

var _grid: Array[String] = []
var _tiles: Texture2D
var _wide_sheet := false
var _doors: Dictionary = {}       # Vector2i -> Door
var _has_door: Dictionary = {}    # Vector2i -> bool
var _spawn_points: Array[Vector2] = []
var _pending: Array = []          # [EnemyData, Vector2, hp_multiplier] waiting to spawn
var _markers: Array[Node] = []
var _wave_started := false
var _has_spikes := false
var _has_lava := false
var _spikes_up := false
var _lava_frame := 0
var _t := 0.0
var _safety_left := SAFETY_INTERVAL


## Run calls this right after add_child() and after connecting `cleared` / `door_entered`.
func setup(p_coord: Vector2i, type: int, neighbours: Dictionary, already_cleared: bool,
		fd: FloorData, template: Array) -> void:
	coord = p_coord
	room_type = type
	floor_data = fd
	var path := DEFAULT_TILES
	if fd and fd.tiles_path != "" and ResourceLoader.exists(fd.tiles_path):
		path = fd.tiles_path
	_tiles = load(path) as Texture2D
	_wide_sheet = _tiles != null and _tiles.get_width() >= 8 * TILE
	rows = template.size() + 2
	cols = (template[0] as String).length() + 2
	room_size = Vector2(cols * TILE, rows * TILE)
	center = room_size / 2.0
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
			return Vector2(center.x, TILE + ENTRY_OFFSET)
		Vector2i.DOWN:
			return Vector2(center.x, room_size.y - TILE - ENTRY_OFFSET)
		Vector2i.LEFT:
			return Vector2(TILE + ENTRY_OFFSET, center.y + 8.0)
		Vector2i.RIGHT:
			return Vector2(room_size.x - TILE - ENTRY_OFFSET, center.y + 8.0)
	return center + Vector2(0, 8)


# --- Queries (also used by bosses) -------------------------------------------------------

func cell_of(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / TILE), floori(local_pos.y / TILE))


func cell_char(local_pos: Vector2) -> String:
	var c := cell_of(local_pos)
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return "#"
	return _grid[c.y][c.x]


func is_walkable_cell(c: Vector2i) -> bool:
	if c.x < 1 or c.y < 1 or c.x >= cols - 1 or c.y >= rows - 1:
		return false
	return WALKABLE.contains(_grid[c.y][c.x])


## The nearest walkable floor position to `local_pos` (itself if it's already fine).
func nearest_free(local_pos: Vector2) -> Vector2:
	var start := cell_of(local_pos)
	if is_walkable_cell(start):
		return local_pos
	start = start.clamp(Vector2i(1, 1), Vector2i(cols - 2, rows - 2))
	for r in maxi(cols, rows):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := start + Vector2i(dx, dy)
				if is_walkable_cell(c) and not "^~".contains(_grid[c.y][c.x]):
					return _cell_center(c.x, c.y) + Vector2(0, 4)
	return center


## A random safe floor position at least `min_dist` px from `away_from` (room-local).
func random_free_point(away_from: Vector2, min_dist: float) -> Vector2:
	for i in 60:
		var c := Vector2i(randi_range(2, cols - 3), randi_range(2, rows - 3))
		var p := _cell_center(c.x, c.y) + Vector2(0, 4)
		if ".S".contains(_grid[c.y][c.x]) and p.distance_to(away_from) >= min_dist:
			return p
	return nearest_free(center)


## The room's floor area (inside the walls) in global coordinates.
func inner_rect_global() -> Rect2:
	return Rect2(to_global(Vector2(TILE, TILE)), room_size - Vector2(TILE * 2, TILE * 2))


# --- Building ------------------------------------------------------------------------

func _build_grid(template: Array) -> void:
	_grid.clear()
	for row in rows:
		var line := ""
		for col in cols:
			var ch := "."
			if row == 0 or row == rows - 1 or col == 0 or col == cols - 1:
				ch = "#"
			else:
				var t_row := row - 1
				var t_col := col - 1
				if t_row < template.size():
					var tline: String = template[t_row]
					if t_col < tline.length():
						ch = tline[t_col]
			line += ch
			if ch == "^":
				_has_spikes = true
			elif ch == "~":
				_has_lava = true
		_grid.append(line)


func _build_layers() -> void:
	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	add_child(solids)
	var pits := StaticBody2D.new()
	pits.name = "Pits"
	pits.collision_layer = PIT_LAYER
	pits.collision_mask = 0
	add_child(pits)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	var pit_shape := RectangleShape2D.new()
	pit_shape.size = Vector2(TILE - 4, TILE - 4)   # a little forgiving at the edges

	for row in rows:
		for col in cols:
			var ch := _grid[row][col]
			if SOLID.contains(ch) and _gap_side(col, row) == Vector2i.ZERO:
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = _cell_center(col, row)
				solids.add_child(cs)
			elif ch == "O":
				var ps := CollisionShape2D.new()
				ps.shape = pit_shape
				ps.position = _cell_center(col, row)
				pits.add_child(ps)
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
			return Vector2(center.x, TILE / 2.0)
		Vector2i.DOWN:
			return Vector2(center.x, room_size.y - TILE / 2.0)
		Vector2i.LEFT:
			return Vector2(TILE / 2.0, center.y)
		_:
			return Vector2(room_size.x - TILE / 2.0, center.y)


## Which wall gap (door opening) a cell belongs to, or ZERO.
func _gap_side(col: int, row: int) -> Vector2i:
	var gx := cols / 2
	var gy := rows / 2
	if (col == gx - 1 or col == gx) and row == 0:
		return Vector2i.UP
	if (col == gx - 1 or col == gx) and row == rows - 1:
		return Vector2i.DOWN
	if (row == gy - 1 or row == gy) and col == 0:
		return Vector2i.LEFT
	if (row == gy - 1 or row == gy) and col == cols - 1:
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE / 2.0, row * TILE + TILE / 2.0)


func _draw() -> void:
	if _tiles == null or _grid.is_empty():
		return
	for row in rows:
		for col in cols:
			var ch := _grid[row][col]
			var pos := Vector2(col * TILE, row * TILE)
			var side := _gap_side(col, row)
			var is_open_gap := side != Vector2i.ZERO and bool(_has_door.get(side, false))
			if ch == "#" and not is_open_gap:
				_draw_tile(_wall_tile(col, row), pos)
				continue
			match ch:
				"O":
					var deep := row > 0 and _grid[row - 1][col] == "O"
					_draw_special(PIT_DEEP if deep else PIT, pos, Color(0.02, 0.01, 0.03))
					continue
				"~":
					_draw_special(LAVA[_lava_frame], pos, Color("#e0561f") if _lava_frame == 0 else Color("#f2843a"))
					continue
			_draw_tile(_floor_tile(col, row), pos)
			if OBSTACLE_TILES.has(ch):
				_draw_tile(OBSTACLE_TILES[ch], pos)
			elif ch == "^":
				_draw_special(SPIKES_UP if _spikes_up else SPIKES_DOWN, pos, Color(0.8, 0.8, 0.85, 0.9 if _spikes_up else 0.3))


func _draw_tile(atlas: Vector2i, pos: Vector2) -> void:
	var size := Vector2(TILE, TILE)
	draw_texture_rect_region(_tiles, Rect2(pos, size), Rect2(Vector2(atlas) * TILE, size))


## Tiles that only exist on the wide biome sheets; plain shapes on the old 4 x 3 sheet.
func _draw_special(atlas: Vector2i, pos: Vector2, fallback: Color) -> void:
	if _wide_sheet:
		_draw_tile(atlas, pos)
		return
	if atlas == SPIKES_UP or atlas == SPIKES_DOWN:
		_draw_tile(FLOOR_TILES[0], pos)
		for i in 3:
			var x := pos.x + 3 + i * 5
			draw_colored_polygon(PackedVector2Array([Vector2(x, pos.y + 12), Vector2(x + 2, pos.y + 4), Vector2(x + 4, pos.y + 12)]), fallback)
	else:
		draw_rect(Rect2(pos, Vector2(TILE, TILE)), fallback)


func _wall_tile(col: int, row: int) -> Vector2i:
	var on_x_edge := col == 0 or col == cols - 1
	var on_y_edge := row == 0 or row == rows - 1
	if on_x_edge and on_y_edge:
		return WALL_CORNER
	if on_y_edge or not on_x_edge:
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


# --- Hazards and safety ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if _has_spikes:
		var up := fmod(_t, SPIKE_CYCLE) > SPIKE_CYCLE - SPIKE_UP_TIME
		if up != _spikes_up:
			_spikes_up = up
			queue_redraw()
	if _has_lava:
		var frame := int(_t * 2.5) % 2
		if frame != _lava_frame:
			_lava_frame = frame
			queue_redraw()

	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.is_dead:
		var ch := cell_char(to_local(player.global_position))
		if ch == "^" and _spikes_up:
			player.take_damage(1, "Spikes")
		elif ch == "~":
			player.take_damage(1, "Lava")

	_safety_left -= delta
	if _safety_left <= 0.0:
		_safety_left = SAFETY_INTERVAL
		_safety_check(player)


func _body_point(body: Node2D) -> Vector2:
	var shape := body.get_node_or_null("CollisionShape2D") as Node2D
	return body.position + (shape.position if shape else Vector2.ZERO)


func _safety_check(player: Player) -> void:
	# 1) Enemies stuck inside walls, obstacles or pits (bullets can't reach them) get freed.
	var living := 0
	for child in enemies_layer.get_children():
		var e := child as Enemy
		if e == null or e.is_dying:
			continue
		living += 1
		if not is_walkable_cell(cell_of(_body_point(e))):
			e.position = nearest_free(e.position)
			e.velocity = Vector2.ZERO
	# 2) The alive counter can never stay higher than the real number of enemies.
	if _wave_started and _pending.is_empty() and living != alive:
		alive = living
		if alive <= 0 and not is_cleared:
			_clear()

	# 3) A player outside the room goes through the door (or back inside).
	if player == null or player.is_dead:
		return
	var lp := to_local(player.global_position)
	if not Rect2(Vector2.ZERO, room_size).has_point(lp):
		var dir := Vector2i.ZERO
		if lp.y < 0.0:
			dir = Vector2i.UP
		elif lp.y > room_size.y:
			dir = Vector2i.DOWN
		elif lp.x < 0.0:
			dir = Vector2i.LEFT
		else:
			dir = Vector2i.RIGHT
		if is_cleared and bool(_has_door.get(dir, false)):
			door_entered.emit(dir)
		else:
			player.global_position = to_global(nearest_free(lp))
		return
	var pc := cell_of(lp + Vector2(0, -4))
	if _gap_side(pc.x, pc.y) == Vector2i.ZERO and not is_walkable_cell(pc):
		player.global_position = to_global(nearest_free(lp))


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
	var boss_id := floor_data.boss_id if floor_data else Content.BOSS_ID
	var boss: EnemyData = Content.get_enemy(boss_id)
	if boss == null:
		push_error("Room: no boss EnemyData with id '%s'" % boss_id)
		_clear()
		return
	_pending = [[boss, center + Vector2(0, -16), 1.0]]
	_show_markers()
	get_tree().create_timer(BOSS_SPAWN_DELAY, false).timeout.connect(_spawn_wave)


## Spends the floor's budget (more in bigger rooms) on random enemies from its pool.
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
			points.append(random_free_point(center, 0.0))
	points.shuffle()

	var area_scale := clampf(float(cols * rows) / (30.0 * 16.0), 1.0, 2.0)
	var budget := roundi(floor_data.combat_budget * area_scale)
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
		marker.position = nearest_free(entry[1])
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
	_wave_started = true
	if alive <= 0 and not is_cleared:
		_clear()


## Spawns one enemy at a room-local position (moved to free floor if needed). Also used for summons.
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
	enemy.position = nearest_free(pos)
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
	pickup.global_position = to_global(nearest_free(to_local(pos)))
	if is_cleared and pickup is Pickup:
		(pickup as Pickup).start_homing(0.5)


func _on_enemy_died(_enemy: Enemy) -> void:
	alive = maxi(alive - 1, 0)
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
		stairs.position = center
		special_layer.add_child(stairs)


func _spawn_treasure(available: bool) -> void:
	var treasure := Treasure.new()
	treasure.name = "Treasure"
	treasure.available = available
	treasure.position = center + Vector2(0, 8)
	special_layer.add_child(treasure)
	treasure.used.connect(func() -> void: cleared.emit())


func _spawn_bonus_ash() -> void:
	if floor_data.clear_bonus_ash <= 0:
		return
	var scene := load(ASH_PICKUP_PATH) as PackedScene
	var pieces := 5
	var per_piece := maxi(1, roundi(floor_data.clear_bonus_ash / float(pieces)))
	for i in pieces:
		var pickup := scene.instantiate() as Pickup
		pickup.value = per_piece
		pickups_layer.add_child(pickup)
		pickup.position = center + Vector2.from_angle(TAU * i / pieces) * 10.0


func _on_door_entered(dir: Vector2i) -> void:
	if is_cleared:
		door_entered.emit(dir)
