extends SceneTree
## Génère les icônes en pixel art (16×16) dans res://assets/icons/.
## À relancer après modification :
##   godot --headless --path . -s res://tools/generate_icons.gd

const SIZE := 16
const OUT_DIR := "res://assets/icons/"

const OUTLINE := Color("3b2a20")
const CANVAS := Color("f4efd8")
const CANVAS_SHADE := Color("d6c9a6")
const WOOD := Color("a8743f")
const WOOD_DARK := Color("7a5230")
const WHEEL := Color("5a4030")
const HUB := Color("d9b77e")

const GOLD_OUTLINE := Color("7a4a10")
const GOLD := Color("f2b233")
const GOLD_RIM := Color("d4912a")
const GOLD_SHINE := Color("fff0a0")
const ARROW_OUTLINE := Color("1e1e1e")
const ARROW_UP := Color("4cc94c")
const ARROW_FLAT := Color("a0a0a0")
const ARROW_DOWN := Color("e03c3c")

const BULB_OUTLINE := Color("5a4a1e")
const BULB_GLASS := Color("ffe680")
const BULB_GLOW := Color("fff7cc")
const BULB_SHADE := Color("f0c850")
const SOCKET := Color("9aa0a8")
const SOCKET_DARK := Color("6b7078")
const BUST_OUTLINE := Color("1f3d1a")
const BUST := Color("5aa84a")
const BUST_SHADE := Color("3f8a35")
const APPLE_OUTLINE := Color("4a1414")
const APPLE := Color("d83a3a")
const APPLE_SHADE := Color("a82828")
const APPLE_SHINE := Color("ff9a8a")
const STEM := Color("6b4423")
const LEAF := Color("4cae3c")
const WARNING_OUTLINE := Color("4a0e0e")
const WARNING := Color("e04040")
const WARNING_SHADE := Color("b82e2e")
const WARNING_MARK := Color("fff4e0")
const BOLT_OUTLINE := Color("5a3a08")
const BOLT := Color("ffd23f")
const BOLT_SHADE := Color("f0a020")
const SOIL := Color("8a5a32")
const SOIL_OUTLINE := Color("2e1e10")
const LEAF_DARK := Color("3a8a2e")
const ARROW_EXPORT := Color("f08040")
const SCALE_METAL := Color("d9b24a")
const SCALE_OUTLINE := Color("3a2a10")
const BLADE := Color("dfe4ec")
const BLADE_SHADE := Color("9aa4b2")
const GUARD := Color("c8a040")
const GRIP := Color("6b4423")
const GLASS_OUTLINE := Color("1e3a5a")
const GLASS := Color("d8eef5")
const GLASS_SHINE := Color("ffffff")
const LIQUID := Color("4a8ff0")
const LIQUID_SHADE := Color("2f6cc8")
const STONE_OUTLINE := Color("2a2a30")
const STONE := Color("a8a8b0")
const STONE_SHADE := Color("7c7c86")
const STONE_JOINT := Color("8e8e98")
const DOORWAY := Color("3a2a20")

## Images de l'animation du chariot en route : rayons des roues en « + » puis en « × » (la roue tourne),
## et caisse qui tressaute d'un pixel vers le haut sur les images 1 et 2.
const SETTLER_FRAMES := 4
const SETTLER_BOUNCE := [0, 1, 1, 0]
## Animations de guerre, en 4 images chacune : soldat en marche (armée en route), épées qui
## s'entrechoquent et petite explosion (bataille).
const WAR_FRAMES := 4
## Épées de la bataille : angle (degrés depuis la verticale) de chacune, de l'écart au choc (étincelle
## sur l'image 2).
const CLASH_ANGLES := [10.0, 28.0, 45.0, 28.0]
const HELMET := Color("b8c0cc")
const HELMET_SHADE := Color("7e8898")
const SKIN := Color("f0c090")
const TUNIC := Color("c83c32")
const TUNIC_SHADE := Color("962a24")
const SHIELD := Color("8a5a32")
const SHIELD_BOSS := Color("d9b24a")
const BOOT := Color("3a2a20")
const SPARK := Color("fff7cc")
const SPARK_EDGE := Color("ffd23f")
const FIRE_CORE := Color("fff4b0")
const FIRE := Color("ffb030")
const FIRE_EDGE := Color("e0502a")
const SMOKE := Color("6e6a66")
const SMOKE_LIGHT := Color("9a948e")
## Icônes en niveaux de gris, teintées au dessin à la couleur d'un joueur (le contour reste sombre).
const TINT_WALL := Color(1.0, 1.0, 1.0)
const TINT_SHADE := Color(0.72, 0.72, 0.72)
const TINT_ROOF := Color(0.5, 0.5, 0.5)
const TINT_WINDOW := Color(0.22, 0.22, 0.22)
const TINT_OUTLINE := Color(0.12, 0.12, 0.12)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_settler(), "settler")
	for frame in SETTLER_FRAMES:
		_save(_settler(frame), "settler_move_%d" % frame)
	_save(_trophy(), "victory")
	_save(_broken_sword(), "defeat")
	_save(_flag(), "colony")
	_save(_white_flag(), "surrender")
	for frame in WAR_FRAMES:
		_save(_soldier(frame), "army_move_%d" % frame)
		_save(_clash(frame), "clash_%d" % frame)
		_save(_explosion(frame), "explosion_%d" % frame)
	_save(_gold_trend(Vector2i.UP, ARROW_UP), "gold_up")
	_save(_gold_trend(Vector2i.RIGHT, ARROW_FLAT), "gold_flat")
	_save(_gold_trend(Vector2i.DOWN, ARROW_DOWN), "gold_down")
	_save(_gold(), "gold")
	_save(_bulb(), "science")
	_save(_bust(), "population")
	# Même buste en niveaux de gris, à teinter à la couleur d'un joueur (le contour reste sombre).
	_save(_bust(Color.WHITE, Color(0.72, 0.72, 0.72), Color(0.12, 0.12, 0.12)), "population_tint")
	# Agglomérations, par époque (village, ville, mégapole).
	_save(_antiquity_village(), "settlement_antiquity_village")
	_save(_antiquity_town(), "settlement_antiquity_town")
	_save(_antiquity_megapolis(), "settlement_antiquity_megapolis")
	_save(_apple(), "food")
	_save(_starvation(), "starvation")
	_save(_boost(), "boost")
	_save(_sword(), "sword")
	_save(_battle(), "battle")
	_save(_march(), "march")
	_save(_flask(), "scientist")
	_save(_tower(), "garrison")
	_save(_produce(), "food_produce")
	_save(_trade(), "food_trade")
	_save(_net(), "food_net")
	_save(_trend(Vector2i.UP, ARROW_UP), "trend_up")
	_save(_trend(Vector2i.RIGHT, ARROW_FLAT), "trend_flat")
	_save(_trend(Vector2i.DOWN, ARROW_DOWN), "trend_down")
	_save(_food_trend(Vector2i.UP, ARROW_UP), "food_up")
	_save(_food_trend(Vector2i.RIGHT, ARROW_FLAT), "food_flat")
	_save(_food_trend(Vector2i.DOWN, ARROW_DOWN), "food_down")
	_save(_grain_sack(), "grain_sack")
	_save(_speaker(true), "sound_on")
	_save(_speaker(false), "sound_off")
	quit()


