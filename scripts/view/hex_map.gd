class_name HexMap
extends Control
## Carte du monde : grille d'hexagones cliquables, redimensionnée pour tenir entièrement dans le contrôle.
## Disposition « odd-r » : hexagones pointe en haut, rangées impaires décalées d'une demi-case.

## Émis au clic sur une case (indices à partir de 0), ou avec NO_CELL au clic droit, qui désélectionne.
signal cell_selected(cell: Vector2i)
## Émis au clic sur une case cible (chariot, déplacement ou épée) : les colons et la troupe de la case sélectionnée
## doivent y partir.
signal units_sent(to_cell: Vector2i)

@export var border_color: Color = Color(0.55, 0.55, 0.55)
@export var selected_border_color: Color = Color(1.0, 0.85, 0.2)
@export var border_width: float = 2.0
@export var margin: float = 16.0

const NO_CELL := Vector2i(-1, -1)
## Disque sombre sous les icônes de cible (chariot, déplacement, épée), pour les détacher de la tuile.
const SETTLER_TARGET_BACKGROUND := Color(0.0, 0.0, 0.0, 0.45)
## Chariot des colons en route : taille (en rayon de case), part du trajet en fondu au départ comme à
## l'arrivée, et cadence de son animation (images par seconde).
const CONVOY_SIZE := 0.5
const CONVOY_FADE := 0.25
const CONVOY_FPS := 8.0
## Flux de food entre deux cases du joueur : un sac de grain glisse de l'exportatrice vers sa voisine en
## FOOD_FLOW_PERIOD secondes, en boucle, avec un fondu aux deux bouts ; sa taille (en rayons de case) va
## de FOOD_FLOW_SIZE[0] à FOOD_FLOW_SIZE[1] selon la quantité, pleine à FOOD_FLOW_FULL par cycle.
const FOOD_FLOW_PERIOD := 1.6
const FOOD_FLOW_SIZE := [0.32, 0.48]
const FOOD_FLOW_FULL := 512.0
## Frontières des joueurs, au néon : largeur du trait (en multiple de border_width), couches du halo
## lumineux autour, et pulsation de ce halo (par seconde).
const FRONTIER_WIDTH := 2.0
const NEON_GLOW_LAYERS := 4
const NEON_PULSE_RATE := 0.6
## Fortifications des cases en vue qui ont une garnison (ennemies comprises), le long des frontières de
## leur propriétaire (pas entre deux de ses cases) : palissade de pieux, puis mur de pierre crénelé à partir
## de WALL_STONE_GARRISON fighters. Elles montent avec la garnison (échelle logarithmique) : la palissade
## de 1 à WALL_STONE_GARRISON fighters (pieux de STAKE_HEIGHT[0] à STAKE_HEIGHT[1]), le mur de pierre de
## WALL_STONE_GARRISON à WALL_FULL_STONE (de STONE_HEIGHT[0] à STONE_HEIGHT[1]).
## Retrait (en rayons de case) vers l'intérieur de la case, et dimensions en rayons de case.
const WALL_STONE_GARRISON := 100
const WALL_FULL_STONE := 1000
const WALL_INSET := 0.17
const STAKE_SPACING := 0.1
const STAKE_HEIGHT := [0.04, 0.18]
const STONE_HEIGHT := [0.04, 0.26]
const STONE_WIDTH := 0.12
const WOOD_COLORS := [Color("5a3a20"), Color("8a5a30"), Color("b07a44")]
const STONE_COLORS := [Color("4a4a52"), Color("8e8e98"), Color("b8b8c0")]
const WALL_OUTLINE := Color("2a1e14")
## Position de la population d'une case sous son agglomération, en rayons de case sous son centre.
const POPULATION_TEXT_OFFSET := 0.66
## Durée (s) du fondu du brouillard sur une case qui vient d'être découverte.
const REVEAL_TIME := 0.8
## Onde sur la frontière quand le territoire du joueur s'agrandit : vitesse (rayons de case par
## seconde), largeur du front lumineux (en rayons de case), et découpage de chaque côté pour que le front
## glisse en douceur le long d'un côté.
const WAVE_SPEED := 7.0
const WAVE_WIDTH := 0.8
const WAVE_STEPS := 6

## Joueur dont on montre la vue (brouillard de guerre) et qu'on fait agir.
var viewer_id: int = 0
## Monde affiché ; les calques des cases sont mis à jour à chacun de ses changements (voir _refresh_cells).
var world: World:
	set(value):
		world = value
		_build_layers()
		world.changed.connect(_mark_dirty)
		world.owner_changed.connect(_on_owner_changed)
		world.city_founded.connect(_on_city_founded)
		world.city_lost.connect(_on_city_lost)
		_update_layout()
## Case sélectionnée, ou NO_CELL.
var selected_cell: Vector2i = NO_CELL
## Temps (s) écoulé depuis la dernière avance des colons en route (World.move_convoys), pour que leurs
## chariots glissent en continu entre deux avances.
var convoy_time_offset: float = 0.0

