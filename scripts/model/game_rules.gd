class_name GameRules
extends Resource
## Réglages de la partie, modifiables dans l'inspecteur (res://data/game_rules.tres).

## Effectif de référence des durées de croissance.
const FULL_POPULATION := 1024.0

@export var columns: int = 10
@export var rows: int = 10
## Nombre de cases de montagne et d'eau placées au hasard sur la carte (le reste est en prairie).
@export var mountain_count: int = 5
@export var water_count: int = 5
## Durée d'un cycle, en secondes.
@export var cycle_duration: float = 1.0
## Population posée sur la case de départ.
@export var starting_population: Dictionary[String, float] = {"worker": 2.0, "scientist": 0.0, "fighter": 0.0}
## Facteur de difficulté des IA : multiplie l'accroissement de leur population à chaque cycle.
@export var ai_growth_factor: float = 0.8
## Workers ajoutés à chaque clic sur le bouton Boost.
@export var boost_workers: int = 1
## Nombre maximal de fighters dans la troupe d'une case (assez pour lancer toute la garnison).
@export var max_army: int = 1024
## Bataille, à chaque cycle et pour chaque paire de camps : un fighter attaquant tombe en tuant 1
## fighter de l'armée du défenseur, ou à défaut ce nombre de workers, ou à défaut ce nombre de
## scientists. La garnison (fighters restés dans la case) défend mieux : pour en tuer un, l'attaquant
## perd army_per_garrison fighters.
@export var army_per_garrison: int = 2
@export var workers_per_fighter: int = 5
@export var scientists_per_fighter: int = 10
## Nombre maximal de colons en attente sur une case.
@export var max_settlers: int = 32
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
## Temps (en secondes) pour qu'un rôle passe de 1 à 1024 ; 0 = ne grandit jamais.
@export var time_to_full: Dictionary[String, float] = {"worker": 300.0, "scientist": 1200.0, "fighter": 0.0}


## Multiplicateur appliqué à chaque rôle à chaque cycle : 1024^(durée d'un cycle / temps pour atteindre 1024).
func growth_rates() -> Dictionary[String, float]:
	var rates: Dictionary[String, float] = {}
	for role in time_to_full:
		var seconds := time_to_full[role]
		rates[role] = 1.0 if seconds <= 0.0 else pow(FULL_POPULATION, cycle_duration / seconds)
	return rates
