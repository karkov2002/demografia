class_name SendSettlersCommand
extends Command
## Envoie les colons d'une case vers une case voisine, où ils deviennent des workers.

var from_cell: Vector2i
var to_cell: Vector2i


func _init(player: int, from: Vector2i, to: Vector2i) -> void:
	player_id = player
	from_cell = from
	to_cell = to


func apply(world: World) -> bool:
	return world.send_settlers(player_id, from_cell, to_cell) > 0
