class_name Convoy
extends RefCounted
## Colons ou troupe en route d'une case vers une case voisine : ils y arrivent au bout de
## rules.travel_time secondes. En attendant, ceux qui vont s'installer chez leur joueur y réservent
## leur place (règle d'or).

var player_id: int
var from_cell: Vector2i
var to_cell: Vector2i
## Colons, ou fighters de la troupe si `is_army`.
var units: int
var is_army: bool
## Leur place est-elle réservée dans `to_cell` ? (Colons ; troupe envoyée chez son joueur en paix.)
var reserves_room: bool
## Temps de trajet déjà parcouru, en secondes.
var elapsed: float = 0.0


func _init(player: int, from: Vector2i, to: Vector2i, count: int, army: bool, reserved: bool) -> void:
	player_id = player
	from_cell = from
	to_cell = to
	units = count
	is_army = army
	reserves_room = reserved