func _save(image: Image, name: String) -> void:
	var path := OUT_DIR + name + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	print("Icône générée : ", path)


## Remplit la forme `inside(x, y)` avec `fill(x, y)`, en contour `outline` sur ses bords.
func _shape(image: Image, inside: Callable, fill: Callable, outline: Color = OUTLINE) -> void:
	for y in SIZE:
		for x in SIZE:
			if not inside.call(x, y):
				continue
			var border: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y)
					and inside.call(x, y - 1) and inside.call(x, y + 1))
			image.set_pixel(x, y, outline if border else fill.call(x, y))


## Chariot bâché : bâche en arche, caisse en bois, deux roues. Avec `frame` (0 à SETTLER_FRAMES - 1),
## image de l'animation du chariot en route : caisse soulevée de SETTLER_BOUNCE[frame] pixels et rayons
## des roues visibles, en « + » ou en « × » selon l'image.
func _settler(frame: int = -1) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lift: int = 0 if frame < 0 else SETTLER_BOUNCE[frame]
	# Bâche : demi-ellipse, ombrée à droite, avec deux arceaux.
	_shape(image,
			func(x: int, y: int) -> bool:
				return y + lift <= 8 and pow((x + 0.5 - 8.0) / 6.5, 2) + pow((y + lift + 0.5 - 8.5) / 7.0, 2) <= 1.0,
			func(x: int, _y: int) -> Color:
				return CANVAS_SHADE if x >= 11 or x == 5 or x == 8 else CANVAS)
	# Caisse en bois, barrée d'une planche sombre.
	_shape(image,
			func(x: int, y: int) -> bool:
				return x >= 1 and x <= 14 and y + lift >= 8 and y + lift <= 12,
			func(x: int, y: int) -> Color:
				return WOOD_DARK if y + lift == 10 else WOOD)
	# Roues avec moyeu clair et, en route, rayons clairs.
	for wheel_x in [4.5, 11.5]:
		_shape(image,
				func(x: int, y: int) -> bool:
					return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(wheel_x, 13.5)) <= 2.5,
				func(x: int, y: int) -> Color:
					var offset := Vector2(x + 0.5, y + 0.5) - Vector2(wheel_x, 13.5)
					if offset.length() < 1.0:
						return HUB
					var straight := absf(offset.x) < 0.1 or absf(offset.y) < 0.1
					if frame >= 0 and offset.length() < 1.5 and straight == (frame % 2 == 0):
						return HUB
					return WHEEL)
	return image


## Pièce d'or barrée d'une flèche vers `direction`.
func _gold_trend(direction: Vector2i, arrow_color: Color) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_coin(image, Vector2(7.0, 8.0))
	_arrow(image, direction, arrow_color)
	return image


## Pièce d'or seule, centrée.
func _gold() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_coin(image, Vector2(8.0, 8.0))
	return image


## Pièce d'or de rayon 6,5 centrée sur `center` : bord en relief, reflet en haut à gauche.
func _coin(image: Image, center: Vector2) -> void:
	for y in SIZE:
		for x in SIZE:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance > 6.5:
				continue
			var color := GOLD
			if distance > 5.6:
				color = GOLD_OUTLINE
			elif distance > 4.0 and distance <= 4.8:
				color = GOLD_RIM
			elif x - center.x < -1.0 and y - center.y < -1.0 and distance < 4.0:
				color = GOLD_SHINE
			image.set_pixel(x, y, color)


