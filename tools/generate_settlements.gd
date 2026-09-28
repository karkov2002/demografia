extends SceneTree
## Génère les agglomérations (village, ville, mégapole) de chaque époque, en pixel art vu de trois quarts,
## dans res://assets/settlements/. Même format que les tuiles de terrain (42×48, voir generate_tiles.gd),
## pour être posées sur la tuile à la même échelle de pixels : lumière venant d'en haut à gauche, ombres
## portées vers le bas à droite, palettes naturelles et douces, sans contour noir.
## Chaque agglomération a deux calques :
## - `_base` : les bâtiments dans leurs couleurs naturelles (pierre, torchis, chaume, terre cuite) ;
## - `_roof` : les toits et bannières en niveaux de gris, que le jeu teinte à la couleur du joueur et pose
##   par-dessus, en partie transparents pour garder la matière des toits.
## À relancer après modification :
##   godot --headless --path . -s res://tools/generate_settlements.gd

const WIDTH := 42
const HEIGHT := 48
const OUT_DIR := "res://assets/settlements/"

## Nuances du plus sombre au plus clair.
const STONE := ["6e6453", "8a7f69", "a89c82", "c4b89c", "ddd2b6", "efe6cf"]
const DAUB := ["7a664c", "98836a", "b5a084", "d0bd9e", "e4d6b8"]
const THATCH := ["5e4822", "7c6130", "9a7c40", "b99a52", "d2b86c"]
const TERRACOTTA := ["6a3021", "88412e", "a5563b", "bf6d4b", "d68a66"]
## Mêmes rangs en niveaux de gris, pour le calque teinté des toits.
const MASK := ["404040", "5c5c5c", "7a7a7a", "989898", "b8b8b8", "d8d8d8"]
const OPENING := "2e241c"
const WOOD := "4e3826"
## Ombre portée sur le sol.
const SHADOW := Color(0.05, 0.08, 0.03, 0.38)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save_layers(_antiquity_village(), "antiquity_village")
	_save_layers(_antiquity_town(), "antiquity_town")
	_save_layers(_antiquity_megapolis(), "antiquity_megapolis")
	quit()


## Calques [base, toits] d'une agglomération vide.
func _layers() -> Array[Image]:
	return [Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8),
			Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)]


func _save_layers(layers: Array[Image], name: String) -> void:
	for i in 2:
		var path := OUT_DIR + name + ("_base" if i == 0 else "_roof") + ".png"
		layers[i].save_png(ProjectSettings.globalize_path(path))
		print("Agglomération générée : ", path)


func _plot(image: Image, x: int, y: int, color: Variant) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, color if color is Color else Color(color))


## Pixel de toit : sa matière naturelle sur la base (rang `rank` de `ramp`), et la même nuance de gris
## sur le calque teinté.
func _roof_pixel(layers: Array[Image], x: int, y: int, ramp: Array, rank: int) -> void:
	rank = clampi(rank, 0, ramp.size() - 1)
	_plot(layers[0], x, y, ramp[rank])
	_plot(layers[1], x, y, MASK[rank])


## Pixel de mur : effacé du calque teinté (un mur peut passer devant le toit d'un bâtiment plus loin).
func _wall_pixel(layers: Array[Image], x: int, y: int, color: String) -> void:
	_plot(layers[0], x, y, color)
	_plot(layers[1], x, y, Color.TRANSPARENT)


## Ombre portée sur le sol, là où rien n'est encore dessiné.
func _shadow(layers: Array[Image], x: int, y: int) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT and layers[0].get_pixel(x, y).a == 0.0:
		layers[0].set_pixel(x, y, SHADOW)


## Ombre d'un volume dont la face avant va de `left` à `right` et de `top` au sol `ground` : une bande
## à droite et une ligne sous le pied, décalées vers le bas à droite (lumière d'en haut à gauche).
func _cast_shadow(layers: Array[Image], left: int, right: int, top: int, ground: int, reach: int = 2) -> void:
	for y in range(top + 2, ground + 2):
		for dx in range(1, reach + 1):
			_shadow(layers, right + dx, y)
	for x in range(left + 1, right + reach + 1):
		_shadow(layers, x, ground + 1)


