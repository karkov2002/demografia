class_name Icons
extends RefCounted
## Icônes en pixel art du jeu (générées par res://tools/generate_icons.gd).

const SETTLER := preload("res://assets/icons/settler.png")
## Ressources de la barre d'action.
const SCIENCE := preload("res://assets/icons/science.png")
const POPULATION := preload("res://assets/icons/population.png")
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
