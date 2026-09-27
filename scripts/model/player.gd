class_name Player
extends RefCounted
## Un joueur de la partie, humain ou IA : ses ressources et ce qu'il a découvert de la carte.

var id: int
var is_ai: bool
## Multiplicateur de la croissance de sa population (facteur de difficulté des IA).
var growth_factor: float
## Points de science accumulés.
var science: float = 0.0
## A-t-il choisi sa case de départ ? (Il reste vrai même s'il perd ensuite toutes ses cases.)
var started: bool = false
## Or ; ne descend jamais sous 0 (les scientists et fighters sont reconvertis à la place).
var gold: float = 0.0

var _explored: Dictionary[Vector2i, bool] = {}


func _init(player_id: int, ai: bool, factor: float) -> void:
	id = player_id
	is_ai = ai
	growth_factor = factor


func explore(cell: Vector2i) -> void:
	_explored[cell] = true


func has_explored(cell: Vector2i) -> bool:
	return _explored.has(cell)