var _hex_radius: float = 0.0
var _first_center: Vector2 = Vector2.ZERO  # centre de la case (0, 0)
var _effects := MapEffects.new()
## Cases dont le joueur connaît déjà le terrain, au dernier dessin, et instant (s) où chacune de celles
## qu'il vient de découvrir l'a été (fondu du brouillard en cours).
var _explored_cells: Dictionary[Vector2i, bool] = {}
var _reveals: Dictionary[Vector2i, float] = {}
var _drawn_once: bool = false
## Ondes qui parcourent la frontière du joueur : [case d'où elle part, instant (s) du départ].
var _frontier_waves: Array = []


func _ready() -> void:
	# Tuiles en pixel art : pas de lissage à l'agrandissement.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_update_layout)


func _process(_delta: float) -> void:
	if world == null:
		return
	# Calques des cases mis à jour au plus une fois par image, seulement si le monde a changé.
	if _cells_dirty:
		_refresh_cells()
	# Halo des néons qui pulse (transparence du calque entier), et surcouche animée.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * NEON_PULSE_RATE)
	_glow_root.modulate.a = 0.45 + 0.55 * pulse
	_overlay.queue_redraw()


func _update_layout() -> void:
	if world == null:
		return
	var available := size - Vector2(margin, margin) * 2.0
	# Taille de la grille en unités de rayon : chaque rangée fait sqrt(3) de large (+ une demi-case
	# pour le décalage), et les rangées se chevauchent verticalement (pas de 1.5).
	var grid_units := Vector2((world.columns + 0.5) * sqrt(3.0), 1.5 * (world.rows - 1) + 2.0)
	_hex_radius = maxf(0.0, minf(available.x / grid_units.x, available.y / grid_units.y))
	var top_left := (size - grid_units * _hex_radius) / 2.0
	_first_center = top_left + Vector2(sqrt(3.0) / 2.0, 1.0) * _hex_radius
	# Les signatures des calques comprennent la taille des cases : tout sera redessiné.
	_cells_dirty = true


func cell_center(cell: Vector2i) -> Vector2:
	var hex_width := sqrt(3.0) * _hex_radius
	var row_offset := hex_width / 2.0 if cell.y % 2 == 1 else 0.0
	return _first_center + Vector2(cell.x * hex_width + row_offset, cell.y * 1.5 * _hex_radius)


## Case sous `point`, ou NO_CELL.
func cell_at(point: Vector2) -> Vector2i:
	for row in world.rows:
		for column in world.columns:
			var cell := Vector2i(column, row)
			if Geometry2D.is_point_in_polygon(point, HexUtils.hex_points(cell_center(cell), _hex_radius)):
				return cell
	return NO_CELL


# --- Calques ---------------------------------------------------------------------------------------
# La carte est dessinée en calques gardés en mémoire par le moteur, pour ne pas tout redessiner à chaque
# image (voir _refresh_cells) :
# - terrain : un calque par case (tuile, voile, champs, agglomération, bordure), redessiné quand la case
#   change ;
# - halo des néons : un calque par case ; la pulsation passe par la transparence du calque entier ;
# - frontières et fortifications : un calque par case (néon, palissade ou mur), redessiné quand ses
#   frontières ou sa garnison changent ;
# - surcouche, redessinée à chaque image : fondu du brouillard, ondes, population, sélection,
#   marqueurs, batailles, cibles, sacs de grain, chariots et effets.

## Calque de dessin : appelle `paint` avec lui-même à chaque fois que le moteur le redessine.
class Painter extends Node2D:
	var paint: Callable

	func _init(callback: Callable) -> void:
		paint = callback

	func _draw() -> void:
		paint.call(self)


## Surcouche : comme Painter, mais un Control qui a la taille de la carte (certains effets s'y centrent).
class OverlayPainter extends Control:
	var paint: Callable

	func _init(callback: Callable) -> void:
		paint = callback
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		paint.call(self)


## Calque où dessinent les fonctions _draw_… en ce moment.
var _canvas: CanvasItem
var _terrain_root := Node2D.new()
var _glow_root := Node2D.new()
var _decor_root := Node2D.new()
var _overlay: OverlayPainter
## Calques de chaque case, et ce qu'ils montraient à leur dernier dessin (on ne les redessine que si cela
## change).
var _terrain_painters: Dictionary[Vector2i, Painter] = {}
var _glow_painters: Dictionary[Vector2i, Painter] = {}
var _decor_painters: Dictionary[Vector2i, Painter] = {}
var _terrain_signatures: Dictionary[Vector2i, Array] = {}
var _decor_signatures: Dictionary[Vector2i, Array] = {}
## Le monde a changé depuis la dernière mise à jour des calques ?
var _cells_dirty: bool = true
## Voisines de chaque case avec le numéro du côté qui leur fait face (calculées une fois), et cases que le
## joueur voit, relevées à chaque mise à jour (voir _refresh_cells).
var _neighbor_sides: Dictionary[Vector2i, Array] = {}
var _visible_set: Dictionary[Vector2i, bool] = {}
## Relevés de la dernière mise à jour : cases en vue occupées, lignes de frontière de chacune (néon),
## cases du joueur affamées, avec une armée prête, ou prêtes à passer en ville.
var _visible_cells: Array[Vector2i] = []
var _frontiers: Dictionary[Vector2i, Array] = {}
var _starving_cells: Array[Vector2i] = []
var _army_cells: Array[Vector2i] = []
var _upgrade_cells: Array[Vector2i] = []


