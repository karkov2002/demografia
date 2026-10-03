class_name FoundCityCommand
extends Command
## Fait passer un village plein du joueur en ville (bouton « Progress to city » du zoom).

var cell: Vector2i


func _init(player: int, target_cell: Vector2i) -> void:
	player_id = player
	cell = target_cell


func apply(world: World) -> bool:
	return world.found_city(player_id, cell)
