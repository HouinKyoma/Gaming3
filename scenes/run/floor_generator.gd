class_name FloorGenerator
extends RefCounted
## Builds a floor layout on a grid: { Vector2i: RoomType }.
## Rooms are only ever added next to an existing room, so every room is reachable.

enum RoomType { START, COMBAT, TREASURE, EXIT, BOSS }

const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const MAX_ATTEMPTS := 50


static func generate(room_count: int, is_boss_floor: bool, rng: RandomNumberGenerator) -> Dictionary:
	room_count = maxi(room_count, 4)
	# The exit / boss must be at least this many rooms from the start (no "skipping" the floor).
	var min_far := clampi(room_count / 2, 2, 5)
	for attempt in MAX_ATTEMPTS * 2:
		var rooms := _grow(room_count, rng)
		if rooms.size() != room_count:
			continue
		var far := 0
		for d in _bfs(rooms).values():
			far = maxi(far, int(d))
		if far >= min_far or attempt >= MAX_ATTEMPTS * 2 - 1:
			_assign_special_rooms(rooms, is_boss_floor, rng)
			return rooms
	push_warning("FloorGenerator: fell back to a smaller layout")
	var fallback := _grow(room_count, rng)
	_assign_special_rooms(fallback, is_boss_floor, rng)
	return fallback


## Random growth from (0,0). A cell is rejected if it would touch 2+ rooms,
## which keeps the map branchy (corridors and dead ends) instead of a solid block.
static func _grow(room_count: int, rng: RandomNumberGenerator) -> Dictionary:
	var rooms := {Vector2i.ZERO: RoomType.START}
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var tries := 0
	while cells.size() < room_count and tries < 500:
		tries += 1
		var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var dir: Vector2i = DIRS[rng.randi_range(0, DIRS.size() - 1)]
		var to: Vector2i = from + dir
		if rooms.has(to) or _neighbour_count(rooms, to) > 1:
			continue
		rooms[to] = RoomType.COMBAT
		cells.append(to)
	return rooms


static func _assign_special_rooms(rooms: Dictionary, is_boss_floor: bool, rng: RandomNumberGenerator) -> void:
	# Exit / boss = the room farthest from the start (in steps).
	var dist := _bfs(rooms)
	var far := Vector2i.ZERO
	for cell: Vector2i in rooms:
		if int(dist[cell]) > int(dist[far]):
			far = cell
	rooms[far] = RoomType.BOSS if is_boss_floor else RoomType.EXIT

	# Treasure = a random remaining dead end (a combat room with exactly one neighbour).
	var dead_ends: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		if rooms[cell] == RoomType.COMBAT and _neighbour_count(rooms, cell) == 1:
			dead_ends.append(cell)
	if not dead_ends.is_empty():
		rooms[dead_ends[rng.randi_range(0, dead_ends.size() - 1)]] = RoomType.TREASURE


static func _bfs(rooms: Dictionary) -> Dictionary:
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var next: Vector2i = cell + d
			if rooms.has(next) and not dist.has(next):
				dist[next] = int(dist[cell]) + 1
				queue.append(next)
	return dist


static func _neighbour_count(rooms: Dictionary, cell: Vector2i) -> int:
	var n := 0
	for d: Vector2i in DIRS:
		if rooms.has(cell + d):
			n += 1
	return n