## Crée les calques (appelé une fois, au premier monde affiché).
func _build_layers() -> void:
	for root in [_terrain_root, _glow_root, _decor_root]:
		add_child(root)
	_overlay = OverlayPainter.new(_paint_overlay)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for row in world.rows:
		for column in world.columns:
			var cell := Vector2i(column, row)
			_terrain_painters[cell] = _add_painter(_terrain_root, _paint_terrain.bind(cell))
			_glow_painters[cell] = _add_painter(_glow_root, _paint_glow.bind(cell))
			_decor_painters[cell] = _add_painter(_decor_root, _paint_decor.bind(cell))
			var pairs := []
			for neighbor in world.neighbors(cell):
				var angle := rad_to_deg(HexUtils.neighbor_direction(cell, neighbor).angle())
				pairs.append([neighbor, posmod(roundi(angle / 60.0), 6)])
			_neighbor_sides[cell] = pairs


## Calque d'une case dans `root`, dessiné par `callback(calque)`.
func _add_painter(root: Node2D, callback: Callable) -> Painter:
	var painter := Painter.new(callback)
	root.add_child(painter)
	return painter


func _mark_dirty() -> void:
	_cells_dirty = true


## Met à jour les relevés de la carte et redessine les calques des cases dont l'aspect a changé.
func _refresh_cells() -> void:
	_cells_dirty = false
	var now := Time.get_ticks_msec() / 1000.0
	var first_draw := not _drawn_once
	_drawn_once = true
	var width := border_width * FRONTIER_WIDTH
	_visible_cells.clear()
	_starving_cells.clear()
	_army_cells.clear()
	_upgrade_cells.clear()
	# Cases que le joueur voit : les siennes et leurs voisines.
	_visible_set.clear()
	for cell in world.cells_of(viewer_id):
		_visible_set[cell] = true
		for neighbor in world.neighbors(cell):
			_visible_set[neighbor] = true
	for row in world.rows:
		for column in world.columns:
			var cell := Vector2i(column, row)
			var explored := world.is_explored(viewer_id, cell)
			if explored and not _explored_cells.has(cell):
				_explored_cells[cell] = true
				if not first_draw:
					_reveals[cell] = now
			var cell_owner := world.owner(cell)
			var seen := cell_owner != World.NO_PLAYER and _visible_set.has(cell)
			var terrain_signature := [_hex_radius, _first_center, explored, seen]
			var decor_signature := [_hex_radius, _first_center, seen]
			if seen:
				var cell_population := world.population(cell)
				var residents := cell_population.residents()
				terrain_signature.append_array([cell_owner, roundi(residents / world.terrain_capacity(cell) * 40.0),
						Icons.settlement_tier(world, cell), ceili(6.0 * residents / world.capacity(cell) - 1e-6)])
				# La fortification n'est redessinée que si son aspect change (pierre ou bois, hauteur au pixel près).
				var garrison := cell_population.whole("fighter")
				var wall := [garrison >= WALL_STONE_GARRISON, roundi(_wall_height(garrison))] if garrison > 0 else []
				decor_signature.append_array([cell_owner, _frontier_sides(cell), wall])
				_visible_cells.append(cell)
				if cell_owner == viewer_id:
					if world.is_starving(cell):
						_starving_cells.append(cell)
					if cell_population.army > 0:
						_army_cells.append(cell)
					if world.can_found_city(viewer_id, cell):
						_upgrade_cells.append(cell)
			if terrain_signature != _terrain_signatures.get(cell, []):
				_terrain_signatures[cell] = terrain_signature
				_terrain_painters[cell].queue_redraw()
			if decor_signature != _decor_signatures.get(cell, []):
				_decor_signatures[cell] = decor_signature
				if seen:
					_frontiers[cell] = _frontier_lines(cell, width * 0.5)
				else:
					_frontiers.erase(cell)
				_glow_painters[cell].queue_redraw()
				_decor_painters[cell].queue_redraw()


## Calque de terrain de `cell` : tuile (ou brouillard), voile, champs et agglomération, puis sa bordure.
func _paint_terrain(canvas: CanvasItem, cell: Vector2i) -> void:
	_canvas = canvas
	CellBackground.draw(_canvas, world, viewer_id, cell, cell_center(cell), _hex_radius)
	var points := HexUtils.hex_points(cell_center(cell), _hex_radius)
	_canvas.draw_polyline(HexUtils.closed(points), border_color, border_width, true)


## Halo au néon de la frontière de `cell`, à son intensité maximale (la pulsation passe par la
## transparence du calque entier, voir _process).
func _paint_glow(canvas: CanvasItem, cell: Vector2i) -> void:
	if not _frontiers.has(cell):
		return
	_canvas = canvas
	_draw_neon_glow(_frontiers[cell], CellBackground.PLAYER_COLORS[world.owner(cell)], border_width * FRONTIER_WIDTH, 1.0)