## Maison vue de trois quarts : façade de `width` pixels et `wall` de haut posée sur la ligne de sol
## `ground` (éclairée à gauche, porte et fenêtre sombres), sous un toit à deux pans de `roof` pixels de
## profondeur, qui déborde d'un pixel de chaque côté (pan avant éclairé, faîtage clair, pan arrière
## plus sombre).
func _house(layers: Array[Image], x: int, ground: int, width: int, wall: int, roof: int, ramp: Array = TERRACOTTA) -> void:
	var wall_top := ground - wall + 1
	var roof_top := wall_top - roof
	_cast_shadow(layers, x - 1, x + width, roof_top, ground)
	for y in range(wall_top, ground + 1):
		for col in range(x, x + width):
			var rank := 3
			if col == x:
				rank = 4
			elif col >= x + width - 2:
				rank = 1
			if y == ground:
				rank -= 1
			_wall_pixel(layers, col, y, DAUB[clampi(rank, 0, DAUB.size() - 1)])
	# Porte au milieu, fenêtre à gauche sur une façade assez large.
	var door := x + width / 2
	for y in range(maxi(wall_top, ground - 1), ground + 1):
		_wall_pixel(layers, door, y, OPENING)
	if width >= 6 and wall >= 3:
		_wall_pixel(layers, x + 1, wall_top + 1, OPENING)
	var ridge := roof_top + roof / 2
	for y in range(roof_top, wall_top):
		for col in range(x - 1, x + width + 1):
			var rank := 3 if y > ridge else (4 if y == ridge else 2)
			if y == wall_top - 1:
				rank = 1  # bord du toit, dans l'ombre de l'avancée
			if col == x - 1:
				rank += 1
			elif col == x + width:
				rank -= 1
			_roof_pixel(layers, col, y, ramp, rank)


## Hutte ronde : mur de torchis arrondi de `half` pixels de part et d'autre de `cx`, `wall` de haut sur le
## sol `ground`, sous un toit de chaume conique de `roof` pixels qui déborde d'un pixel.
func _hut(layers: Array[Image], cx: int, ground: int, half: int, wall: int, roof: int) -> void:
	var wall_top := ground - wall + 1
	var apex := wall_top - roof
	_cast_shadow(layers, cx - half - 1, cx + half + 1, apex, ground)
	for y in range(wall_top, ground + 1):
		for col in range(cx - half, cx + half + 1):
			# Coins arrondis au pied.
			if y == ground and absi(col - cx) == half:
				continue
			var rank := 3 if col < cx else (2 if col < cx + half else 1)
			if col == cx - half:
				rank = 4
			_wall_pixel(layers, col, y, DAUB[rank])
	_wall_pixel(layers, cx, ground, OPENING)
	_wall_pixel(layers, cx, ground - 1, OPENING)
	for y in range(apex, wall_top):
		var spread := roundi(float(y - apex + 1) / roof * (half + 1))
		for col in range(cx - spread, cx + spread + 1):
			var rank := 3 if col < cx else 2
			if col == cx - spread:
				rank = 4
			elif col == cx + spread:
				rank = 1
			if y == wall_top - 1:
				rank -= 1
			_roof_pixel(layers, col, y, THATCH, rank)


## Temple grec vu de face et d'en haut : toit de tuiles qui file vers l'arrière, fronton de pierre,
## architrave, colonnes claires séparées d'ombre, et deux marches jusqu'au sol `ground`. Façade de
## `x` à `x + width - 1`, colonnes de `columns` pixels de haut.
func _temple(layers: Array[Image], x: int, ground: int, width: int, columns: int) -> void:
	var steps_top := ground - 1
	var columns_top := steps_top - columns
	var architrave := columns_top - 1
	var pediment := maxi(2, width / 4)
	var roof_top := architrave - pediment - 3
	_cast_shadow(layers, x - 1, x + width, roof_top, ground, 3)
	# Toit qui file vers l'arrière, derrière le fronton.
	for y in range(roof_top, architrave):
		for col in range(x - 1, x + width + 1):
			var rank := 2 if y < roof_top + 2 else 3
			if col == x - 1:
				rank += 1
			elif col == x + width:
				rank -= 1
			_roof_pixel(layers, col, y, TERRACOTTA, rank)
	# Fronton triangulaire de pierre, par-dessus le bas du toit.
	var middle := x + (width - 1) / 2.0
	for y in range(architrave - pediment, architrave):
		var spread := float(y - (architrave - pediment) + 1) / pediment * (width / 2.0)
		for col in range(x, x + width):
			if absf(col - middle) <= spread:
				var inner := absf(col - middle) <= spread - 1.5 and y < architrave - 1
				_wall_pixel(layers, col, y, STONE[2] if inner else STONE[4])
	for col in range(x - 1, x + width + 1):
		_wall_pixel(layers, col, architrave, STONE[4] if col < x + width - 1 else STONE[2])
	# Colonnes claires (éclairées à gauche), ombre entre elles.
	for y in range(columns_top, steps_top):
		for col in range(x, x + width):
			var column := (col - x) % 2 == 0
			_wall_pixel(layers, col, y, (STONE[5] if col < middle else STONE[4]) if column else STONE[0])
	for y in range(steps_top, ground + 1):
		for col in range(x - 2 + (y - steps_top), x + width + 2 - (y - steps_top)):
			_wall_pixel(layers, col, y, STONE[3] if y == steps_top else STONE[2])