## Ampoule : globe jaune lumineux (reflet en haut à gauche, ombre à droite) sur un culot vissé.
func _bulb() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var glass_center := Vector2(8.0, 6.5)
	_shape(image,
			func(x: int, y: int) -> bool:
				var point := Vector2(x + 0.5, y + 0.5)
				# Globe rond qui se resserre vers le culot.
				return point.distance_to(glass_center) <= 5.8 or (y >= 9 and y <= 11 and absf(point.x - 8.0) <= 3.2),
			func(x: int, y: int) -> Color:
				var offset := Vector2(x + 0.5, y + 0.5) - glass_center
				if offset.x < -1.0 and offset.y < -1.0 and offset.length() < 3.5:
					return BULB_GLOW
				return BULB_SHADE if offset.x > 2.0 else BULB_GLASS,
			BULB_OUTLINE)
	_shape(image,
			func(x: int, y: int) -> bool:
				return x >= 5 and x <= 10 and y >= 11 and y <= 15,
			func(_x: int, y: int) -> Color:
				return SOCKET_DARK if y % 2 == 0 else SOCKET,
			BULB_OUTLINE)
	return image


## Buste simplifié : tête ronde posée sur des épaules en arrondi.
func _bust(fill: Color = BUST, shade: Color = BUST_SHADE, outline: Color = BUST_OUTLINE) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				return pow((x + 0.5 - 8.0) / 6.5, 2) + pow((y + 0.5 - 16.5) / 7.0, 2) <= 1.0,
			func(x: int, _y: int) -> Color:
				return shade if x >= 10 else fill,
			outline)
	_shape(image,
			func(x: int, y: int) -> bool:
				return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8.0, 5.0)) <= 4.4,
			func(x: int, _y: int) -> Color:
				return shade if x >= 9 else fill,
			outline)
	return image


## Village antique : deux huttes rondes à toit de chaume conique, en niveaux de gris à teinter (voir
## _building).
func _antiquity_village() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_hut(image, 4, 3, [1, 2, 3, 4, 4], 3)
	_hut(image, 12, 7, [1, 2, 3, 4], 3)
	return image


## Hutte ronde centrée entre les colonnes `center - 1` et `center` : toit de chaume à partir de la ligne
## `top`, dont chaque rangée s'étend de `roof_halves[i]` pixels de part et d'autre (la dernière déborde
## des murs), puis murs de `wall_half` pixels de part et d'autre jusqu'au bas de l'image, et porte
## sombre au milieu.
func _hut(image: Image, center: int, top: int, roof_halves: Array, wall_half: int) -> void:
	var walls_top: int = top + roof_halves.size()
	_shape(image,
			func(x: int, y: int) -> bool:
				# Distance au milieu : 1 pour les deux colonnes centrales, puis 2, 3…
				var offset: int = x - center + 1 if x >= center else center - x
				if y >= top and y < walls_top:
					return offset <= roof_halves[y - top]
				return y >= walls_top and y < SIZE and offset <= wall_half,
			func(x: int, y: int) -> Color:
				if y < walls_top:
					return TINT_ROOF
				if x in [center - 1, center] and y >= SIZE - 3:
					return TINT_WINDOW
				return TINT_SHADE if x >= center + wall_half - 1 else TINT_WALL,
			TINT_OUTLINE)


## Ville antique : un temple grec (fronton, colonnes, marches) à côté d'une maison.
func _antiquity_town() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_building(image, Rect2i(11, 10, 5, 5), 3, [Vector2i(13, 13), Vector2i(13, 14)])
	_temple(image, 0, 10, 4)
	return image


## Mégapole antique : cité fortifiée, rempart crénelé percé d'une porte, et derrière lui un grand temple
## et une tour de guet.
func _antiquity_megapolis() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_temple(image, 0, 9, 1)
	# Tour de guet à deux créneaux, percée d'une fenêtre.
	_shape(image,
			func(x: int, y: int) -> bool:
				return x >= 11 and x <= 14 and (y >= 3 and y <= 10 or y == 2 and x in [11, 14]),
			func(x: int, y: int) -> Color:
				if x in [12, 13] and y == 5:
					return TINT_WINDOW
				return TINT_SHADE if x == 14 else TINT_WALL,
			TINT_OUTLINE)
	# Rempart crénelé, avec sa porte en arc.
	_shape(image,
			func(x: int, y: int) -> bool:
				return y >= 10 and y <= 15 or y == 9 and x % 3 != 2,
			func(x: int, y: int) -> Color:
				if x >= 7 and x <= 8 and y >= 12 or y == 12 and x == 6:
					return TINT_WINDOW
				return TINT_ROOF if y == 11 else TINT_SHADE,
			TINT_OUTLINE)
	return image


## Temple grec en niveaux de gris entre les colonnes `left` et `right` : fronton triangulaire au sommet
## `top`, architrave, colonnes séparées d'ombre, puis deux marches jusqu'au bas de l'image.
func _temple(image: Image, left: int, right: int, top: int) -> void:
	var middle := (left + right) / 2.0 + 0.5
	var half := (right - left + 1) / 2.0
	_shape(image,
			func(x: int, y: int) -> bool:
				if x < left or x > right or y < top:
					return false
				var pediment := y < top + 3 and absf(x + 0.5 - middle) <= half * float(y - top + 1) / 3.0 - 0.5
				return pediment or y >= top + 3,
			func(x: int, y: int) -> Color:
				if y < top + 3:
					return TINT_ROOF
				if y == top + 3 or y >= SIZE - 2:
					return TINT_SHADE
				# Colonnes claires une sur deux, ombre entre elles.
				return TINT_WALL if (x - left) % 2 == 1 else TINT_WINDOW,
			TINT_OUTLINE)