## Frontière au néon de `cell` et, si elle a une garnison, sa palissade ou son mur.
func _paint_decor(canvas: CanvasItem, cell: Vector2i) -> void:
	if not _frontiers.has(cell):
		return
	_canvas = canvas
	_draw_neon_line(_frontiers[cell], CellBackground.PLAYER_COLORS[world.owner(cell)], border_width * FRONTIER_WIDTH)
	var garrison := world.population(cell).whole("fighter")
	if garrison > 0:
		for line in _frontier_lines(cell, _hex_radius * WALL_INSET):
			_draw_wall(line, garrison)


## Surcouche animée, redessinée à chaque image.
func _paint_overlay(canvas: CanvasItem) -> void:
	if world == null:
		return
	_canvas = canvas
	var now := Time.get_ticks_msec() / 1000.0
	for cell in _reveals.keys():
		_draw_reveal(cell, now)
	var frontiers := []
	for cell in _visible_cells:
		frontiers.append(_frontiers.get(cell, []))
	_draw_frontier_waves(_visible_cells, frontiers, border_width * FRONTIER_WIDTH, now)
	# Population totale de chaque case en vue (celles du joueur comme les ennemies), sous son
	# agglomération (voir CellBackground).
	var font := get_theme_default_font()
	var font_size := maxi(10, int(_hex_radius * 0.3))
	for cell in _visible_cells:
		if world.population(cell) != null and not world.is_at_war(cell):
			PopulationText.draw_icon_row(_canvas, font, [[null,
					NumberFormat.compact(world.population(cell).whole_total()), Color.WHITE]],
					cell_center(cell) + Vector2(0.0, _hex_radius * POPULATION_TEXT_OFFSET), font_size)
	# Sélection en retrait, pour laisser voir la couleur du joueur autour.
	if selected_cell != NO_CELL:
		_draw_outline(selected_cell, selected_border_color, border_width * 2.0)
	# Pièce en baisse en haut des cases du joueur dont la population est reconvertie faute d'or.
	for cell in world.bankrupt_cells:
		if world.owner(cell) != viewer_id:
			continue
		var icon_size := Vector2.ONE * _hex_radius * 0.7
		var icon_center := cell_center(cell) - Vector2(0.0, _hex_radius * 0.5)
		_canvas.draw_texture_rect(Icons.GOLD_DOWN, Rect2(icon_center - icon_size / 2.0, icon_size), false)
	# Alerte en bas des cases du joueur touchées par la famine.
	for cell in _starving_cells:
		var icon_size := Vector2.ONE * _hex_radius * 0.7
		var icon_center := cell_center(cell) + Vector2(0.0, _hex_radius * 0.5)
		_canvas.draw_texture_rect(Icons.STARVATION, Rect2(icon_center - icon_size / 2.0, icon_size), false)
	# Petit soldat qui marche sur place en haut à gauche des cases du joueur où une armée est prête à
	# partir (celles des ennemis restent cachées : on n'en voit que la population totale).
	var march_frame := int(now * CONVOY_FPS * 0.5) % Icons.ARMY_MOVE.size()
	for cell in _army_cells:
		var soldier_size := Vector2.ONE * _hex_radius * 0.5
		var soldier_center := cell_center(cell) + Vector2(-_hex_radius * 0.45, -_hex_radius * 0.3)
		_canvas.draw_circle(soldier_center, soldier_size.x * 0.5, Color(1.0, 0.97, 0.88, 0.85))
		_canvas.draw_arc(soldier_center, soldier_size.x * 0.5, 0.0, TAU, 24, PopulationText.OUTLINE_COLOR,
				maxf(1.5, _hex_radius * 0.04), true)
		_canvas.draw_texture_rect(Icons.ARMY_MOVE[march_frame], Rect2(soldier_center - soldier_size / 2.0, soldier_size),
				false)
	# Flèche qui sautille sur les villages pleins du joueur, qui peuvent passer en ville.
	for cell in _upgrade_cells:
		_draw_upgrade_arrow(cell_center(cell) + Vector2(_hex_radius * 0.45, -_hex_radius * 0.3), now)
	_draw_battles()
	# Cibles de la case sélectionnée : chariot où ses colons peuvent partir ; pour sa troupe, flèche de
	# déplacement vers une case du joueur et épée vers une case ennemie à attaquer (côte à côte quand
	# la case accepte colons et troupe).
	var settler_targets := world.colonization_targets(viewer_id, selected_cell)
	var army_targets := world.army_targets(viewer_id, selected_cell)
	for cell in settler_targets:
		_draw_target(cell, Icons.SETTLER, -1.0 if cell in army_targets else 0.0)
	for cell in army_targets:
		var icon := Icons.MARCH if world.owner(cell) == viewer_id else Icons.SWORD
		_draw_target(cell, icon, 1.0 if cell in settler_targets else 0.0)
	_draw_food_flows(now)
	_draw_convoys()
	_effects.draw(_canvas, font, cell_center, _hex_radius)


## Annonce, en grand au centre de la carte, qu'un joueur ennemi vient d'être détruit (`text`), avec
## feux d'artifice et son portrait (`portrait`, ou le trophée).
func show_destroyed(text: String, portrait: Texture2D = null) -> void:
	_effects.add(MapEffects.Kind.DESTROYED, NO_CELL, Color.WHITE, text, portrait)


