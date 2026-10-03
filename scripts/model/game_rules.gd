class_name GameRules
extends Resource
## Réglages de la partie, modifiables dans l'inspecteur (res://data/game_rules.tres). Avec les profils
## d'IA (AIProfile, res://data/ai/*.tres), ce sont tous les paramètres d'équilibrage du jeu.

## Effectif de référence des durées de croissance.
const FULL_POPULATION := 1024.0

@export var columns: int = 10
@export var rows: int = 10
## Génération de la carte (voir MapGenerator). Les nombres de cases sont donnés pour une carte de
## map_reference_cells cases et suivent la proportion sur une autre taille.
## Montagnes semées au hasard sur les terres, leur nombre variant de mountain_spread[0] à
## mountain_spread[1] fois mountain_count.
@export var mountain_count: int = 6
@export var mountain_spread: Vector2 = Vector2(0.8, 1.8)
## Forêts, collines et marais, posés en petits massifs (les marais près de l'eau).
@export var forest_count: int = 14
@export var hill_count: int = 9
@export var marsh_count: int = 6
## Carte « Lacs » : cases d'eau, en quelques grandes étendues.
@export var water_count: int = 15
@export var map_reference_cells: float = 100.0
## Part des cases en terre : carte « Îles » et carte « Continents ».
@export var islands_land_ratio: float = 0.45
@export var continents_land_ratio: float = 0.5
## Carte « Méditerranée » : part des cases occupée par la mer centrale.
@export var mediterranean_sea_ratio: float = 0.35
## Règle d'or : population maximale d'une case selon son terrain, tous rôles confondus (0 = inhabitable).
@export var capacity: Dictionary[Terrain.Type, float] = {
	Terrain.Type.PRAIRIE: 1024.0,
	Terrain.Type.MOUNTAIN: 256.0,
	Terrain.Type.WATER: 0.0,
	Terrain.Type.FOREST: 768.0,
	Terrain.Type.HILL: 768.0,
	Terrain.Type.MARSH: 512.0,
}
## Population maximale d'un village (toute case peuplée l'est d'abord) : sa croissance s'y arrête net.
## Le joueur peut alors faire passer la case en ville, qui grandit jusqu'à la capacité de son terrain.
## Seuls les villages produisent de la food ; seules les villes accueillent des scientists.
@export var village_capacity: float = 256.0
## Une ville grandit plus lentement : son accroissement par cycle est multiplié par ce facteur.
@export var city_growth_factor: float = 0.5
## Une ville remplie à au moins cette part de la capacité de son terrain est une mégapole : ses remparts
## multiplient la force de sa garnison par megapolis_defense.
@export var megapolis_threshold: float = 2.0 / 3.0
@export var megapolis_defense: float = 1.5
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
## celle d'un défenseur est multipliée par le bonus de son terrain (terrain_defense : montagne, colline). Dans chaque échange, le camp le
## plus faible subit ses pertes habituelles multipliées par (force adverse ÷ sa force) ^
## force_ratio_exponent ; le plus fort garde ses pertes habituelles. Un exposant au-dessus de 1 fait
## écraser plus vite l'adversaire quand on a une nette supériorité, sans changer grand-chose aux combats
## serrés.
@export var garrison_strength: float = 3.0
@export var army_strength: float = 2.0
@export var worker_strength: float = 0.25
@export var terrain_defense: Dictionary[Terrain.Type, float] = {
	Terrain.Type.MOUNTAIN: 2.0,
	Terrain.Type.HILL: 1.5,
}
@export var force_ratio_exponent: float = 1.5
## Nombre maximal de colons en attente sur une case.
@export var max_settlers: int = 32
## Durée (s) du trajet des colons et des troupes jusqu'à la case voisine ; ils n'y arrivent qu'ensuite.
@export var travel_time: float = 1.0
## Or rapporté (ou coûté, si négatif) par chaque individu d'un rôle, à chaque cycle ; un worker d'une
## ville rapporte city_gold_per_worker à la place, un worker de montagne mountain_gold_per_worker (le
## meilleur des deux s'il est les deux).
@export var gold_per_role: Dictionary[String, float] = {"worker": 2.0, "scientist": -1.0, "fighter": -1.0}
@export var city_gold_per_worker: float = 3.0
@export var mountain_gold_per_worker: float = 3.0
## Food produite par chaque worker d'un village, à chaque cycle, selon le terrain (ceux d'une ville n'en
## produisent pas).
@export var food_per_worker: Dictionary[Terrain.Type, float] = {
	Terrain.Type.PRAIRIE: 4.0,
	Terrain.Type.MOUNTAIN: 3.0,
	Terrain.Type.FOREST: 3.0,
	Terrain.Type.HILL: 2.5,
	Terrain.Type.MARSH: 2.0,
}
## Food consommée par chaque worker, scientist ou fighter de la garnison, à chaque cycle : dans un
## village, et dans une ville (un citadin mange plus : 6 villages pleins nourrissent juste une ville
## pleine).
@export var food_per_individual: float = 1.0
@export var city_food_per_individual: float = 3.0
## Food consommée par chaque fighter de la troupe d'une case, à chaque cycle (ration : un village plein
## nourrit juste une troupe complète). Les colons, et les troupes en route ou en bataille, ne mangent pas.
@export var army_food: float = 0.5
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