## Bâtiment en niveaux de gris, à teinter à la couleur d'un joueur : murs `walls` (clairs, ombrés sur la
## droite), toit à deux pans de `roof` pixels de haut au-dessus (0 = toit plat), fenêtres et portes
## sombres aux pixels `openings` ; contour sombre commun.
func _building(image: Image, walls: Rect2i, roof: int, openings: Array[Vector2i]) -> void:
	var center_x := walls.position.x + walls.size.x / 2.0
	_shape(image,
			func(x: int, y: int) -> bool:
				if walls.has_point(Vector2i(x, y)):
					return true
				var height := walls.position.y - y
				return roof > 0 and height >= 1 and height <= roof \
						and absf(x + 0.5 - center_x) <= walls.size.x / 2.0 * (1.0 - float(height - 1) / roof),
			func(x: int, y: int) -> Color:
				if y < walls.position.y:
					return TINT_ROOF
				return TINT_SHADE if x >= walls.end.x - 2 else TINT_WALL,
			TINT_OUTLINE)
	for pixel in openings:
		image.set_pixelv(pixel, TINT_WINDOW)


## Pomme rouge (reflet à gauche, ombre à droite) avec sa queue et une feuille, décalée de `shift`
## pixels vers la droite.
func _apple(shift: int = 0) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				var point := Vector2(x - shift + 0.5, y + 0.5)
				# Deux lobes accolés pour le creux du haut.
				return point.distance_to(Vector2(6.3, 9.5)) <= 5.0 or point.distance_to(Vector2(9.7, 9.5)) <= 5.0,
			func(x: int, y: int) -> Color:
				if x - shift <= 5 and y >= 7 and y <= 9:
					return APPLE_SHINE
				return APPLE_SHADE if x - shift >= 11 else APPLE,
			APPLE_OUTLINE)
	for y in range(2, 6):
		image.set_pixel(8 + shift, y, STEM)
	for leaf in [Vector2i(9, 3), Vector2i(10, 3), Vector2i(10, 2), Vector2i(11, 2)]:
		image.set_pixelv(leaf + Vector2i(shift, 0), LEAF)
	return image


## Pomme décalée à gauche, barrée d'une flèche vers `direction` (tendance de la food).
func _food_trend(direction: Vector2i, arrow_color: Color) -> Image:
	var image := _apple(-1)
	_arrow(image, direction, arrow_color)
	return image


## Flèche dans le coin droit (pour les tendances posées sur une pièce ou une pomme).
func _arrow(image: Image, direction: Vector2i, color: Color) -> void:
	const TIPS := {Vector2i.UP: Vector2i(12, 6), Vector2i.DOWN: Vector2i(12, 12), Vector2i.RIGHT: Vector2i(14, 9)}
	_stroke(image, _arrow_pixels(direction, TIPS[direction], 4), color)


## Pixels d'une flèche d'un pixel d'épaisseur pointant vers `direction` : pointe en `tip` sur 3 rangées
## (1, 3 puis 5 pixels), suivie d'une hampe de `shaft` pixels.
func _arrow_pixels(direction: Vector2i, tip: Vector2i, shaft: int) -> Array[Vector2i]:
	var back := -direction
	var side := Vector2i(direction.y, direction.x)
	var pixels: Array[Vector2i] = []
	for i in 3:
		for k in range(-i, i + 1):
			pixels.append(tip + back * i + side * k)
	for i in range(3, 3 + shaft):
		pixels.append(tip + back * i)
	return pixels


## Peint `pixels` en `color`, cernés d'un contour sombre pour ressortir sur n'importe quel fond.
func _stroke(image: Image, pixels: Array[Vector2i], color: Color, outline: Color = ARROW_OUTLINE) -> void:
	for pixel in pixels:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var around := pixel + Vector2i(dx, dy)
				if around not in pixels and around.x >= 0 and around.x < SIZE and around.y >= 0 and around.y < SIZE:
					image.set_pixelv(around, outline)
	for pixel in pixels:
		image.set_pixelv(pixel, color)


## Flèche de tendance seule, centrée.
func _trend(direction: Vector2i, color: Color) -> Image:
	const TIPS := {Vector2i.UP: Vector2i(8, 2), Vector2i.DOWN: Vector2i(8, 13), Vector2i.RIGHT: Vector2i(13, 8)}
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_stroke(image, _arrow_pixels(direction, TIPS[direction], 8), color)
	return image


## Production de food : jeune pousse à deux feuilles sortant d'une motte de terre.
func _produce() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				return y >= 12 and pow((x + 0.5 - 8.0) / 7.0, 2) + pow((y + 0.5 - 16.0) / 4.0, 2) <= 1.0,
			func(_x: int, _y: int) -> Color: return SOIL,
			SOIL_OUTLINE)
	var stem: Array[Vector2i] = []
	for y in range(5, 13):
		stem.append(Vector2i(8, y))
	_stroke(image, stem, LEAF_DARK, SOIL_OUTLINE)
	for leaf_center in [Vector2(4.5, 6.5), Vector2(11.5, 4.5)]:
		_shape(image,
				func(x: int, y: int) -> bool:
					return pow((x + 0.5 - leaf_center.x) / 3.8, 2) + pow((y + 0.5 - leaf_center.y) / 2.3, 2) <= 1.0,
				func(_x: int, y: int) -> Color: return LEAF if y < leaf_center.y else LEAF_DARK,
				SOIL_OUTLINE)
	return image


