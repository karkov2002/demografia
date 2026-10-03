class_name CellBackground
extends RefCounted
## Fond d'une case vue par un joueur : brouillard si elle est inexplorée, sinon la tuile de son
## terrain, recouverte d'un voile à la couleur de son propriétaire si elle est occupée et en vue,
## d'autant plus opaque qu'elle est remplie, et de son agglomération (village, ville ou mégapole).

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
## Opacité du voile à la couleur du propriétaire sur une case pleine ; elle est proportionnelle à son
## remplissage (habitants, hors troupe, ÷ capacité de son terrain, celle d'une ville).
const MAX_ALPHA := 0.8
## Agglomérations posées sur la tuile, par époque puis par palier (village, ville, mégapole ; voir
## Icons.settlement_tier) : [bâtiments aux couleurs naturelles, toits et bannières à teinter à la couleur
## du propriétaire] (générées par res://tools/generate_settlements.gd, au format des tuiles).
const SETTLEMENTS := {
	"antiquity": [
		[preload("res://assets/settlements/antiquity_village_base.png"),
				preload("res://assets/settlements/antiquity_village_roof.png")],
		[preload("res://assets/settlements/antiquity_town_base.png"),
				preload("res://assets/settlements/antiquity_town_roof.png")],
		[preload("res://assets/settlements/antiquity_megapolis_base.png"),
				preload("res://assets/settlements/antiquity_megapolis_roof.png")],
	],
}
## Opacité de la couleur du propriétaire posée sur les toits : le reste laisse voir leur matière.
const ROOF_TINT := 0.8


## Fond de `cell` en `center`, avec son agglomération si `with_settlement`.
static func draw(canvas: CanvasItem, world: World, viewer_id: int, cell: Vector2i, center: Vector2,
		radius: float, with_settlement: bool = true) -> void:
	var points := HexUtils.hex_points(center, radius)
	var uvs := _tile_uvs(points, center, radius)
	if not world.is_explored(viewer_id, cell):
		canvas.draw_colored_polygon(points, Color.WHITE, uvs, FOG_TILE)
		return
	canvas.draw_colored_polygon(points, Color.WHITE, uvs, TILES[world.terrain(cell)])
	var cell_owner := world.owner(cell)
	if cell_owner == World.NO_PLAYER or not world.is_visible(viewer_id, cell):
		return
	var fill := clampf(world.population(cell).residents() / world.terrain_capacity(cell), 0.0, 1.0)
	var color: Color = PLAYER_COLORS[cell_owner]
	canvas.draw_colored_polygon(points, Color(color, MAX_ALPHA * fill))
	if with_settlement:
		# Même cadre que la tuile : les pixels des bâtiments ont la taille de ceux du terrain.
		var tile_size := Vector2(sqrt(3.0) * radius, 2.0 * radius)
		var rect := Rect2(center - tile_size / 2.0, tile_size)
		var sprites: Array = SETTLEMENTS["antiquity"][Icons.settlement_tier(world, cell)]
		canvas.draw_texture_rect(sprites[0], rect, false)
		canvas.draw_texture_rect(sprites[1], rect, false, Color(color, ROOF_TINT))


## Brouillard posé par-dessus une case avec l'opacité `alpha`, pour le faire disparaître en fondu quand
## la case vient d'être découverte.
static func draw_fog(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	var points := HexUtils.hex_points(center, radius)
	canvas.draw_colored_polygon(points, Color(1.0, 1.0, 1.0, alpha), _tile_uvs(points, center, radius), FOG_TILE)


## Coordonnées de texture des sommets `points` : la tuile est plaquée sur l'hexagone géométrique, dont
## le bord suit exactement la bordure tracée par-dessus, au lieu du contour en escalier des pixels.
static func _tile_uvs(points: PackedVector2Array, center: Vector2, radius: float) -> PackedVector2Array:
	var tile_size := Vector2(sqrt(3.0) * radius, 2.0 * radius)
	var tile_origin := center - tile_size / 2.0
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point - tile_origin) / tile_size)
	return uvs
