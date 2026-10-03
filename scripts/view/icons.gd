class_name Icons
extends RefCounted
## Icônes en pixel art du jeu (générées par res://tools/generate_icons.gd).

const SETTLER := preload("res://assets/icons/settler.png")
## Images de l'animation du chariot en route (roues qui tournent, caisse qui tressaute).
const SETTLER_MOVE: Array[Texture2D] = [
	preload("res://assets/icons/settler_move_0.png"),
	preload("res://assets/icons/settler_move_1.png"),
	preload("res://assets/icons/settler_move_2.png"),
	preload("res://assets/icons/settler_move_3.png"),
]
## Événements sur la carte : victoire (trophée), défaite (épée brisée), terre conquise (drapeau).
const VICTORY := preload("res://assets/icons/victory.png")
const DEFEAT := preload("res://assets/icons/defeat.png")
const COLONY := preload("res://assets/icons/colony.png")
## Images de l'animation du soldat en marche (troupe en route).
const ARMY_MOVE: Array[Texture2D] = [
	preload("res://assets/icons/army_move_0.png"),
	preload("res://assets/icons/army_move_1.png"),
	preload("res://assets/icons/army_move_2.png"),
	preload("res://assets/icons/army_move_3.png"),
]
## Bataille : épées qui s'entrechoquent, et petite explosion.
const CLASH: Array[Texture2D] = [
	preload("res://assets/icons/clash_0.png"),
	preload("res://assets/icons/clash_1.png"),
	preload("res://assets/icons/clash_2.png"),
	preload("res://assets/icons/clash_3.png"),
]
const EXPLOSION: Array[Texture2D] = [
	preload("res://assets/icons/explosion_0.png"),
	preload("res://assets/icons/explosion_1.png"),
	preload("res://assets/icons/explosion_2.png"),
	preload("res://assets/icons/explosion_3.png"),
]
## Ressources de la barre d'action.
const SCIENCE := preload("res://assets/icons/science.png")
const POPULATION := preload("res://assets/icons/population.png")
## Même buste en niveaux de gris, à teinter à la couleur d'un joueur.
const POPULATION_TINT := preload("res://assets/icons/population_tint.png")
## Agglomération d'une case selon son statut, son remplissage et l'époque, en niveaux de gris à teinter
## à la couleur de son propriétaire : village, ville, puis mégapole (voir
## World.is_megapolis). Chaque époque (qui avancera avec la science) aura ses trois images.
const SETTLEMENTS := {
	"antiquity": [
		preload("res://assets/icons/settlement_antiquity_village.png"),
		preload("res://assets/icons/settlement_antiquity_town.png"),
		preload("res://assets/icons/settlement_antiquity_megapolis.png"),
	],
}
const GOLD := preload("res://assets/icons/gold.png")
const FOOD := preload("res://assets/icons/food.png")
## Alerte de famine.
const STARVATION := preload("res://assets/icons/starvation.png")
## Bouton Boost.
const BOOST := preload("res://assets/icons/boost.png")
## Rôles dans le zoom de la case : scientist (fiole) et garnison (tour de château).
const SCIENTIST := preload("res://assets/icons/scientist.png")
const GARRISON := preload("res://assets/icons/garrison.png")
## Guerre : bouton Army et cases où l'armée peut partir, puis bataille en cours.
const SWORD := preload("res://assets/icons/sword.png")
const BATTLE := preload("res://assets/icons/battle.png")
## Déplacement de la troupe vers une case du joueur.
const MARCH := preload("res://assets/icons/march.png")
## Détail de la food d'une case : production nette, échanges avec les voisines, solde.
const FOOD_PRODUCE := preload("res://assets/icons/food_produce.png")
const FOOD_TRADE := preload("res://assets/icons/food_trade.png")
const FOOD_NET := preload("res://assets/icons/food_net.png")
## Flèches de tendance seules : hausse, stabilité, baisse.
const TREND_UP := preload("res://assets/icons/trend_up.png")
const TREND_FLAT := preload("res://assets/icons/trend_flat.png")
const TREND_DOWN := preload("res://assets/icons/trend_down.png")
## Pièce d'or et tendance : l'or monte, stagne ou baisse. GOLD_DOWN signale aussi une case dont la
## population est reconvertie faute d'or.
const GOLD_UP := preload("res://assets/icons/gold_up.png")
const GOLD_FLAT := preload("res://assets/icons/gold_flat.png")
const GOLD_DOWN := preload("res://assets/icons/gold_down.png")
## Pomme et tendance : la food de la case est excédentaire, équilibrée ou déficitaire.
const FOOD_UP := preload("res://assets/icons/food_up.png")
const FOOD_FLAT := preload("res://assets/icons/food_flat.png")
const FOOD_DOWN := preload("res://assets/icons/food_down.png")


## Icône de tendance pour un revenu `income` (par cycle).
static func gold_trend(income: float) -> Texture2D:
	if income > 0.0:
		return GOLD_UP
	if income < 0.0:
		return GOLD_DOWN
	return GOLD_FLAT


## Icône de tendance de la food pour un solde `balance` (par cycle).
static func food_trend(balance: float) -> Texture2D:
	if balance > 0.0:
		return FOOD_UP
	if balance < 0.0:
		return FOOD_DOWN
	return FOOD_FLAT


## Flèche de tendance selon le signe de `change`.
static func trend(change: float) -> Texture2D:
	if change > 0.0:
		return TREND_UP
	if change < 0.0:
		return TREND_DOWN
	return TREND_FLAT


## Palier d'agglomération de `cell` : 0 = village, 1 = ville, 2 = mégapole (voir World.is_megapolis).
static func settlement_tier(world: World, cell: Vector2i) -> int:
	if not world.is_city(cell):
		return 0
	return 2 if world.is_megapolis(cell) else 1


## Petite icône de l'agglomération de `cell` (voir settlement_tier), pour les lignes d'information
## (zoom, belligérants).
static func settlement(world: World, cell: Vector2i, era: String = "antiquity") -> Texture2D:
	return settlement_icon(settlement_tier(world, cell), era)


## Petite icône du palier d'agglomération `tier` (0 = village, 1 = ville, 2 = mégapole).
static func settlement_icon(tier: int, era: String = "antiquity") -> Texture2D:
	return SETTLEMENTS[era][tier]
