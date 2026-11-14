extends Enemy
## Walks straight at the player.


func _behaviour(_delta: float) -> Vector2:
	return dir_to_target() * data.move_speed
