class_name SendArmyCommand
extends Command
## Envoie la troupe d'une case vers une case voisine : déplacement ou renfort chez soi, attaque d'une
## case ennemie, ou entrée dans une bataille en cours.

var from_cell: Vector2i
var to_cell: Vector2i


func _init(player: int, from: Vector2i, to: Vector2i) -> void:
	player_id = player
	from_cell = from
	to_cell = to


func apply(world: World) -> bool:
	return world.send_army(player_id, from_cell, to_cell) > 0
