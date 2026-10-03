class_name MapGenerator
extends RefCounted
## Génération de la carte selon son type (voir MapType), puis des cases de départ des joueurs, tirées au
## hasard (humain compris) mais loin les unes des autres :
## - ISLANDS : de l'eau partout, et deux fois plus de grandes îles que de joueurs ; chaque joueur démarre
##   seul sur une île ;
## - CONTINENTS : deux continents entourés d'océan, au moins un joueur sur chacun ;
## - LAKES : une grande plaine semée de quelques grandes étendues d'eau ;
## - MEDITERRANEAN : une grande mer centrale, entourée de terres jusqu'aux bords de la carte.
## Sur les terres, les montagnes sont semées au hasard (en nombre variable), forêts, collines et marais
## posés en petits massifs, les marais près de l'eau. Les cases de départ sont des plaines.

enum MapType { ISLANDS, CONTINENTS, LAKES, MEDITERRANEAN }

## Nom affiché de chaque type de carte (clé de texte, voir Locale).
const MAP_TYPE_NAMES := {
	MapType.ISLANDS: "MAP_ISLANDS",
	MapType.CONTINENTS: "MAP_CONTINENTS",
	MapType.LAKES: "MAP_LAKES",
	MapType.MEDITERRANEAN: "MAP_MEDITERRANEAN",
}
## Côté minimal de la carte (largeur et hauteur) selon le type et le nombre de joueurs (2 à 4), pour que
## ses contraintes tiennent : îles séparées par l'eau, continents entourés d'océan, mer centrale bordée de
## terres.
const MIN_SIDES := {
	MapType.ISLANDS: [8, 9, 11],
	MapType.CONTINENTS: [7, 8, 8],
	MapType.LAKES: [4, 5, 6],
	MapType.MEDITERRANEAN: [6, 6, 7],
}
## Taille minimale (en cases) d'une île, et d'un massif de forêt, colline ou marais (au plus le double).
const MIN_ISLAND := 4
const MIN_PATCH := 1
## Tentatives de génération avant d'accepter une carte qui ne respecte pas toutes ses contraintes.
const ATTEMPTS := 30


## Côté minimal de la carte pour `map_type` et `player_count` joueurs.
static func min_side(map_type: MapType, player_count: int) -> int:
	var sides: Array = MIN_SIDES[map_type]
	return sides[clampi(player_count - 2, 0, sides.size() - 1)]


## Génère le terrain de `world` (de type `map_type`) et renvoie une case de départ par joueur
## (`player_count`), toutes en plaine, dans l'ordre des joueurs.
static func generate(world: World, rng: RandomNumberGenerator, map_type: MapType, player_count: int) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	for attempt in ATTEMPTS:
		var regions := _land(world, rng, map_type, player_count)
		starts = _starts(world, rng, regions, map_type, player_count)
		if starts.size() == player_count:
			break
	if starts.size() < player_count:
		# Carte trop petite pour ses contraintes : les départs manquants vont sur les terres les plus
		# éloignées des autres, sans plus exiger une île ou un continent par joueur.
		starts = _starts(world, rng, [_land_cells(world)], MapType.LAKES, player_count)
	_land_features(world, rng, starts)
	return starts


# --- Terres et eau -------------------------------------------------------------------------------

