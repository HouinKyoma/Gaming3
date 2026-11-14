class_name Door
extends Node2D
## A door in the middle of one wall. Built entirely in code by Room.
##   WALL:   no room on this side; looks like wall and blocks.
##   LOCKED: enemies alive; visible, blocks.
##   OPEN:   room cleared; walking into it emits `entered`.
## The node is rotated so "up" always points out of the room.

signal entered(direction: Vector2i)

enum State { WALL, LOCKED, OPEN }

var direction := Vector2i.UP
var state: State = State.WALL

var _blocker_shape: CollisionShape2D
var _trigger: Area2D
var _visual: EntityVisual


func _ready() -> void:
	rotation = _rotation_for(direction)

	var blocker := StaticBody2D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	_blocker_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 16)
	_blocker_shape.shape = rect
	blocker.add_child(_blocker_shape)
	add_child(blocker)

	_trigger = Area2D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 64
	_trigger.collision_mask = 2
	_trigger.monitorable = false
	var trigger_shape := CollisionShape2D.new()
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = Vector2(28, 6)
	trigger_shape.shape = trigger_rect
	trigger_shape.position = Vector2(0, -5)   # outer edge of the gap
	_trigger.add_child(trigger_shape)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_trigger_body_entered)

	_visual = EntityVisual.new()
	_visual.name = "Visual"
	_visual.art_key = "door"
	_visual.feet_origin = false
	_visual.start_animation = EntityVisual.CLOSED
	add_child(_visual)

	_apply_state()


func set_state(new_state: State) -> void:
	state = new_state
	if is_node_ready():
		_apply_state()


func _apply_state() -> void:
	match state:
		State.WALL:
			visible = false
			_blocker_shape.set_deferred("disabled", false)
			_trigger.set_deferred("monitoring", false)
		State.LOCKED:
			visible = true
			_visual.play(EntityVisual.CLOSED)
			_blocker_shape.set_deferred("disabled", false)
			_trigger.set_deferred("monitoring", false)
		State.OPEN:
			visible = true
			_visual.play(EntityVisual.OPEN)
			_blocker_shape.set_deferred("disabled", true)
			_trigger.set_deferred("monitoring", true)


func _on_trigger_body_entered(body: Node) -> void:
	if state == State.OPEN and body is Player:
		entered.emit(direction)


static func _rotation_for(dir: Vector2i) -> float:
	match dir:
		Vector2i.DOWN:
			return PI
		Vector2i.LEFT:
			return -PI / 2.0
		Vector2i.RIGHT:
			return PI / 2.0
	return 0.0