## « +`amount` » qui s'envole de `cell` (clic sur Boost).
func show_boost(cell: Vector2i, amount: int) -> void:
	_effects.add(MapEffects.Kind.BOOST, cell, Color.WHITE, "+%d" % amount)


## Effets quand une case change de main : victoire si le joueur la conquiert, défaite s'il la perd par la
## guerre, flash sur toute case en vue qui change de main par la guerre, et terre conquise quand il
## colonise une case.
func _on_owner_changed(cell: Vector2i, previous_owner: int, new_owner: int, by_war: bool) -> void:
	# Le territoire du joueur s'agrandit : une onde parcourt sa frontière depuis la nouvelle case.
	if new_owner == viewer_id:
		_frontier_waves.append([cell, Time.get_ticks_msec() / 1000.0])
	if not by_war:
		if new_owner == viewer_id:
			_effects.add(MapEffects.Kind.COLONY, cell, CellBackground.PLAYER_COLORS[new_owner])
		return
	var involved := viewer_id in [previous_owner, new_owner]
	if involved or world.is_visible(viewer_id, cell):
		var color: Color = CellBackground.PLAYER_COLORS[new_owner] if new_owner != World.NO_PLAYER else BattleView.OUTLINE_COLOR
		_effects.add(MapEffects.Kind.FLASH, cell, color)
	if new_owner == viewer_id:
		_effects.add(MapEffects.Kind.VICTORY, cell)
	elif previous_owner == viewer_id:
		_effects.add(MapEffects.Kind.DEFEAT, cell)


## Ville fondée par le joueur : feux d'artifice et picto de la ville à sa couleur.
func _on_city_founded(cell: Vector2i) -> void:
	if world.owner(cell) == viewer_id:
		_effects.add(MapEffects.Kind.CITY, cell, CellBackground.PLAYER_COLORS[viewer_id])


## Ville du joueur redevenue village : picto du village à sa couleur sur une pluie de braises, avec
## « VILLE AFFAMÉE » si c'est la famine.
func _on_city_lost(cell: Vector2i, by_famine: bool) -> void:
	if world.owner(cell) == viewer_id:
		_effects.add(MapEffects.Kind.VILLAGE, cell, CellBackground.PLAYER_COLORS[viewer_id],
				Locale.text("EFFECT_STARVING_CITY") if by_famine else "")


## Ondes sur la frontière du joueur : un front lumineux, cercle qui grandit depuis la case d'où part
## l'onde, illumine au passage chaque bout de sa frontière (blanc sur un halo à sa couleur), puis
## s'estompe à mesure qu'il s'éloigne. `cells` et `frontiers` : cases en vue et leurs lignes de frontière.
func _draw_frontier_waves(cells: Array[Vector2i], frontiers: Array, width: float, now: float) -> void:
	# Distance maximale à parcourir : la diagonale de la carte.
	var reach := Vector2(world.columns * sqrt(3.0), world.rows * 1.5).length() * _hex_radius
	var color: Color = CellBackground.PLAYER_COLORS[viewer_id]
	var band := WAVE_WIDTH * _hex_radius
	_frontier_waves = _frontier_waves.filter(func(wave: Array) -> bool:
		return (now - wave[1]) * WAVE_SPEED * _hex_radius < reach + band)
	for wave in _frontier_waves:
		var origin := cell_center(wave[0])
		var front: float = (now - wave[1]) * WAVE_SPEED * _hex_radius
		var strength := 1.0 - front / (reach + band)
		for i in cells.size():
			if world.owner(cells[i]) != viewer_id:
				continue
			for line in frontiers[i]:
				for k in line.size() - 1:
					for step in WAVE_STEPS:
						var a: Vector2 = line[k].lerp(line[k + 1], float(step) / WAVE_STEPS)
						var b: Vector2 = line[k].lerp(line[k + 1], float(step + 1) / WAVE_STEPS)
						var glow := exp(-pow((origin.distance_to((a + b) / 2.0) - front) / band, 2.0)) * strength
						if glow < 0.03:
							continue
						_canvas.draw_line(a, b, Color(color.lerp(Color.WHITE, 0.3), glow * 0.6), width * 4.0, true)
						_canvas.draw_line(a, b, Color(1.0, 1.0, 1.0, glow), width * 1.2, true)


## Fondu du brouillard sur `cell` si elle vient d'être découverte, avec un léger éclat blanc au milieu.
func _draw_reveal(cell: Vector2i, now: float) -> void:
	if not _reveals.has(cell):
		return
	var t := (now - _reveals[cell]) / REVEAL_TIME
	if t >= 1.0:
		_reveals.erase(cell)
		return
	CellBackground.draw_fog(_canvas, cell_center(cell), _hex_radius, 1.0 - t)
	_canvas.draw_colored_polygon(HexUtils.hex_points(cell_center(cell), _hex_radius), Color(1.0, 1.0, 1.0, 0.25 * sin(t * PI)))


