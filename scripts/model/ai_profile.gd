class_name AIProfile
extends Resource
## Caractère d'une IA (res://data/ai/*.tres) : son rythme de clics sur Boost, son goût pour l'expansion,
## la défense, la science et l'attaque.

## Niveaux proposés dans la fenêtre « New game », du plus paisible au plus belliqueux.
enum Level { PACIFIST, NORMAL, AGGRESSIVE }

const PATHS := {
	Level.PACIFIST: "res://data/ai/pacifist.tres",
	Level.NORMAL: "res://data/ai/normal.tres",
	Level.AGGRESSIVE: "res://data/ai/aggressive.tres",
}

## Nom affiché (« pacifiste », « normale », « agressive »).
@export var label: String = "normale"
## Handicap de croissance : multiplie l'accroissement de la population de l'IA à chaque cycle (1 = comme
## un humain).
@export var growth_factor: float = 0.8

@export_group("Boost")
## Clics par seconde pendant une rafale sur le bouton Boost, variant au hasard de ± boost_click_jitter.
@export var boost_clicks_per_second: float = 5.0
@export_range(0.0, 1.0) var boost_click_jitter: float = 0.3
## Durées moyennes (s) d'une rafale de clics et de la pause qui la suit, variant au hasard de
## ± boost_phase_jitter.
@export var boost_burst_seconds: float = 5.0
@export var boost_pause_seconds: float = 5.0
@export_range(0.0, 1.0) var boost_phase_jitter: float = 0.5

@export_group("Économie")
## Part de ce que les workers d'une case peuvent nourrir et payer que l'IA consacre à ses scientists et
## à sa garnison (le reste est une marge d'or et de food).
@export_range(0.0, 1.0) var budget_share: float = 0.9
## Workers qu'une case garde toujours, pour continuer à grandir (colons et armées ne les prennent pas).
@export var keep_workers: int = 2

@export_group("Expansion")
## Une case envoie des colons quand sa population atteint cette part de la capacité de son terrain (celle
## d'une ville ; un village plafonne à rules.village_capacity).
@export_range(0.0, 1.0) var settle_fill_ratio: float = 0.1
## Colons envoyés à chaque fois (dans la limite de rules.max_settlers).
@export var settlers_per_wave: int = 16
## Un village plein ne passe en ville que si ses voisines peuvent lui envoyer de quoi nourrir une ville de
## sa taille, avec cette marge (une ville ne produit pas de food, et ses citadins mangent plus).
@export var city_food_margin: float = 1.2

@export_group("Défense et science")
## Garnison visée sur une case frontalière : cette part de la plus grosse population ennemie voisine.
@export var garrison_ratio: float = 0.4
## Scientists visés dans chaque ville (un village n'en accueille pas) : cette part de sa population (workers, scientists et fighters).
@export var science_ratio: float = 0.15

@export_group("Guerre")
## Attaque une case ennemie voisine avec cette marge au-dessus de la plus petite armée qui vaincrait le
## pire cas (toute sa population en garnison) ; 0 = n'attaque jamais.
@export var attack_margin: float = 2.0
## Temps de réaction (s) : l'IA n'attaque une case ennemie qu'après l'avoir vue au moins ce temps, ce
## qui laisse à son propriétaire le temps d'y installer une garnison.
@export var attack_delay: float = 60.0
## Part des workers d'une case que l'IA accepte d'enrôler pour une attaque ou pour secourir une voisine
## assiégée.
@export_range(0.0, 1.0) var army_commit: float = 0.6

@export_group("Rythme")
## Temps (s) entre deux actions sur la carte (une attaque, des renforts envoyés d'une case, ou une vague
## de colons), comme le temps qu'il faut à un humain pour choisir une case, former ses troupes ou ses
## colons et cliquer sur la cible ; varie au hasard de ± action_delay_jitter. Le Boost a son propre
## rythme.
@export var action_delay: float = 3.0
@export_range(0.0, 1.0) var action_delay_jitter: float = 0.3


static func of_level(level: Level) -> AIProfile:
	return load(PATHS[level])
