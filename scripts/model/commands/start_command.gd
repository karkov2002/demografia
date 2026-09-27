class_name StartCommand
extends Command
## Choix de la case de départ.

var cell: Vector2i


func _init(player: int, start_cell: Vector2i) -> void:
	player_id = player
	cell = start_cell


func apply(world: World) -> bool:
	return world.start_at(player_id, cell)