## Batailles en vue : animation de BattleView (contour, explosions, épées sur leur halo) en haut de la
## case, et en dessous les belligérants, le défenseur sur une ligne et les attaquants sur la suivante.
func _draw_battles() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var font := get_theme_default_font()
	var font_size := maxi(9, int(_hex_radius * 0.24))
	for cell in world.battle_cells():
		if not world.is_visible(viewer_id, cell):
			continue
		var center := cell_center(cell)
		BattleView.draw(_canvas, cell, center, _hex_radius, center - Vector2(0.0, _hex_radius * 0.35), _hex_radius * 0.7,
				time)
		var rows := BattleView.belligerents(world, viewer_id, cell)
		for i in rows.size():
			if not rows[i].is_empty():
				PopulationText.draw_icon_row(_canvas, font, rows[i], center + Vector2(0.0, _hex_radius * (0.2 + 0.28 * i)),
						font_size)


## Colons et troupes en route dont la case de départ ou d'arrivée est en vue : un petit chariot ou un
## petit soldat glisse d'un centre de case à l'autre pendant le trajet, apparaît et disparaît en fondu,
## et s'anime (roues qui tournent, soldat qui marche).
func _draw_convoys() -> void:
	var frame := int(Time.get_ticks_msec() / 1000.0 * CONVOY_FPS) % Icons.SETTLER_MOVE.size()
	var icon_size := Vector2.ONE * _hex_radius * CONVOY_SIZE
	for convoy in world.convoys():
		if not (world.is_visible(viewer_id, convoy.from_cell) or world.is_visible(viewer_id, convoy.to_cell)):
			continue
		var progress := clampf((convoy.elapsed + convoy_time_offset) / world.rules.travel_time, 0.0, 1.0)
		var alpha := clampf(minf(progress, 1.0 - progress) / CONVOY_FADE, 0.0, 1.0)
		var center := cell_center(convoy.from_cell).lerp(cell_center(convoy.to_cell), progress)
		var frames := Icons.ARMY_MOVE if convoy.is_army else Icons.SETTLER_MOVE
		var rect := Rect2(center - icon_size / 2.0, icon_size)
		# Tourné vers sa destination : retourné (largeur négative) quand il part vers la gauche.
		if cell_center(convoy.to_cell).x < cell_center(convoy.from_cell).x:
			rect = Rect2(rect.position + Vector2(icon_size.x, 0.0), Vector2(-icon_size.x, icon_size.y))
		_canvas.draw_texture_rect(frames[frame], rect, false, Color(1.0, 1.0, 1.0, alpha))


## Icône de cible sur un disque sombre au centre de `cell`, décalée d'un demi-rayon par `shift` (-1, 0 ou 1).
func _draw_target(cell: Vector2i, icon: Texture2D, shift: float) -> void:
	var icon_size := Vector2.ONE * _hex_radius * (0.7 if shift != 0.0 else 1.0)
	var icon_center := cell_center(cell) + Vector2(shift * _hex_radius * 0.4, 0.0)
	_canvas.draw_circle(icon_center, icon_size.x * 0.6, SETTLER_TARGET_BACKGROUND)
	_canvas.draw_texture_rect(icon, Rect2(icon_center - icon_size / 2.0, icon_size), false)


## Côtés de `cell` qui sont des frontières de son propriétaire : ceux qui donnent sur une case qui n'est
## pas à lui, sur le bord de la carte, ou sur une case que le joueur ne voit pas (brouillard de guerre :
## rien n'y est révélé). Le côté i, entre les sommets i et i + 1 de HexUtils.hex_points, fait face à la
## direction 60° × i.
func _frontier_sides(cell: Vector2i) -> Array[bool]:
	var sides: Array[bool] = [true, true, true, true, true, true]
	var cell_owner := world.owner(cell)
	for pair in _neighbor_sides[cell]:
		if world.owner(pair[0]) == cell_owner and _visible_set.has(pair[0]):
			sides[pair[1]] = false
	return sides


## Lignes de frontière de `cell` (voir _frontier_sides), en retrait de `inset` vers l'intérieur de la
## case, pour que deux frontières voisines restent visibles côte à côte. Chaque suite de côtés frontières
## consécutifs forme une ligne, prolongée à ses bouts jusqu'aux côtés intérieurs pour se raccorder sans
## cassure à la frontière des cases voisines du même joueur.
func _frontier_lines(cell: Vector2i, inset: float) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var sides := _frontier_sides(cell)
	if not sides.has(true):
		return lines
	var center := cell_center(cell)
	if not sides.has(false):
		lines.append(HexUtils.closed(HexUtils.hex_points(center, _hex_radius - inset / cos(PI / 6.0))))
		return lines
	for start in 6:
		if not sides[start] or sides[posmod(start - 1, 6)]:
			continue
		var line := PackedVector2Array([_side_corner(center, posmod(start - 1, 6), false, true, inset)])
		var side := start
		while sides[side]:
			var next := (side + 1) % 6
			line.append(_side_corner(center, side, true, sides[next], inset))
			side = next
		lines.append(line)
	return lines


