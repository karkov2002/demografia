class_name CellBackground
extends RefCounted
## Fond d'une case vue par un joueur : brouillard si elle est inexplorée, sinon la tuile de son
## terrain, recouverte de la couleur de sa population si elle appartient au joueur, ou de la couleur
## de son propriétaire si c'est une case ennemie en vue.

## Tuile en pixel art de chaque terrain (générées par res://tools/generate_tiles.gd).
const TILES := {
	Terrain.Type.PRAIRIE: preload("res://assets/tiles/prairie.png"),
	Terrain.Type.MOUNTAIN: preload("res://assets/tiles/mountain.png"),
	Terrain.Type.WATER: preload("res://assets/tiles/water.png"),
}
const FOG_TILE := preload("res://assets/tiles/fog.png")
## Couleur et nom de couleur de chaque joueur, par identifiant (l'ordre des joueurs fixe leur couleur) :
## bordure de ses cases, courbes de fin de partie. Palette validée pour le daltonisme sur fond sombre.
const PLAYER_COLORS := [Color("4a82f5"), Color("0fa396"), Color("d27a14"), Color("e04464")]
const PLAYER_COLOR_NAMES := ["bleu", "vert", "orange", "rouge"]
## Opacité de la couleur de population posée sur la tuile.
const POPULATION_ALPHA := 0.5
## Opacité du voile à la couleur du joueur posé sur une case ennemie en vue.
const ENEMY_ALPHA := 0.55


static func draw(canvas: CanvasItem, world: World, viewer_id: int, cell: Vector2i, center: Vector2,
		radius: float) -> void:
	# La tuile est plaquée sur l'hexagone géométrique : son bord suit exactement la bordure tracée
	# par-dessus, au lieu du contour en escalier des pixels de l'image.
	var points := HexUtils.hex_points(center, radius)
	var tile_size := Vector2(sqrt(3.0) * radius, 2.0 * radius)
	var tile_origin := center - tile_size / 2.0
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point - tile_origin) / tile_size)
	if not world.is_explored(viewer_id, cell):
		canvas.draw_colored_polygon(points, Color.WHITE, uvs, FOG_TILE)
		return
	canvas.draw_colored_polygon(points, Color.WHITE, uvs, TILES[world.terrain(cell)])
	var population := world.population(cell)
	if population == null:
		return
	# Couleur de population réservée aux cases du joueur : sur une case ennemie, elle trahirait sa
	# composition ; une case ennemie en vue reçoit à la place un voile à la couleur de son propriétaire.
	if population.owner == viewer_id:
		var color := population_color(population)
		color.a = POPULATION_ALPHA
		canvas.draw_colored_polygon(points, color)
	elif world.is_visible(viewer_id, cell):
		var color: Color = PLAYER_COLORS[population.owner]
		color.a = ENEMY_ALPHA
		canvas.draw_colored_polygon(points, color)


## Couleur d'une population : rouge = fighter, vert = worker, bleu = scientist, chaque canal
## allant du noir (0) à l'intensité maximale (1024).
static func population_color(population: Population) -> Color:
	const FULL := 1024.0
	return Color(
			clampf(population.counts["fighter"] / FULL, 0.0, 1.0),
			clampf(population.counts["worker"] / FULL, 0.0, 1.0),
			clampf(population.counts["scientist"] / FULL, 0.0, 1.0))