## Échanges de food : deux flèches opposées (⇄).
func _trade() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_stroke(image, _arrow_pixels(Vector2i.RIGHT, Vector2i(13, 4), 9), ARROW_UP)
	_stroke(image, _arrow_pixels(Vector2i.LEFT, Vector2i(2, 11), 9), ARROW_EXPORT)
	return image


## Solde : balance à deux plateaux suspendus à un fléau.
func _net() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var frame: Array[Vector2i] = []
	for y in range(3, 14):
		frame.append_array([Vector2i(7, y), Vector2i(8, y)])
	for x in range(2, 14):
		frame.append(Vector2i(x, 3))
	for x in range(4, 12):
		frame.append(Vector2i(x, 14))
	for pan_x in [3, 12]:
		# Cordes en V sous chaque extrémité du fléau, puis le plateau.
		frame.append(Vector2i(pan_x, 4))
		for y in [5, 6]:
			frame.append_array([Vector2i(pan_x - 1, y), Vector2i(pan_x + 1, y)])
		frame.append_array([Vector2i(pan_x - 2, 7), Vector2i(pan_x + 2, 7)])
		for x in range(pan_x - 2, pan_x + 3):
			frame.append(Vector2i(x, 8))
		for x in range(pan_x - 1, pan_x + 2):
			frame.append(Vector2i(x, 9))
	_stroke(image, frame, SCALE_METAL, SCALE_OUTLINE)
	return image


## Panneau d'alerte : triangle rouge marqué d'un point d'exclamation clair.
func _starvation() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				# Triangle pointe en haut : il s'élargit d'un demi-pixel de chaque côté par rangée.
				return y >= 1 and y <= 14 and absf(x + 0.5 - 8.0) <= (y - 0.5) * 0.55,
			func(x: int, _y: int) -> Color:
				return WARNING_SHADE if x >= 10 else WARNING,
			WARNING_OUTLINE)
	for y in range(5, 11):
		image.set_pixel(7, y, WARNING_MARK)
		image.set_pixel(8, y, WARNING_MARK)
	image.set_pixel(7, 12, WARNING_MARK)
	image.set_pixel(8, 12, WARNING_MARK)
	return image


## Éclair jaune en zigzag, ombré sur sa moitié droite.
func _boost() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bolt := PackedVector2Array([
		Vector2(8, 0), Vector2(2, 9.5), Vector2(7, 9.5), Vector2(4, 16), Vector2(14.5, 6), Vector2(9.5, 6), Vector2(14, 0)])
	_shape(image,
			func(x: int, y: int) -> bool:
				return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), bolt),
			func(x: int, _y: int) -> Color:
				return BOLT_SHADE if x >= 9 else BOLT,
			BOLT_OUTLINE)
	return image


## Épée en diagonale, pointe en haut à droite.
func _sword() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_sword(image, false)
	return image


## Bataille : deux épées croisées.
func _battle() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_sword(image, false)
	_draw_sword(image, true)
	return image


## Épée pointe en haut à droite (ou en haut à gauche si `mirrored`) : lame de 2 pixels ombrée d'un
## côté, garde en travers, poignée et pommeau.
func _draw_sword(image: Image, mirrored: bool) -> void:
	var flip := func(pixel: Vector2i) -> Vector2i:
		return Vector2i(SIZE - 1 - pixel.x, pixel.y) if mirrored else pixel
	var blade: Array[Vector2i] = []
	var blade_shade: Array[Vector2i] = []
	for i in 9:
		blade.append(flip.call(Vector2i(13 - i, 2 + i)))
		blade_shade.append(flip.call(Vector2i(13 - i, 3 + i)))
	var guard: Array[Vector2i] = []
	for i in 5:
		guard.append(flip.call(Vector2i(2 + i, 9 + i)))
	var grip: Array[Vector2i] = [flip.call(Vector2i(3, 12)), flip.call(Vector2i(2, 13)), flip.call(Vector2i(1, 14))]
	var all: Array[Vector2i] = []
	all.append_array(blade)
	all.append_array(blade_shade)
	all.append_array(guard)
	all.append_array(grip)
	# Contour commun, puis chaque partie dans sa couleur.
	_stroke(image, all, BLADE)
	for pixel in blade_shade:
		image.set_pixelv(pixel, BLADE_SHADE)
	for pixel in guard:
		image.set_pixelv(pixel, GUARD)
	for pixel in grip:
		image.set_pixelv(pixel, GRIP)


## Déplacement d'armée : épée suivie d'une flèche verte vers la droite.
func _march() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_sword(image, false)
	_stroke(image, _arrow_pixels(Vector2i.RIGHT, Vector2i(14, 12), 5), ARROW_UP)
	return image