## Coin entre le côté `side` et le suivant, chacun décalé de `inset` vers l'intérieur si c'est une
## frontière (`shifted`, `next_shifted`) : intersection des deux côtés ainsi placés.
func _side_corner(center: Vector2, side: int, shifted: bool, next_shifted: bool, inset: float) -> Vector2:
	var corners := HexUtils.hex_points(center, _hex_radius)
	var lines := []
	for i in [side, (side + 1) % 6]:
		var a := corners[i]
		var b := corners[(i + 1) % 6]
		var offset := (center - (a + b) / 2.0).normalized() * inset
		var move := shifted if i == side else next_shifted
		lines.append([a + offset if move else a, b - a])
	var hit: Variant = Geometry2D.line_intersects_line(lines[0][0], lines[0][1], lines[1][0], lines[1][1])
	return hit if hit != null else corners[(side + 1) % 6]


## Halo lumineux d'une frontière au néon : traits larges et transparents, qui s'élargissent et
## s'éclairent au rythme de `pulse` (0 à 1).
func _draw_neon_glow(lines: Array[PackedVector2Array], color: Color, width: float, pulse: float) -> void:
	for layer in range(NEON_GLOW_LAYERS, 0, -1):
		var glow := Color(color, 0.06 + 0.07 * pulse)
		for line in lines:
			_canvas.draw_polyline(line, glow, width * (1.0 + layer * 1.2) * (0.9 + 0.3 * pulse), true)


## Trait d'une frontière au néon : la couleur du joueur, et un cœur plus clair au milieu. Des disques
## arrondissent les coins.
func _draw_neon_line(lines: Array[PackedVector2Array], color: Color, width: float) -> void:
	var core := color.lerp(Color.WHITE, 0.55)
	for line in lines:
		_canvas.draw_polyline(line, color, width, true)
		for point in line:
			_canvas.draw_circle(point, width / 2.0, color)
		_canvas.draw_polyline(line, core, width * 0.4, true)
		for point in line:
			_canvas.draw_circle(point, width * 0.2, core)


func _draw_outline(cell: Vector2i, color: Color, inset: float = 0.0, width: float = border_width * 2.0) -> void:
	var points := HexUtils.hex_points(cell_center(cell), _hex_radius - inset)
	_canvas.draw_polyline(HexUtils.closed(points), color, width, true)


func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	# Clic droit : plus aucune case sélectionnée.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_cell != NO_CELL:
			selected_cell = NO_CELL
			cell_selected.emit(NO_CELL)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_at(event.position)
		var is_target := cell in world.colonization_targets(viewer_id, selected_cell) \
				or cell in world.army_targets(viewer_id, selected_cell)
		if is_target:
			units_sent.emit(cell)
			accept_event()
		elif cell != NO_CELL:
			selected_cell = cell
			cell_selected.emit(cell)
			accept_event()


## Petite flèche « up » dorée centrée sur `center`, cernée de sombre, qui sautille et luit doucement :
## le village peut passer en ville.
func _draw_upgrade_arrow(center: Vector2, now: float) -> void:
	const COLOR := Color("ffd84a")
	var size := _hex_radius * 0.28
	var bounce := absf(sin(now * TAU * 0.8))
	center.y -= bounce * size * 0.35
	var points := PackedVector2Array()
	for point in [Vector2(0.0, -0.5), Vector2(0.5, 0.05), Vector2(0.2, 0.05), Vector2(0.2, 0.5),
			Vector2(-0.2, 0.5), Vector2(-0.2, 0.05), Vector2(-0.5, 0.05)]:
		points.append(center + point * size)
	_canvas.draw_circle(center, size * (0.75 + 0.1 * bounce), Color(COLOR, 0.18 + 0.12 * bounce))
	_canvas.draw_colored_polygon(points, COLOR.lerp(Color.WHITE, 0.3 * bounce))
	points.append(points[0])
	_canvas.draw_polyline(points, PopulationText.OUTLINE_COLOR, maxf(1.5, size * 0.1), true)


## Food que s'envoient les cases du joueur : un sac de grain par flux, qui glisse en boucle de la case
## qui exporte vers celle qui reçoit (voir World.food_exports), plus gros quand le flux est fort. Chaque
## flux a son propre décalage dans le temps, pour que les sacs ne partent pas tous ensemble. Seuls les
## flux du joueur sont montrés (rien n'est révélé de l'économie ennemie).
func _draw_food_flows(now: float) -> void:
	for cell in world.cells_of(viewer_id):
		var exports := world.food_exports(cell)
		for neighbor in exports:
			var amount: float = exports[neighbor]
			var offset := float(absi(hash([cell, neighbor])) % 1000) / 1000.0
			var progress := fmod(now / FOOD_FLOW_PERIOD + offset, 1.0)
			var alpha := clampf(minf(progress, 1.0 - progress) / CONVOY_FADE, 0.0, 1.0)
			var weight := clampf(amount / FOOD_FLOW_FULL, 0.0, 1.0)
			var icon_size := Vector2.ONE * _hex_radius * lerpf(FOOD_FLOW_SIZE[0], FOOD_FLOW_SIZE[1], weight)
			# Petit cahot, comme porté à dos d'homme.
			var center := cell_center(cell).lerp(cell_center(neighbor), progress) \
					- Vector2(0.0, absf(sin(progress * TAU * 3.0)) * icon_size.y * 0.15)
			_canvas.draw_texture_rect(Icons.GRAIN_SACK, Rect2(center - icon_size / 2.0, icon_size), false,
					Color(1.0, 1.0, 1.0, alpha))