## Tour de guet crénelée de `width` pixels et `height` de haut sur le sol `ground`, meurtrière sombre, et
## bannière à la couleur du joueur au sommet.
func _tower(layers: Array[Image], x: int, ground: int, width: int, height: int) -> void:
	var top := ground - height + 1
	_cast_shadow(layers, x, x + width - 1, top - 4, ground, 3)
	for y in range(top, ground + 1):
		for col in range(x, x + width):
			if y == top and (col - x) % 2 == 1:
				continue  # créneaux
			var rank := 4 if col == x else (1 if col == x + width - 1 else 3)
			if y == top + 1:
				rank = 5  # chemin de ronde, vu d'en haut
			_wall_pixel(layers, col, y, STONE[rank])
	_wall_pixel(layers, x + width / 2, top + 4, OPENING)
	_wall_pixel(layers, x + width / 2, top + 5, OPENING)
	# Mât et bannière.
	var pole := x + width / 2
	for y in range(top - 4, top):
		_wall_pixel(layers, pole, y, WOOD)
	for y in range(top - 4, top - 2):
		for col in range(pole + 1, pole + 4):
			_roof_pixel(layers, col, y, TERRACOTTA, 3 if y == top - 4 else 2)


## Rempart crénelé de `left` à `right`, `height` pixels de haut sur le sol `ground`, percé d'une porte en
## arc de `gate` pixels au milieu.
func _rampart(layers: Array[Image], left: int, right: int, ground: int, height: int, gate: int) -> void:
	var top := ground - height + 1
	_cast_shadow(layers, left, right, top, ground)
	var middle := (left + right) / 2
	for y in range(top, ground + 1):
		for col in range(left, right + 1):
			if y == top and (col - left) % 3 == 2:
				continue  # créneaux
			var in_gate := absi(col - middle) <= gate / 2 and y >= top + 2 and not (y == top + 2 and absi(col - middle) == gate / 2)
			if in_gate:
				_wall_pixel(layers, col, y, OPENING)
				continue
			var rank := 3
			if y == top + 1:
				rank = 5  # chemin de ronde
			elif (y - top) % 2 == 0 and (col + y) % 4 == 0:
				rank = 2  # joints des pierres
			if col == left:
				rank = mini(rank + 1, 5)
			elif col == right:
				rank = 1
			_wall_pixel(layers, col, y, STONE[rank])


## Village antique : trois huttes au toit de chaume.
func _antiquity_village() -> Array[Image]:
	var layers := _layers()
	_hut(layers, 26, 21, 3, 3, 5)
	_hut(layers, 15, 24, 4, 4, 6)
	_hut(layers, 24, 30, 3, 3, 5)
	return layers


## Ville antique : un temple grec entouré de maisons aux toits de tuiles.
func _antiquity_town() -> Array[Image]:
	var layers := _layers()
	_house(layers, 25, 19, 7, 3, 4)
	_temple(layers, 9, 23, 13, 5)
	_house(layers, 26, 28, 8, 4, 4)
	_house(layers, 10, 31, 7, 3, 4)
	return layers


## Mégapole antique : cité ceinte d'un rempart crénelé, avec un grand temple, une tour de guet et des
## maisons serrées.
func _antiquity_megapolis() -> Array[Image]:
	var layers := _layers()
	_tower(layers, 29, 19, 5, 11)
	_temple(layers, 7, 20, 17, 6)
	_house(layers, 26, 25, 7, 3, 3)
	_house(layers, 8, 27, 6, 3, 3)
	_house(layers, 16, 28, 7, 3, 3)
	_house(layers, 27, 30, 6, 3, 3)
	_rampart(layers, 5, 36, 35, 4, 4)
	return layers