## Soldat en marche vers la droite, image `frame` de l'animation : casque, tunique, bouclier rond,
## épée levée. Jambes écartées (images 0 et 2, la jambe de derrière changeant de côté) ou serrées
## (images 1 et 3, le corps se soulève alors d'un pixel).
func _soldier(frame: int) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lift := frame % 2
	# Jambes, de la hanche au pied.
	var left_leg: Array[Vector2i] = [Vector2i(7, 11), Vector2i(6, 12), Vector2i(6, 13), Vector2i(5, 14)]
	var right_leg: Array[Vector2i] = [Vector2i(8, 11), Vector2i(9, 12), Vector2i(9, 13), Vector2i(10, 14)]
	if lift == 1:
		left_leg = [Vector2i(7, 10), Vector2i(7, 11), Vector2i(7, 12), Vector2i(7, 13), Vector2i(7, 14)]
		right_leg = [Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12), Vector2i(8, 13), Vector2i(8, 14)]
	var legs: Array[Vector2i] = []
	legs.append_array(left_leg)
	legs.append_array(right_leg)
	_stroke(image, legs, TUNIC_SHADE)
	var back_leg := left_leg if frame < 2 else right_leg
	for pixel in back_leg:
		image.set_pixelv(pixel, TUNIC_SHADE.darkened(0.35))
	image.set_pixelv(left_leg[-1], BOOT)
	image.set_pixelv(right_leg[-1], BOOT)
	# Casque, visage et tunique ceinturée, d'un seul contour.
	_shape(image,
			func(x: int, y: int) -> bool:
				var row := y + lift
				var helmet := row <= 3 and pow((x + 0.5 - 8.0) / 2.8, 2) + pow((row + 0.5 - 4.0) / 2.6, 2) <= 1.0
				var face := x >= 7 and x <= 9 and row >= 4 and row <= 5
				var tunic := x >= 6 and x <= 10 and row >= 6 and row <= 10
				return helmet or face or tunic,
			func(x: int, y: int) -> Color:
				var row := y + lift
				if row <= 3:
					return HELMET_SHADE if x >= 9 else HELMET
				if row <= 5:
					return OUTLINE if x == 9 and row == 4 else SKIN
				if row == 9:
					return WOOD_DARK
				return TUNIC_SHADE if x >= 9 else TUNIC)
	# Bouclier rond à clou doré, sur le flanc gauche.
	var shield_center := Vector2(5.5, 8.5 - lift)
	_shape(image,
			func(x: int, y: int) -> bool:
				return Vector2(x + 0.5, y + 0.5).distance_to(shield_center) <= 2.6,
			func(x: int, y: int) -> Color:
				return SHIELD_BOSS if Vector2(x + 0.5, y + 0.5).distance_to(shield_center) < 1.0 else SHIELD)
	# Épée levée dans la main droite.
	var blade: Array[Vector2i] = []
	for y in range(1, 7):
		blade.append(Vector2i(12, y - lift))
	var guard: Array[Vector2i] = [Vector2i(11, 7 - lift), Vector2i(13, 7 - lift)]
	var hand := Vector2i(12, 7 - lift)
	var all: Array[Vector2i] = []
	all.append_array(blade)
	all.append_array(guard)
	all.append(hand)
	_stroke(image, all, BLADE)
	for pixel in guard:
		image.set_pixelv(pixel, GUARD)
	image.set_pixelv(hand, SKIN)
	return image


## Deux épées qui s'entrechoquent, image `frame` de l'animation : elles partent des coins bas et
## s'inclinent l'une vers l'autre de CLASH_ANGLES[frame] degrés ; étincelle au choc (image 2).
func _clash(frame: int) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var angle := deg_to_rad(CLASH_ANGLES[frame])
	var left_grip := Vector2(3.5, 14.5)
	var right_grip := Vector2(12.5, 14.5)
	_draw_swung_sword(image, left_grip, Vector2(sin(angle), -cos(angle)))
	_draw_swung_sword(image, right_grip, Vector2(-sin(angle), -cos(angle)))
	if frame == 2:
		# Point de croisement des deux lames.
		var reach := (right_grip.x - left_grip.x) / 2.0 / sin(angle)
		_spark(image, Vector2i(left_grip + Vector2(sin(angle), -cos(angle)) * reach))
	return image


## Épée qui part de la poignée `grip` dans la direction `direction` : poignée, garde en travers, lame
## de deux pixels (ombrée d'un côté) ; ce qui sort de l'image est coupé.
func _draw_swung_sword(image: Image, grip: Vector2, direction: Vector2) -> void:
	var across := direction.orthogonal()
	var parts := {GRIP: [], GUARD: [], BLADE: [], BLADE_SHADE: []}
	for step in range(0, 26):
		var t := step * 0.5
		var center := grip + direction * t
		if t < 2.0:
			parts[GRIP].append(Vector2i(center.floor()))
		elif t < 2.5:
			for side in [-1.6, -0.8, 0.0, 0.8, 1.6]:
				parts[GUARD].append(Vector2i((center + across * side).floor()))
		else:
			parts[BLADE].append(Vector2i(center.floor()))
			parts[BLADE_SHADE].append(Vector2i((center + across * 0.8).floor()))
	var all: Array[Vector2i] = []
	for color in parts:
		for pixel in parts[color]:
			if pixel not in all and pixel.x >= 0 and pixel.x < SIZE and pixel.y >= 0 and pixel.y < SIZE:
				all.append(pixel)
	_stroke(image, all, BLADE)
	for color in [BLADE_SHADE, GUARD, GRIP]:
		for pixel in parts[color]:
			if pixel in all:
				image.set_pixelv(pixel, color)


## Étincelle en étoile centrée sur `center`.
func _spark(image: Image, center: Vector2i) -> void:
	var rays: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	for ray in rays:
		var pixel := center + ray
		if pixel.x >= 0 and pixel.x < SIZE and pixel.y >= 0 and pixel.y < SIZE:
			image.set_pixelv(pixel, SPARK_EDGE)
	image.set_pixelv(center, SPARK)