## Pose l'eau et la terre (en plaine) selon le type de carte ; renvoie les régions de terre où répartir
## les joueurs (les îles, les continents, ou toutes les terres d'un seul tenant pour les autres types).
static func _land(world: World, rng: RandomNumberGenerator, map_type: MapType, player_count: int) -> Array:
	var all := _all_cells(world)
	match map_type:
		MapType.ISLANDS:
			_fill(world, all, Terrain.Type.WATER)
			var count := player_count * 2
			var size := maxi(MIN_ISLAND, roundi(all.size() * world.rules.islands_land_ratio / count))
			return _grow_blobs(world, rng, _spread_seeds(world, rng, count, 1), size, true)
		MapType.CONTINENTS:
			_fill(world, all, Terrain.Type.WATER)
			var size := roundi(all.size() * world.rules.continents_land_ratio / 2.0)
			var wide := world.columns >= world.rows
			var seeds: Array[Vector2i] = [
				Vector2i(world.columns / 4, world.rows / 2) if wide else Vector2i(world.columns / 2, world.rows / 4),
				Vector2i(world.columns * 3 / 4, world.rows / 2) if wide else Vector2i(world.columns / 2, world.rows * 3 / 4),
			]
			return _grow_blobs(world, rng, seeds, size, true)
		MapType.LAKES:
			_fill(world, all, Terrain.Type.PRAIRIE)
			var water := roundi(world.rules.water_count * all.size() / world.rules.map_reference_cells)
			var lakes := maxi(1, roundi(water / 6.0))
			var blobs := _grow_blobs(world, rng, _spread_seeds(world, rng, lakes, 0), maxi(1, water / lakes), false)
			for blob in blobs:
				_fill(world, blob, Terrain.Type.WATER)
			return [_land_cells(world)]
		_:
			_fill(world, all, Terrain.Type.PRAIRIE)
			_mediterranean_sea(world, rng)
			return [_land_cells(world)]


## Mer centrale : les cases les plus proches du centre de la carte (distance déformée par un bruit, pour
## une côte découpée), jusqu'à rules.mediterranean_sea_ratio de la carte, jamais sur les bords.
static func _mediterranean_sea(world: World, rng: RandomNumberGenerator) -> void:
	var center := Vector2((world.columns - 1) / 2.0, (world.rows - 1) / 2.0)
	var scale := Vector2(maxf(1.0, world.columns / 2.0), maxf(1.0, world.rows / 2.0))
	var distances := {}
	var inner: Array[Vector2i] = []
	for cell in _all_cells(world):
		if cell.x == 0 or cell.y == 0 or cell.x == world.columns - 1 or cell.y == world.rows - 1:
			continue
		var offset := (_position(cell) - center) / scale
		distances[cell] = offset.length() * rng.randf_range(0.8, 1.2)
		inner.append(cell)
	inner.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return distances[a] < distances[b])
	var sea := mini(inner.size(), roundi(_all_cells(world).size() * world.rules.mediterranean_sea_ratio))
	_fill(world, inner.slice(0, sea), Terrain.Type.WATER)


## Fait grandir une région de terre (ou d'eau) depuis chaque graine de `seeds`, case par case parmi ses
## voisines (de préférence celles qui touchent le plus la région, pour des formes compactes), jusqu'à `size` cases chacune, en alternance. Avec `separated`, deux régions ne se
## touchent jamais et ne vont pas sur les bords de la carte (terres entourées d'eau). Renvoie les régions
## (tableaux de cases) ; leurs cases passent en plaine (avec `separated`) ou restent à poser.
static func _grow_blobs(world: World, rng: RandomNumberGenerator, seeds: Array[Vector2i], size: int,
		separated: bool) -> Array:
	var owner_of := {}
	var blobs: Array = []
	for i in seeds.size():
		blobs.append([seeds[i]])
		owner_of[seeds[i]] = i
	var growing := true
	while growing:
		growing = false
		for i in blobs.size():
			if blobs[i].size() >= size:
				continue
			var candidates: Array[Vector2i] = []
			for cell in blobs[i]:
				for neighbor in world.neighbors(cell):
					if owner_of.has(neighbor) or (separated and _on_border(world, neighbor)):
						continue
					if separated and _touches_other(world, neighbor, i, owner_of):
						continue
					candidates.append(neighbor)
			if candidates.is_empty():
				continue
			# Région compacte : on préfère les cases qui touchent déjà le plus de cases de la région.
			var chosen := candidates[0]
			var best_score := -INF
			for candidate in candidates:
				var score := rng.randf() * 1.5
				for neighbor in world.neighbors(candidate):
					if owner_of.get(neighbor, -1) == i:
						score += 1.0
				if score > best_score:
					chosen = candidate
					best_score = score
			blobs[i].append(chosen)
			owner_of[chosen] = i
			growing = true
	if separated:
		for blob in blobs:
			_fill(world, blob, Terrain.Type.PRAIRIE)
	return blobs


