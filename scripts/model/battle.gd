class_name Battle
extends RefCounted
## Bataille en cours sur une case : les fighters engagés par chaque joueur venu l'attaquer. Le
## propriétaire de la case, s'il en reste un, s'y défend avec toute sa population.

## Fighters engagés par chaque attaquant ({ joueur: fighters }), sans limite d'effectif.
var fighters: Dictionary[int, int] = {}
## Pertes fractionnaires pas encore subies ({ joueur: pertes }), dues au rapport des forces : elles
## s'accumulent d'un cycle à l'autre et un fighter tombe chaque fois qu'elles atteignent 1.
var wounds: Dictionary[int, float] = {}
## Idem pour l'armée du défenseur.
var defender_army_wounds: float = 0.0


func add(player_id: int, count: int) -> void:
	fighters[player_id] = fighters.get(player_id, 0) + count


func total_fighters() -> int:
	var total := 0
	for count in fighters.values():
		total += count
	return total