## Petite explosion, image `frame` de l'animation : étincelle, boule de feu, flammes bordées de fumée,
## puis trois bouffées de fumée. Bords irréguliers, sans contour.
func _explosion(frame: int) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	const RADII := [2.5, 4.5, 6.2, 6.8]
	if frame == 3:
		for puff in [Vector2(5.5, 10.0), Vector2(10.5, 9.0), Vector2(8.0, 5.5)]:
			for y in SIZE:
				for x in SIZE:
					var distance := Vector2(x + 0.5, y + 0.5).distance_to(puff)
					if distance <= 2.6:
						image.set_pixel(x, y, SMOKE_LIGHT if distance < 1.5 else SMOKE)
		return image
	for y in SIZE:
		for x in SIZE:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8.0, 8.0))
			var noise := float((x * 7 + y * 13) % 5) / 4.0 - 0.5
			var reach: float = RADII[frame] + noise
			if distance > reach:
				continue
			var color := Color.TRANSPARENT
			match frame:
				0:
					color = FIRE_CORE if distance < 1.5 else FIRE
				1:
					color = FIRE_CORE if distance < 2.0 else (FIRE if distance < 3.5 else FIRE_EDGE)
				2:
					color = FIRE if distance < 2.5 else (FIRE_EDGE if distance < 4.5 else SMOKE)
				3:
					if (x * 5 + y * 3) % 3 == 0 or distance < 2.0:
						continue
					color = SMOKE_LIGHT if (x + y) % 2 == 0 else SMOKE
			image.set_pixel(x, y, color)
	return image


## Victoire : coupe en or à deux anses, sur un pied et un socle, avec un reflet.
func _trophy() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				var cup := y >= 1 and y <= 7 and pow((x + 0.5 - 8.0) / 5.0, 2) + pow((y + 0.5 - 1.0) / 7.0, 2) <= 1.0
				var handles := y >= 2 and y <= 5 and (x == 1 or x == 14) or (y == 2 or y == 5) and (x == 2 or x == 13)
				var stem := x >= 7 and x <= 8 and y >= 8 and y <= 11
				var base := x >= 4 and x <= 11 and y >= 12 and y <= 14
				return cup or handles or stem or base,
			func(x: int, y: int) -> Color:
				if x == 5 and y >= 2 and y <= 5:
					return GOLD_SHINE
				return GOLD_RIM if x >= 10 or y >= 13 else GOLD,
			GOLD_OUTLINE)
	return image


## Défaite : épée brisée en deux, la pointe tombée à côté de la garde.
func _broken_sword() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var hilt_blade: Array[Vector2i] = []
	for i in 4:
		hilt_blade.append(Vector2i(8 - i, 6 + i))
	var guard: Array[Vector2i] = [Vector2i(2, 8), Vector2i(3, 9), Vector2i(5, 11), Vector2i(6, 12)]
	var grip: Array[Vector2i] = [Vector2i(3, 11), Vector2i(2, 12), Vector2i(1, 13)]
	var tip: Array[Vector2i] = []
	for i in 5:
		tip.append(Vector2i(10 + i, 13 - i))
	var all: Array[Vector2i] = []
	for part in [hilt_blade, guard, grip, tip]:
		all.append_array(part)
	_stroke(image, all, BLADE)
	for pixel in guard:
		image.set_pixelv(pixel, GUARD)
	for pixel in grip:
		image.set_pixelv(pixel, GRIP)
	# Cassure : éclats sombres au bout de chaque morceau.
	image.set_pixelv(Vector2i(8, 6), BLADE_SHADE)
	image.set_pixelv(Vector2i(10, 13), BLADE_SHADE)
	return image


## Terre conquise : drapeau blanc et or planté sur une motte d'herbe.
func _flag() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# Motte d'herbe.
	_shape(image,
			func(x: int, y: int) -> bool:
				return y >= 12 and pow((x + 0.5 - 8.0) / 7.0, 2) + pow((y + 0.5 - 15.5) / 3.5, 2) <= 1.0,
			func(_x: int, y: int) -> Color:
				return LEAF if y <= 13 else LEAF_DARK,
			SOIL_OUTLINE)
	# Mât.
	var pole: Array[Vector2i] = []
	for y in range(1, 13):
		pole.append(Vector2i(4, y))
	_stroke(image, pole, WOOD, OUTLINE)
	# Étendard qui flotte, rayé d'or.
	_shape(image,
			func(x: int, y: int) -> bool:
				return x >= 5 and x <= 13 and y >= 1 and y <= 7 - int(x >= 10) and not (x == 13 and y == 4),
			func(_x: int, y: int) -> Color:
				return GOLD if y == 4 else CANVAS,
			OUTLINE)
	return image


## Scientist : fiole d'erlenmeyer en verre, remplie d'un liquide bleu jusqu'à mi-hauteur.
func _flask() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var flask := PackedVector2Array([
		Vector2(5.5, 0.5), Vector2(10.5, 0.5), Vector2(10.5, 2), Vector2(9.5, 2), Vector2(9.5, 6),
		Vector2(15, 15.5), Vector2(1, 15.5), Vector2(6.5, 6), Vector2(6.5, 2), Vector2(5.5, 2)])
	_shape(image,
			func(x: int, y: int) -> bool:
				return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), flask),
			func(x: int, y: int) -> Color:
				if y >= 10:
					return LIQUID_SHADE if x >= 10 else LIQUID
				return GLASS_SHINE if x <= 7 and y >= 3 else GLASS,
			GLASS_OUTLINE)
	return image


