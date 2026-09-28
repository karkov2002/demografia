class_name GameRules
extends Resource
## Réglages de la partie, modifiables dans l'inspecteur (res://data/game_rules.tres). Avec les profils
## d'IA (AIProfile, res://data/ai/*.tres), ce sont tous les paramètres d'équilibrage du jeu.

## Effectif de référence des durées de croissance.
const FULL_POPULATION := 1024.0

@export var columns: int = 10
@export var rows: int = 10
## Nombre de cases de montagne et d'eau placées au hasard sur une carte de map_reference_cells cases (le
## reste est en prairie) ; sur une autre taille, ces nombres suivent la proportion.
@export var mountain_count: int = 5
@export var water_count: int = 5
@export var map_reference_cells: float = 100.0
## Règle d'or : population maximale d'une case selon son terrain, tous rôles confondus (0 = inhabitable).
@export var capacity: Dictionary[Terrain.Type, float] = {
	Terrain.Type.PRAIRIE: 1024.0,
	Terrain.Type.MOUNTAIN: 256.0,
	Terrain.Type.WATER: 0.0,
}
## Durée d'un cycle, en secondes.
@export var cycle_duration: float = 1.0
## Population posée sur la case de départ.
@export var starting_population: Dictionary[String, float] = {"worker": 2.0, "scientist": 0.0, "fighter": 0.0}
## Workers ajoutés à chaque clic sur le bouton Boost.
@export var boost_workers: int = 1
## Bouton maintenu (Settler, Army, « + », « - ») : délai (s) avant la première répétition, les suivantes
## attendant hold_delay / n, jusqu'à max_hold_rate individus par seconde. C'est la vitesse à laquelle un
## humain peut mobiliser sa population.
@export var hold_delay: float = 0.4
@export var max_hold_rate: float = 500.0
## Nombre maximal de fighters dans la troupe d'une case (assez pour lancer toute la garnison).
@export var max_army: int = 1024
## Bataille, à chaque cycle et pour chaque paire de camps : un fighter attaquant tombe en tuant 1
## fighter de l'armée du défenseur, ou à défaut ce nombre de workers, ou à défaut ce nombre de
## scientists. La garnison (fighters restés dans la case) défend mieux : pour en tuer un, l'attaquant
## perd army_per_garrison fighters.
@export var army_per_garrison: int = 2
@export var workers_per_fighter: int = 10
@export var scientists_per_fighter: int = 20
## Rapport des forces. Force d'un camp : garrison_strength par fighter de garnison, army_strength par
## fighter d'armée (celle du défenseur comme les fighters des attaquants), worker_strength par worker ;
## celle d'un défenseur en montagne est multipliée par mountain_defense. Dans chaque échange, le camp le
## plus faible subit ses pertes habituelles multipliées par (force adverse ÷ sa force) ^
## force_ratio_exponent ; le plus fort garde ses pertes habituelles. Un exposant au-dessus de 1 fait
## écraser plus vite l'adversaire quand on a une nette supériorité, sans changer grand-chose aux combats
## serrés.
@export var garrison_strength: float = 3.0
@export var army_strength: float = 2.0
@export var worker_strength: float = 0.25
@export var mountain_defense: float = 2.0
@export var force_ratio_exponent: float = 1.5
## Nombre maximal de colons en attente sur une case.
@export var max_settlers: int = 32
## Durée (s) du trajet des colons et des troupes jusqu'à la case voisine ; ils n'y arrivent qu'ensuite.
@export var travel_time: float = 1.0
## Or rapporté (ou coûté, si négatif) par chaque individu d'un rôle, à chaque cycle.
@export var gold_per_role: Dictionary[String, float] = {"worker": 2.0, "scientist": -1.0, "fighter": -1.0}
## Food produite par chaque worker, à chaque cycle.
@export var food_per_worker: float = 3.0
## Food consommée par chaque worker, scientist ou fighter, à chaque cycle.
@export var food_per_individual: float = 1.0
## Famine : délai de grâce (s) pendant lequel une case peut manquer de food sans perte, puis délai
## (s) entre deux morts tant qu'elle en manque.
@export var starvation_grace: float = 1.0
@export var starvation_interval: float = 0.1
## Quand l'or est épuisé : nombre de scientists ou fighters reconvertis en workers à chaque cycle.
@export var conversions_per_cycle: int = 1
## Points de science produits par chaque scientist, à chaque cycle.
@export var science_per_scientist: float = 0.1
## Croissance logistique (courbe en S) : temps (en secondes) pour qu'un rôle seul passe de 1 individu à la
## moitié d'une case de FULL_POPULATION places ; 0 = ne grandit jamais. La case pleine n'est atteinte
## qu'en un temps infini (voir Population.grow).
@export var time_to_half: Dictionary[String, float] = {"worker": 300.0, "scientist": 1200.0, "fighter": 0.0}


## Multiplicateur de chaque rôle par cycle dans une case vide (avant le frein de la courbe en S) :
## (FULL_POPULATION − 1)^(durée d'un cycle / time_to_half), qui fait passer de 1 à la moitié de la case
## en time_to_half.
func growth_rates() -> Dictionary[String, float]:
	var rates: Dictionary[String, float] = {}
	for role in time_to_half:
		var seconds := time_to_half[role]
		rates[role] = 1.0 if seconds <= 0.0 else pow(FULL_POPULATION - 1.0, cycle_duration / seconds)
	return rates
