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
## Chariot des colons en route : taille (en rayon de case), part du trajet en fondu au départ comme à
## l'arrivée, et cadence de son animation (images par seconde).
const CONVOY_SIZE := 0.5
const CONVOY_FADE := 0.25
const CONVOY_FPS := 8.0
## Frontières des joueurs, au néon : largeur du trait (en multiple de border_width), couches du halo
## lumineux autour, et pulsation de ce halo (par seconde).
const FRONTIER_WIDTH := 2.0
const NEON_GLOW_LAYERS := 4
const NEON_PULSE_RATE := 0.6
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
## Monde affiché ; la carte se redessine à chacun de ses changements.
var world: World:
	set(value):
		world = value
		world.changed.connect(queue_redraw)
		world.owner_changed.connect(_on_owner_changed)
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
	# Frontières au néon qui pulsent, colons et troupes en route, batailles : animés à chaque image.
	if world != null:
		queue_redraw()


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
	var now := Time.get_ticks_msec() / 1000.0
	# Au premier dessin, ce qui est déjà connu (les mers) l'est sans fondu.
	var first_draw := not _drawn_once
	_drawn_once = true
	for row in world.rows:
		for column in world.columns:
			var cell := Vector2i(column, row)
			CellBackground.draw(self, world, viewer_id, cell, cell_center(cell), _hex_radius)
			if world.is_explored(viewer_id, cell) and not _explored_cells.has(cell):
				_explored_cells[cell] = true
				if not first_draw:
					_reveals[cell] = now
			_draw_reveal(cell, now)
			var points := HexUtils.hex_points(cell_center(cell), _hex_radius)
			draw_polyline(HexUtils.closed(points), border_color, border_width, true)
	# Frontières des joueurs (ennemis seulement s'ils sont en vue), au néon, dessinées après la grille
	# pour passer au-dessus des bordures voisines. Une case ennemie en vue affiche aussi sa population
	# totale, sans détail (sauf en guerre : voir _draw_battles).
	var font := get_theme_default_font()
	var font_size := maxi(10, int(_hex_radius * 0.3))
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * NEON_PULSE_RATE)
	var width := border_width * FRONTIER_WIDTH
	var visible_cells: Array[Vector2i] = []
	var frontiers: Array = []
	for cell in world.occupied_cells():
		if world.is_visible(viewer_id, cell):
			visible_cells.append(cell)
			frontiers.append(_frontier_lines(cell, width * 0.5))
	# Tous les halos d'abord, pour qu'aucun ne passe sur le trait d'une frontière voisine.
	for i in visible_cells.size():
		_draw_neon_glow(frontiers[i], CellBackground.PLAYER_COLORS[world.owner(visible_cells[i])], width, pulse)
	for i in visible_cells.size():
		_draw_neon_line(frontiers[i], CellBackground.PLAYER_COLORS[world.owner(visible_cells[i])], width)
	_draw_frontier_waves(visible_cells, frontiers, width, now)
	# Population totale de chaque case en vue (celles du joueur comme les ennemies), sous son
	# agglomération (voir CellBackground).
	for cell in visible_cells:
		if not world.is_at_war(cell):
			PopulationText.draw_icon_row(self, font, [[null,
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
		draw_texture_rect(Icons.GOLD_DOWN, Rect2(icon_center - icon_size / 2.0, icon_size), false)
	# Alerte en bas des cases du joueur touchées par la famine.
	for cell in world.cells_of(viewer_id):
		if world.is_starving(cell):
			var icon_size := Vector2.ONE * _hex_radius * 0.7
			var icon_center := cell_center(cell) + Vector2(0.0, _hex_radius * 0.5)
			draw_texture_rect(Icons.STARVATION, Rect2(icon_center - icon_size / 2.0, icon_size), false)
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
	_draw_convoys()
	_effects.draw(self, font, cell_center, _hex_radius)


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
						draw_line(a, b, Color(color.lerp(Color.WHITE, 0.3), glow * 0.6), width * 4.0, true)
						draw_line(a, b, Color(1.0, 1.0, 1.0, glow), width * 1.2, true)


## Fondu du brouillard sur `cell` si elle vient d'être découverte, avec un léger éclat blanc au milieu.
func _draw_reveal(cell: Vector2i, now: float) -> void:
	if not _reveals.has(cell):
		return
	var t := (now - _reveals[cell]) / REVEAL_TIME
	if t >= 1.0:
		_reveals.erase(cell)
		return
	CellBackground.draw_fog(self, cell_center(cell), _hex_radius, 1.0 - t)
	draw_colored_polygon(HexUtils.hex_points(cell_center(cell), _hex_radius), Color(1.0, 1.0, 1.0, 0.25 * sin(t * PI)))


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
		BattleView.draw(self, cell, center, _hex_radius, center - Vector2(0.0, _hex_radius * 0.35), _hex_radius * 0.7,
				time)
		var rows := BattleView.belligerents(world, viewer_id, cell)
		for i in rows.size():
			if not rows[i].is_empty():
				PopulationText.draw_icon_row(self, font, rows[i], center + Vector2(0.0, _hex_radius * (0.2 + 0.28 * i)),
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
		draw_texture_rect(frames[frame], rect, false, Color(1.0, 1.0, 1.0, alpha))


## Icône de cible sur un disque sombre au centre de `cell`, décalée d'un demi-rayon par `shift` (-1, 0 ou 1).
func _draw_target(cell: Vector2i, icon: Texture2D, shift: float) -> void:
	var icon_size := Vector2.ONE * _hex_radius * (0.7 if shift != 0.0 else 1.0)
	var icon_center := cell_center(cell) + Vector2(shift * _hex_radius * 0.4, 0.0)
	draw_circle(icon_center, icon_size.x * 0.6, SETTLER_TARGET_BACKGROUND)
	draw_texture_rect(icon, Rect2(icon_center - icon_size / 2.0, icon_size), false)


## Côtés de `cell` qui sont des frontières de son propriétaire : ceux qui donnent sur une case qui n'est
## pas à lui, sur le bord de la carte, ou sur une case que le joueur ne voit pas (brouillard de guerre :
## rien n'y est révélé). Le côté i, entre les sommets i et i + 1 de HexUtils.hex_points, fait face à la
## direction 60° × i.
func _frontier_sides(cell: Vector2i) -> Array[bool]:
	var sides: Array[bool] = [true, true, true, true, true, true]
	for neighbor in world.neighbors(cell):
		if world.owner(neighbor) == world.owner(cell) and world.is_visible(viewer_id, neighbor):
			var angle := rad_to_deg(HexUtils.neighbor_direction(cell, neighbor).angle())
			sides[posmod(roundi(angle / 60.0), 6)] = false
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
			draw_polyline(line, glow, width * (1.0 + layer * 1.2) * (0.9 + 0.3 * pulse), true)


## Trait d'une frontière au néon : la couleur du joueur, et un cœur plus clair au milieu. Des disques
## arrondissent les coins.
func _draw_neon_line(lines: Array[PackedVector2Array], color: Color, width: float) -> void:
	var core := color.lerp(Color.WHITE, 0.55)
	for line in lines:
		draw_polyline(line, color, width, true)
		for point in line:
			draw_circle(point, width / 2.0, color)
		draw_polyline(line, core, width * 0.4, true)
		for point in line:
			draw_circle(point, width * 0.2, core)


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
