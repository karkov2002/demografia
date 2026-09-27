class_name HexMap
extends Control
## Carte du monde : grille d'hexagones cliquables, redimensionnée pour tenir entièrement dans le contrôle.
## Disposition « odd-r » : hexagones pointe en haut, rangées impaires décalées d'une demi-case.

## Émis au clic sur une case (indices à partir de 0).
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

## Joueur dont on montre la vue (brouillard de guerre) et qu'on fait agir.
var viewer_id: int = 0
## Monde affiché ; la carte se redessine à chacun de ses changements.
var world: World:
	set(value):
		world = value
		world.changed.connect(queue_redraw)
		_update_layout()
## Case sélectionnée, ou NO_CELL.
var selected_cell: Vector2i = NO_CELL

var _hex_radius: float = 0.0
var _first_center: Vector2 = Vector2.ZERO  # centre de la case (0, 0)


func _ready() -> void:
	# Tuiles en pixel art : pas de lissage à l'agrandissement.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_update_layout)


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
	queue_redraw()


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


func _draw() -> void:
	if world == null:
		return
	for row in world.rows:
		for column in world.columns:
			var cell := Vector2i(column, row)
			CellBackground.draw(self, world, viewer_id, cell, cell_center(cell), _hex_radius)
			var points := HexUtils.hex_points(cell_center(cell), _hex_radius)
			draw_polyline(HexUtils.closed(points), border_color, border_width, true)
	# Contours aux couleurs des joueurs (ennemis seulement s'ils sont en vue, en plus épais pour se
	# détacher de la grille), dessinés après la grille pour passer au-dessus des bordures voisines.
	# Une case ennemie en vue affiche aussi sa population totale, sans détail.
	var font := get_theme_default_font()
	var font_size := maxi(10, int(_hex_radius * 0.3))
	for cell in world.occupied_cells():
		if not world.is_visible(viewer_id, cell):
			continue
		var owner := world.owner(cell)
		if owner == viewer_id:
			_draw_outline(cell, CellBackground.PLAYER_COLORS[owner])
		else:
			_draw_outline(cell, CellBackground.PLAYER_COLORS[owner], border_width * 1.5, border_width * 4.0)
			PopulationText.draw_icon_row(self, font, [[Icons.POPULATION,
					NumberFormat.compact(world.population(cell).whole_total()), Color.WHITE]],
					cell_center(cell) + Vector2(0.0, _hex_radius * 0.25), font_size)
	# Sélection en retrait, pour laisser voir la couleur du joueur autour.
	if selected_cell != NO_CELL:
		_draw_outline(selected_cell, selected_border_color, border_width * 2.0)
	# Pièce en baisse en haut des cases du joueur dont la population est reconvertie faute d'or.
	for cell in world.bankrupt_cells:
		if world.owner(cell) != viewer_id:
			continue
		var icon_size := Vector2.ONE * _hex_radius * 0.7
		var icon_center := cell_center(cell) - Vector2(0.0, _hex_radius * 0.5)
		draw_texture_rect(Icons.GOLD_DOWN, Rect2(icon_center - icon_size / 2.0, icon_size), false)
	# Alerte en bas des cases du joueur touchées par la famine.
	for cell in world.cells_of(viewer_id):
		if world.is_starving(cell):
			var icon_size := Vector2.ONE * _hex_radius * 0.7
			var icon_center := cell_center(cell) + Vector2(0.0, _hex_radius * 0.5)
			draw_texture_rect(Icons.STARVATION, Rect2(icon_center - icon_size / 2.0, icon_size), false)
	# Épées croisées sur les batailles en vue.
	for cell in world.battle_cells():
		if world.is_visible(viewer_id, cell):
			var icon_size := Vector2.ONE * _hex_radius * 0.8
			var icon_center := cell_center(cell) - Vector2(0.0, _hex_radius * 0.4)
			draw_texture_rect(Icons.BATTLE, Rect2(icon_center - icon_size / 2.0, icon_size), false)
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


## Icône de cible sur un disque sombre au centre de `cell`, décalée d'un demi-rayon par `shift` (-1, 0 ou 1).
func _draw_target(cell: Vector2i, icon: Texture2D, shift: float) -> void:
	var icon_size := Vector2.ONE * _hex_radius * (0.7 if shift != 0.0 else 1.0)
	var icon_center := cell_center(cell) + Vector2(shift * _hex_radius * 0.4, 0.0)
	draw_circle(icon_center, icon_size.x * 0.6, SETTLER_TARGET_BACKGROUND)
	draw_texture_rect(icon, Rect2(icon_center - icon_size / 2.0, icon_size), false)


func _draw_outline(cell: Vector2i, color: Color, inset: float = 0.0, width: float = border_width * 2.0) -> void:
	var points := HexUtils.hex_points(cell_center(cell), _hex_radius - inset)
	draw_polyline(HexUtils.closed(points), color, width, true)


func _gui_input(event: InputEvent) -> void:
	if world == null:
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
			queue_redraw()
			cell_selected.emit(cell)
			accept_event()
