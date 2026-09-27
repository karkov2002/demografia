class_name GameHistory
extends RefCounted
## Évolution de la partie, relevée à chaque cycle : population, science accumulée et solde de food
## de chaque joueur.

const POPULATION := "population"
const SCIENCE := "science"
const FOOD := "food"
const METRICS := [POPULATION, SCIENCE, FOOD]

## Instant (s) de chaque relevé.
var times: Array[float] = []

var _series: Dictionary = {}  # mesure → identifiant de joueur → Array[float] des relevés


func record(world: World, time: float) -> void:
	times.append(time)
	for current in world.players:
		_append(POPULATION, current.id, world.total_population(current.id))
		_append(SCIENCE, current.id, current.science)
		_append(FOOD, current.id, world.total_food_balance(current.id))


## Relevés de `metric` pour le joueur, dans l'ordre de `times`.
func series(metric: String, player_id: int) -> Array[float]:
	var values: Array[float] = []
	values.assign(_series.get(metric, {}).get(player_id, []))
	return values


func _append(metric: String, player_id: int, value: float) -> void:
	if not _series.has(metric):
		_series[metric] = {}
	if not _series[metric].has(player_id):
		_series[metric][player_id] = [] as Array[float]
	_series[metric][player_id].append(value)
