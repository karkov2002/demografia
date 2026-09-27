class_name TransferCommand
extends Command
## Fait passer des individus d'un rôle à un autre dans une case (colons compris, voir Population.SETTLER).

var cell: Vector2i
var from_role: String
var to_role: String
var amount: int


func _init(player: int, target_cell: Vector2i, from: String, to: String, count: int = 1) -> void:
	player_id = player
	cell = target_cell
	from_role = from
	to_role = to
	amount = count


func apply(world: World) -> bool:
	return world.transfer(player_id, cell, from_role, to_role, amount) > 0