## Fortification le long de `line` (son pied), à la hauteur que donne la garnison `garrison` (voir
## WALL_STONE_GARRISON) : mur de pierre crénelé à partir de WALL_STONE_GARRISON fighters, sinon palissade
## de pieux appointés. Tout se dresse vers le haut de l'écran (vue de trois quarts), éclairé à gauche.
func _draw_wall(line: PackedVector2Array, garrison: int) -> void:
	var outline_width := maxf(1.0, _hex_radius * 0.02)
	var stone := garrison >= WALL_STONE_GARRISON
	var height := _wall_height(garrison)
	if stone:
		_draw_stone_face(line, height, outline_width)
	else:
		_canvas.draw_polyline(line, WALL_OUTLINE, outline_width * 2.5, true)
	var spacing := _hex_radius * STAKE_SPACING
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var count := maxi(1, roundi(a.distance_to(b) / spacing))
		for k in count:
			var spot := a.lerp(b, (k + 0.5) / count)
			if stone:
				_draw_merlon(spot - Vector2(0.0, height))
			else:
				_draw_stake(spot, height)


## Hauteur (px) de la fortification d'une garnison de `garrison` fighters (voir WALL_STONE_GARRISON).
func _wall_height(garrison: int) -> float:
	if garrison >= WALL_STONE_GARRISON:
		var stone_rise := log(float(garrison) / WALL_STONE_GARRISON) / log(float(WALL_FULL_STONE) / WALL_STONE_GARRISON)
		return _hex_radius * lerpf(STONE_HEIGHT[0], STONE_HEIGHT[1], clampf(stone_rise, 0.0, 1.0))
	var rise := clampf(log(float(maxi(garrison, 1))) / log(float(WALL_STONE_GARRISON)), 0.0, 1.0)
	return _hex_radius * lerpf(STAKE_HEIGHT[0], STAKE_HEIGHT[1], rise)


## Mur de pierre de `height` pixels dressé sur `line` : face sombre striée d'assises de pierre, puis le
## chemin de ronde clair à son sommet.
func _draw_stone_face(line: PackedVector2Array, height: float, outline_width: float) -> void:
	var lift := Vector2(0.0, -height)
	var course := _hex_radius * STONE_WIDTH * 0.5
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var face := PackedVector2Array([a, b, b + lift, a + lift])
		_canvas.draw_colored_polygon(face, STONE_COLORS[0])
		# Assises : une ligne de joint toutes les `course` pixels de hauteur.
		var rows := floori(height / course)
		for row in range(1, rows + 1):
			var up := Vector2(0.0, -row * course)
			_canvas.draw_line(a + up, b + up, WALL_OUTLINE.lerp(STONE_COLORS[0], 0.5), maxf(1.0, outline_width * 0.6), true)
		face.append(face[0])
		_canvas.draw_polyline(face, WALL_OUTLINE, outline_width, true)
	var top := PackedVector2Array()
	for point in line:
		top.append(point + lift)
	var walk := _hex_radius * STONE_WIDTH * 0.6
	_canvas.draw_polyline(top, WALL_OUTLINE, walk + outline_width * 2.0, true)
	_canvas.draw_polyline(top, STONE_COLORS[1], walk, true)


## Pieu de palissade de `h` pixels planté en `foot` : corps de bois éclairé à gauche, pointe en haut,
## cerné de sombre.
func _draw_stake(foot: Vector2, h: float) -> void:
	var w := _hex_radius * STAKE_SPACING * 0.7
	var body := PackedVector2Array([foot + Vector2(-w / 2.0, 0.0), foot + Vector2(w / 2.0, 0.0),
			foot + Vector2(w / 2.0, -h), foot + Vector2(0.0, -h - w * 0.7), foot + Vector2(-w / 2.0, -h)])
	_canvas.draw_colored_polygon(body, WOOD_COLORS[1])
	_canvas.draw_colored_polygon(PackedVector2Array([foot + Vector2(-w / 2.0, 0.0), foot + Vector2(-w / 2.0 + w * 0.35, 0.0),
			foot + Vector2(-w / 2.0 + w * 0.35, -h - w * 0.45), foot + Vector2(-w / 2.0, -h)]), WOOD_COLORS[2])
	body.append(body[0])
	_canvas.draw_polyline(body, WALL_OUTLINE, maxf(1.0, _hex_radius * 0.015), true)


## Merlon posé sur le chemin de ronde en `spot` (le sommet du mur) : bloc éclairé à gauche, cerné de sombre.
func _draw_merlon(spot: Vector2) -> void:
	var s := _hex_radius * STONE_WIDTH * 0.7
	var block := Rect2(spot + Vector2(-s / 2.0, -s), Vector2(s, s))
	_canvas.draw_rect(block, STONE_COLORS[1])
	_canvas.draw_rect(Rect2(block.position, Vector2(s * 0.35, s)), STONE_COLORS[2])
	_canvas.draw_rect(Rect2(block.position + Vector2(0.0, s * 0.75), Vector2(s, s * 0.25)), STONE_COLORS[0])
	_canvas.draw_rect(block, WALL_OUTLINE, false, maxf(1.0, _hex_radius * 0.015))
