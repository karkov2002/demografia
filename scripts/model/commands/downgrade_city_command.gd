class_name DowngradeCityCommand
extends Command
## Fait redevenir village une ville du joueur (bouton « Downgrade to village » du zoom) : elle perd ce
## qui dépasse la capacité d'un village.

var cell: Vector2i


func _init(player: int, target_cell: Vector2i) -> void:
	player_id = player
	cell = target_cell


func apply(world: World) -> bool:
	return world.downgrade_city(player_id, cell)