## Garnison : tour de château en pierre, créneaux en haut, meurtrière et porte en arc.
func _tower() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				var body := x >= 3 and x <= 12 and y >= 4 and y <= 15
				var merlon := y >= 1 and y <= 4 and x in [2, 3, 4, 7, 8, 11, 12, 13]
				return body or merlon,
			func(x: int, y: int) -> Color:
				# Assises de pierres décalées d'une rangée à l'autre, ombre sur la droite.
				if x >= 10:
					return STONE_SHADE
				return STONE_JOINT if (y % 3 == 0) or ((x + (y / 3) * 2) % 5 == 0) else STONE,
			STONE_OUTLINE)
	# Meurtrière et porte en arc.
	for y in [6, 7, 8]:
		image.set_pixel(7, y, DOORWAY)
		image.set_pixel(8, y, DOORWAY)
	for y in range(11, 15):
		for x in range(6, 10):
			if y > 11 or x in [7, 8]:
				image.set_pixel(x, y, DOORWAY)
	return image


## Sac de grain en toile de jute, aux épaules larges et au fond plat, ficelé au col, d'où dépassent des
## épis de blé dorés : la food qui part des villages vers les villes.
func _grain_sack() -> Image:
	const BURLAP := Color("d9b77e")
	const BURLAP_SHADE := Color("b08a50")
	const BURLAP_OUTLINE := Color("5a3a1e")
	# Demi-largeur de la panse à chaque ligne, du col au fond.
	const HALVES := {5: 1.5, 6: 3.0, 7: 4.5, 8: 5.5, 9: 5.5, 10: 5.5, 11: 5.5, 12: 5.5, 13: 5.5, 14: 5.0}
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# Épis qui dépassent du col : tige, puis grain doré en haut.
	for ear in [Vector2i(6, 1), Vector2i(8, 0), Vector2i(10, 1)]:
		_shape(image,
				func(x: int, y: int) -> bool:
					return y >= ear.y and y <= 5 and (x == ear.x or (absi(x - ear.x) == 1 and y <= ear.y + 2)),
				func(x: int, _y: int) -> Color:
					return GOLD_SHINE if x < ear.x else GOLD,
				GOLD_OUTLINE)
	_shape(image,
			func(x: int, y: int) -> bool:
				return HALVES.has(y) and absf(x + 0.5 - 8.0) <= HALVES[y],
			func(x: int, y: int) -> Color:
				return BURLAP_SHADE if x >= 10 or y == 13 else BURLAP,
			BURLAP_OUTLINE)
	# Ficelle au col.
	for x in range(6, 11):
		image.set_pixel(x, 6, WOOD_DARK)
	return image


## Haut-parleur clair, pavillon évasé vers la droite ; avec `on`, deux ondes sonores, sinon une croix
## rouge (son coupé). Dessiné pixel par pixel : O contour, L clair, S ombre.
func _speaker(on: bool) -> Image:
	const ROWS := [
		"................",
		"........O.......",
		".......OO.......",
		"......OLO.......",
		".....OLLO.......",
		".OOOOLLLO.......",
		".OSLLLLLO.......",
		".OSLLLLLO.......",
		".OSLLLLLO.......",
		".OSLLLLLO.......",
		".OOOOLLLO.......",
		".....OLLO.......",
		"......OLO.......",
		".......OO.......",
		"........O.......",
		"................",
	]
	const COLORS := {"O": ARROW_OUTLINE, "L": BLADE, "S": STONE_SHADE}
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var key: String = ROWS[y][x]
			if COLORS.has(key):
				image.set_pixel(x, y, COLORS[key])
	if on:
		_stroke(image, [Vector2i(10, 5), Vector2i(11, 6), Vector2i(11, 7), Vector2i(11, 8), Vector2i(11, 9),
				Vector2i(10, 10)], GLASS_SHINE)
		_stroke(image, [Vector2i(12, 2), Vector2i(13, 3), Vector2i(14, 4), Vector2i(14, 5), Vector2i(14, 6),
				Vector2i(14, 7), Vector2i(14, 8), Vector2i(14, 9), Vector2i(14, 10), Vector2i(14, 11),
				Vector2i(13, 12), Vector2i(12, 13)], GLASS_SHINE)
	else:
		var cross: Array[Vector2i] = []
		for i in 5:
			cross.append(Vector2i(10 + i, 5 + i))
			cross.append(Vector2i(14 - i, 5 + i))
		_stroke(image, cross, WARNING)
	return image


## Drapeau blanc d'abandon, un peu déchiré, qui flotte au bout d'une hampe de bois plantée de biais.
func _white_flag() -> Image:
	const ROWS := [
		"................",
		"..W.............",
		"..WOOOOOO.......",
		"..WOccccOOO.....",
		"..WOcccccccO....",
		"..WOccccssccO...",
		"..WOcccsscccO...",
		"..WOccccccccO...",
		"..WOOcccccOO....",
		"..W..OOcOO......",
		"..W....O........",
		"..W.............",
		"..W.............",
		"..W.............",
		".WWW............",
		"................",
	]
	var colors := {"W": WOOD_DARK, "O": OUTLINE, "c": CANVAS, "s": CANVAS_SHADE}
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var key: String = ROWS[y][x]
			if colors.has(key):
				image.set_pixel(x, y, colors[key])
	return image
