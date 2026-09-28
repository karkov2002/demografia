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

@export_group("Boost")
## Clics par seconde pendant une rafale sur le bouton Boost.
@export var boost_clicks_per_second: float = 5.0
## Durées moyennes (s) d'une rafale de clics et de la pause qui la suit.
@export var boost_burst_seconds: float = 5.0
@export var boost_pause_seconds: float = 5.0

@export_group("Expansion")
## Une case envoie des colons quand sa population atteint cette part de sa capacité.
@export_range(0.0, 1.0) var settle_fill_ratio: float = 0.1
## Colons envoyés à chaque fois (dans la limite de rules.max_settlers).
@export var settlers_per_wave: int = 16

@export_group("Défense et science")
## Garnison visée sur une case frontalière : cette part de la plus grosse population ennemie voisine.
@export var garrison_ratio: float = 0.4
## Scientists visés dans chaque case : cette part de sa population (workers, scientists et fighters).
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


static func of_level(level: Level) -> AIProfile:
	return load(PATHS[level])
