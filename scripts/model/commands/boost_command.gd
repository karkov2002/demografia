class_name BoostCommand
extends Command
## Coup de pouce manuel : ajoute des workers dans une case du joueur.

var cell: Vector2i


func _init(player: int, target_cell: Vector2i) -> void:
	player_id = player
	cell = target_cell


func apply(world: World) -> bool:
	return world.boost(player_id, cell) > 0
