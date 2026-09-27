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


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_settler(), "settler")
	_save(_gold_trend(Vector2i.UP, ARROW_UP), "gold_up")
	_save(_gold_trend(Vector2i.RIGHT, ARROW_FLAT), "gold_flat")
	_save(_gold_trend(Vector2i.DOWN, ARROW_DOWN), "gold_down")
	_save(_gold(), "gold")
	_save(_bulb(), "science")
	_save(_bust(), "population")
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


## Chariot bâché : bâche en arche, caisse en bois, deux roues.
func _settler() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# Bâche : demi-ellipse, ombrée à droite, avec deux arceaux.
	_shape(image,
			func(x: int, y: int) -> bool:
				return y <= 8 and pow((x + 0.5 - 8.0) / 6.5, 2) + pow((y + 0.5 - 8.5) / 7.0, 2) <= 1.0,
			func(x: int, _y: int) -> Color:
				return CANVAS_SHADE if x >= 11 or x == 5 or x == 8 else CANVAS)
	# Caisse en bois, barrée d'une planche sombre.
	_shape(image,
			func(x: int, y: int) -> bool:
				return x >= 1 and x <= 14 and y >= 8 and y <= 12,
			func(x: int, y: int) -> Color:
				return WOOD_DARK if y == 10 else WOOD)
	# Roues avec moyeu clair.
	for wheel_x in [4.5, 11.5]:
		_shape(image,
				func(x: int, y: int) -> bool:
					return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(wheel_x, 13.5)) <= 2.5,
				func(x: int, y: int) -> Color:
					return HUB if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(wheel_x, 13.5)) < 1.0 else WHEEL)
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
func _bust() -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shape(image,
			func(x: int, y: int) -> bool:
				return pow((x + 0.5 - 8.0) / 6.5, 2) + pow((y + 0.5 - 16.5) / 7.0, 2) <= 1.0,
			func(x: int, _y: int) -> Color:
				return BUST_SHADE if x >= 10 else BUST,
			BUST_OUTLINE)
	_shape(image,
			func(x: int, y: int) -> bool:
				return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8.0, 5.0)) <= 4.4,
			func(x: int, _y: int) -> Color:
				return BUST_SHADE if x >= 9 else BUST,
			BUST_OUTLINE)
	return image


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
