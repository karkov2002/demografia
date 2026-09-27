class_name AIController
extends RefCounted
## Joueur IA : observe le monde et agit en émettant des commandes, exactement comme un humain.
## Pour l'instant sans stratégie : il s'installe sur une case au hasard, puis ne fait plus rien.

var player_id: int

var _world: World
var _rng: RandomNumberGenerator


func _init(world: World, ai_player_id: int, rng: RandomNumberGenerator) -> void:
	_world = world
	player_id = ai_player_id
	_rng = rng


## Case de départ tirée au hasard parmi celles où le départ est permis (jamais sur l'eau).
func choose_start() -> Command:
	var candidates: Array[Vector2i] = []
	for row in _world.rows:
		for column in _world.columns:
			var cell := Vector2i(column, row)
			if _world.can_start_at(player_id, cell):
				candidates.append(cell)
	if candidates.is_empty():
		return null
	return StartCommand.new(player_id, candidates[_rng.randi_range(0, candidates.size() - 1)])


## Commandes à jouer après chaque cycle.
func play_cycle() -> Array[Command]:
	return []