## `cell` touche-t-elle une case d'une autre région que `blob` ?
static func _touches_other(world: World, cell: Vector2i, blob: int, owner_of: Dictionary) -> bool:
	for neighbor in world.neighbors(cell):
		if owner_of.has(neighbor) and owner_of[neighbor] != blob:
			return true
	return false


static func _on_border(world: World, cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == world.columns - 1 or cell.y == world.rows - 1


## `count` graines bien réparties : chacune la plus loin possible des précédentes (parmi quelques
## tirages), à au moins `margin` cases des bords.
static func _spread_seeds(world: World, rng: RandomNumberGenerator, count: int, margin: int) -> Array[Vector2i]:
	var pool: Array[Vector2i] = []
	for cell in _all_cells(world):
		if cell.x >= margin and cell.y >= margin and cell.x < world.columns - margin and cell.y < world.rows - margin:
			pool.append(cell)
	if pool.is_empty():
		pool = _all_cells(world)
	var seeds: Array[Vector2i] = []
	for i in count:
		var best := pool[rng.randi_range(0, pool.size() - 1)]
		var best_distance := -1
		for draw in 12:
			var candidate := pool[rng.randi_range(0, pool.size() - 1)]
			var distance := _distance_to_all(candidate, seeds)
			if distance > best_distance:
				best = candidate
				best_distance = distance
		seeds.append(best)
	return seeds


# --- Cases de départ -----------------------------------------------------------------------------

## Une case de départ par joueur, en plaine ou sur une terre qui le deviendra, la plus éloignée possible
## des autres départs. Sur les îles, chaque joueur a son île ; sur les continents, les joueurs sont
## répartis en alternance (au moins un par continent). Renvoie moins de cases que de joueurs si la carte
## ne le permet pas.
static func _starts(world: World, rng: RandomNumberGenerator, regions: Array, map_type: MapType,
		player_count: int) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	var usable: Array = []
	for region in regions:
		if region.size() >= MIN_ISLAND or map_type != MapType.ISLANDS:
			usable.append(region)
	_shuffle(usable, rng)
	for player in player_count:
		var candidates: Array = []
		match map_type:
			MapType.ISLANDS:
				if player >= usable.size():
					return starts
				candidates = usable[player]
			MapType.CONTINENTS:
				if usable.size() < 2:
					return starts
				candidates = usable[player % 2]
			_:
				candidates = usable[0] if not usable.is_empty() else []
		var best := World.NO_CELL
		var best_score := -INF
		for cell in candidates:
			if cell in starts:
				continue
			# Loin des autres départs, avec un peu de hasard, et pas collé à l'eau si possible.
			var score := _distance_to_all(cell, starts) + rng.randf() * 1.5 + _land_around(world, cell) * 0.3
			if score > best_score:
				best = cell
				best_score = score
		if best == World.NO_CELL:
			return starts
		starts.append(best)
	return starts


## Nombre de voisines de `cell` hors de l'eau.
static func _land_around(world: World, cell: Vector2i) -> int:
	var count := 0
	for neighbor in world.neighbors(cell):
		if world.terrain(neighbor) != Terrain.Type.WATER:
			count += 1
	return count


# --- Reliefs et végétation -----------------------------------------------------------------------

## Sur les terres : montagnes semées au hasard (leur nombre variant de rules.mountain_spread), puis
## massifs de forêt, de collines et de marais (près de l'eau). Les cases de départ, et leurs voisines
## pour les montagnes, restent en plaine.
static func _land_features(world: World, rng: RandomNumberGenerator, starts: Array[Vector2i]) -> void:
	var rules := world.rules
	# Les quantités suivent la surface des terres (une carte de référence est presque toute en terre).
	var ratio := _land_cells(world).size() / rules.map_reference_cells
	var protected := {}
	for start in starts:
		protected[start] = true
	var free_land := _land_cells(world).filter(func(cell: Vector2i) -> bool: return not protected.has(cell))
	_shuffle(free_land, rng)
	var near_start := {}
	for start in starts:
		for neighbor in world.neighbors(start):
			near_start[neighbor] = true
	var mountains := roundi(rules.mountain_count * ratio * rng.randf_range(rules.mountain_spread.x, rules.mountain_spread.y))
	for cell in free_land:
		if mountains <= 0:
			break
		if not near_start.has(cell):
			world.set_terrain(cell, Terrain.Type.MOUNTAIN)
			mountains -= 1
	_patches(world, rng, Terrain.Type.FOREST, roundi(rules.forest_count * ratio), protected, false)
	_patches(world, rng, Terrain.Type.HILL, roundi(rules.hill_count * ratio), protected, false)
	_patches(world, rng, Terrain.Type.MARSH, roundi(rules.marsh_count * ratio), protected, true)


## Pose `count` cases de `type` en petits massifs (de MIN_PATCH à quelques cases d'un seul tenant) sur les
## plaines encore libres, hors des cases `protected` ; avec `near_water`, les massifs partent d'une plaine
## au bord de l'eau quand il y en a.
static func _patches(world: World, rng: RandomNumberGenerator, type: Terrain.Type, count: int, protected: Dictionary,
		near_water: bool) -> void:
	var guard := 0
	while count > 0 and guard < 200:
		guard += 1
		var plains := _land_cells(world).filter(func(cell: Vector2i) -> bool:
			return world.terrain(cell) == Terrain.Type.PRAIRIE and not protected.has(cell))
		if plains.is_empty():
			return
		if near_water:
			var shore := plains.filter(func(cell: Vector2i) -> bool: return _land_around(world, cell) < world.neighbors(cell).size())
			if not shore.is_empty():
				plains = shore
		var cell: Vector2i = plains[rng.randi_range(0, plains.size() - 1)]
		var size := mini(count, rng.randi_range(MIN_PATCH, 4))
		for i in size:
			world.set_terrain(cell, type)
			count -= 1
			var next: Array[Vector2i] = []
			for neighbor in world.neighbors(cell):
				if world.terrain(neighbor) == Terrain.Type.PRAIRIE and not protected.has(neighbor):
					next.append(neighbor)
			if next.is_empty():
				break
			cell = next[rng.randi_range(0, next.size() - 1)]


# --- Outils --------------------------------------------------------------------------------------

static func _all_cells(world: World) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in world.rows:
		for column in world.columns:
			cells.append(Vector2i(column, row))
	return cells


static func _land_cells(world: World) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _all_cells(world):
		if world.terrain(cell) != Terrain.Type.WATER:
			cells.append(cell)
	return cells


static func _fill(world: World, cells: Array, type: Terrain.Type) -> void:
	for cell in cells:
		world.set_terrain(cell, type)


## Position d'une case dans le plan (rangées impaires décalées d'une demi-case, pas vertical √3/2).
static func _position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + (0.5 if cell.y % 2 == 1 else 0.0), cell.y * sqrt(3.0) / 2.0)


## Distance en cases entre deux cases de la grille « odd-r » (passage en coordonnées cubiques).
static func distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x - (a.y - (a.y & 1)) / 2
	var bq := b.x - (b.y - (b.y & 1)) / 2
	var dq := aq - bq
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## Plus petite distance de `cell` aux cases `others` (une grande valeur s'il n'y en a pas).
static func _distance_to_all(cell: Vector2i, others: Array[Vector2i]) -> int:
	var nearest := 1 << 20
	for other in others:
		nearest = mini(nearest, distance(cell, other))
	return nearest


## Mélange de Fisher-Yates avec `rng` (Array.shuffle utilise le générateur global).
static func _shuffle(cells: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
