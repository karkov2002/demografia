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
## leur propriétaire (pas entre deux de ses cases) : palissade de pieux, puis mur de pierre crénelé à partir de WALL_STONE_GARRISON fighters.
## Retrait (en rayons de case) vers l'intérieur de la case, et dimensions en rayons de case.
const WALL_STONE_GARRISON := 100
const WALL_INSET := 0.17
const STAKE_SPACING := 0.1
const STAKE_HEIGHT := 0.16
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
## Monde affiché ; la carte se redessine à chacun de ses changements.
var world: World:
	set(value):
		world = value
		world.changed.connect(queue_redraw)
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
	# Fortifications de chaque case en vue qui a une garnison (celles des ennemis comprises) : une case
	# sans garnison fait un trou dans la muraille de son propriétaire.
	for cell in visible_cells:
		var garrison := world.population(cell).whole("fighter")
		if garrison > 0:
			for line in _frontier_lines(cell, _hex_radius * WALL_INSET):
				_draw_wall(line, garrison >= WALL_STONE_GARRISON)
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
	# Petit soldat qui marche sur place en haut à gauche des cases du joueur où une armée est prête à
	# partir (celles des ennemis restent cachées : on n'en voit que la population totale).
	var march_frame := int(now * CONVOY_FPS * 0.5) % Icons.ARMY_MOVE.size()
	for cell in world.cells_of(viewer_id):
		if world.population(cell).army > 0:
			var soldier_size := Vector2.ONE * _hex_radius * 0.5
			var soldier_center := cell_center(cell) + Vector2(-_hex_radius * 0.45, -_hex_radius * 0.3)
			draw_circle(soldier_center, soldier_size.x * 0.5, Color(1.0, 0.97, 0.88, 0.85))
			draw_arc(soldier_center, soldier_size.x * 0.5, 0.0, TAU, 24, PopulationText.OUTLINE_COLOR,
					maxf(1.5, _hex_radius * 0.04), true)
			draw_texture_rect(Icons.ARMY_MOVE[march_frame], Rect2(soldier_center - soldier_size / 2.0, soldier_size),
					false)
	# Flèche qui sautille sur les villages pleins du joueur, qui peuvent passer en ville.
	for cell in world.cells_of(viewer_id):
		if world.can_found_city(viewer_id, cell):
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
	_effects.draw(self, font, cell_center, _hex_radius)


## Annonce, en grand au centre de la carte, qu'un joueur ennemi vient d'être détruit (`text`), avec
## feux d'artifice et trophée.
func show_destroyed(text: String) -> void:
	_effects.add(MapEffects.Kind.DESTROYED, NO_CELL, Color.WHITE, text)


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
	# Clic droit : plus aucune case sélectionnée.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_cell != NO_CELL:
			selected_cell = NO_CELL
			queue_redraw()
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
			queue_redraw()
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
	draw_circle(center, size * (0.75 + 0.1 * bounce), Color(COLOR, 0.18 + 0.12 * bounce))
	draw_colored_polygon(points, COLOR.lerp(Color.WHITE, 0.3 * bounce))
	points.append(points[0])
	draw_polyline(points, PopulationText.OUTLINE_COLOR, maxf(1.5, size * 0.1), true)


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
			draw_texture_rect(Icons.GRAIN_SACK, Rect2(center - icon_size / 2.0, icon_size), false,
					Color(1.0, 1.0, 1.0, alpha))


## Fortification le long de `line` : mur de pierre crénelé (`stone`), sinon palissade de pieux appointés,
## dressés vers le haut de l'écran (vue de trois quarts) et éclairés à gauche.
func _draw_wall(line: PackedVector2Array, stone: bool) -> void:
	var outline_width := maxf(1.0, _hex_radius * 0.02)
	if stone:
		var band := _hex_radius * STONE_WIDTH
		# Face du mur, plus sombre, sous le chemin de ronde : le mur a de la hauteur.
		var face := PackedVector2Array()
		for point in line:
			face.append(point + Vector2(0.0, band * 0.6))
		draw_polyline(face, WALL_OUTLINE, band + outline_width * 2.0, true)
		draw_polyline(face, STONE_COLORS[0], band, true)
		draw_polyline(line, WALL_OUTLINE, band + outline_width * 2.0, true)
		draw_polyline(line, STONE_COLORS[1], band, true)
	else:
		draw_polyline(line, WALL_OUTLINE, outline_width * 2.5, true)
	var spacing := _hex_radius * STAKE_SPACING
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var count := maxi(1, roundi(a.distance_to(b) / spacing))
		for k in count:
			var spot := a.lerp(b, (k + 0.5) / count)
			if stone:
				_draw_merlon(spot)
			else:
				_draw_stake(spot)


## Pieu de palissade planté en `foot` : corps de bois éclairé à gauche, pointe en haut, cerné de sombre.
func _draw_stake(foot: Vector2) -> void:
	var w := _hex_radius * STAKE_SPACING * 0.7
	var h := _hex_radius * STAKE_HEIGHT
	var body := PackedVector2Array([foot + Vector2(-w / 2.0, 0.0), foot + Vector2(w / 2.0, 0.0),
			foot + Vector2(w / 2.0, -h), foot + Vector2(0.0, -h - w * 0.7), foot + Vector2(-w / 2.0, -h)])
	draw_colored_polygon(body, WOOD_COLORS[1])
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-w / 2.0, 0.0), foot + Vector2(-w / 2.0 + w * 0.35, 0.0),
			foot + Vector2(-w / 2.0 + w * 0.35, -h - w * 0.45), foot + Vector2(-w / 2.0, -h)]), WOOD_COLORS[2])
	body.append(body[0])
	draw_polyline(body, WALL_OUTLINE, maxf(1.0, _hex_radius * 0.015), true)


## Merlon de mur de pierre posé sur le chemin de ronde en `spot` : bloc éclairé à gauche, cerné de sombre.
func _draw_merlon(spot: Vector2) -> void:
	var s := _hex_radius * STONE_WIDTH * 0.8
	var block := Rect2(spot + Vector2(-s / 2.0, -s * 1.2), Vector2(s, s))
	draw_rect(block, STONE_COLORS[1])
	draw_rect(Rect2(block.position, Vector2(s * 0.35, s)), STONE_COLORS[2])
	draw_rect(Rect2(block.position + Vector2(0.0, s * 0.75), Vector2(s, s * 0.25)), STONE_COLORS[0])
	draw_rect(block, WALL_OUTLINE, false, maxf(1.0, _hex_radius * 0.015))
