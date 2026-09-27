class_name MapGenerator
extends RefCounted
## Génération du terrain : prairie partout, avec quelques montagnes et étendues d'eau placées au hasard.

## Nombre de cases de la carte pour laquelle rules.mountain_count et rules.water_count sont réglés
## (10 × 10) ; sur une autre taille, ces nombres suivent la proportion.
const REFERENCE_CELLS := 100.0


## Place montagnes et eau en gardant au moins `land_needed` cases hors de l'eau (une case de départ
## par joueur).
static func generate(world: World, rng: RandomNumberGenerator, land_needed: int = 1) -> void:
	var cells: Array[Vector2i] = []
	for row in world.rows:
		for column in world.columns:
			cells.append(Vector2i(column, row))
	_shuffle(cells, rng)
	var ratio := cells.size() / REFERENCE_CELLS
	var water := mini(roundi(world.rules.water_count * ratio), maxi(0, cells.size() - land_needed))
	var mountains := mini(roundi(world.rules.mountain_count * ratio), cells.size() - water)
	for i in mountains:
		world.set_terrain(cells.pop_back(), Terrain.Type.MOUNTAIN)
	for i in water:
		world.set_terrain(cells.pop_back(), Terrain.Type.WATER)


## Mélange de Fisher-Yates avec `rng` (Array.shuffle utilise le générateur global).
static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
