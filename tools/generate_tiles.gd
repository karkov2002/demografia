extends SceneTree
## Génère les tuiles de terrain en pixel art (hexagones pointe en haut) dans res://assets/tiles/, au format
## TILE_SIZE (84×96) ; la montagne et la colline viennent d'images peintes à la main (voir SOURCE_DIR).
## Style doux : palettes en dégradé peu saturées, bruit lissé plutôt que pixels isolés, lumière venant
## d'en haut à gauche, tramage ordonné pour adoucir le passage d'une nuance à l'autre.
## À relancer après modification :
##   godot --headless --path . -s res://tools/generate_tiles.gd

const RADIUS := 24
const WIDTH := 42
const HEIGHT := 48
const OUT_DIR := "res://assets/tiles/"
## Taille de toutes les tuiles enregistrées. Les tuiles dessinées par ce script le sont à WIDTH × HEIGHT,
## puis agrandies sans lissage (chaque pixel doublé, même rendu à l'écran) ; les tuiles peintes à la main
## (images d'origine dans SOURCE_DIR, dossier ignoré par Godot pour ne pas importer ces grandes images)
## y sont réduites. Elles remplaceront peu à peu les tuiles dessinées.
const SOURCE_DIR := "res://assets/tiles/sources/"
const TILE_SIZE := Vector2i(84, 96)

## Nuances du plus sombre au plus clair.
const PRAIRIE_RAMP := ["2f5d3a", "3b7043", "4a8248", "5c9450", "72a65a", "8bb866", "a7c97a"]
const FLOWERS := ["f2d479", "e8a0a8", "f4efd8"]
const WATER_RAMP := ["1e4f7a", "25628f", "2e76a3", "3a8bb5", "4f9fc4", "6db4d2", "93cadf"]
const FOG_RAMP := ["2b2f3a", "343947", "3e4454", "4a5163", "575f73"]
const FOAM := "e3f1f5"
## Forêt : sous-bois sombre et frondaisons rondes (du creux d'ombre au reflet de lumière).
const UNDERGROWTH_RAMP := ["24452c", "2c5233", "355f3b", "406c43"]
const CANOPY_RAMP := ["1f4a2a", "2a5e33", "387340", "4c8a4c", "68a35a", "86b96b"]
const TRUNK := "4a3424"
## Marais : sol vaseux, mares sombres, roseaux et massettes.
const MARSH_RAMP := ["3a4430", "445036", "4f5c3c", "5b6943", "68774b"]
const POOL_RAMP := ["26403f", "2e4f4b", "3a5f58", "4f766b", "6f9585"]
const REED := ["556b2f", "7a8f3e", "9aab52"]
const CATTAIL := "6b4a2a"

## Matrice de Bayer 4×4, pour le tramage ordonné.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_prairie(), "prairie")
	_save(_from_source("mountain"), "mountain")
	_save(_water(), "water")
	_save(_forest(), "forest")
	_save(_from_source("hill"), "hill")
	_save(_marsh(), "marsh")
	_save(_fog(), "fog")
	quit()


## Enregistre `image` au format des tuiles (TILE_SIZE), agrandie sans lissage si besoin.
func _save(image: Image, name: String) -> void:
	if image.get_size() != TILE_SIZE:
		image.resize(TILE_SIZE.x, TILE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var path := OUT_DIR + name + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	print("Tuile générée : ", path)


## Le pixel (x, y) est-il dans l'hexagone ? Sert à placer les motifs (fleurs, reflets…) loin des bords.
func _inside(x: int, y: int) -> bool:
	var dx := absf(x + 0.5 - WIDTH / 2.0)
	var dy := absf(y + 0.5 - HEIGHT / 2.0)
	return dx <= WIDTH / 2.0 and dy <= RADIUS - dx / sqrt(3.0)


## L'image entière est peinte, coins compris : le jeu découpe lui-même l'hexagone, et un bord
## transparent y ferait apparaître des trous.
func _plot(image: Image, x: int, y: int, color: String) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, Color(color))


## Nuance de `ramp` pour une valeur de 0 à 1, tramée selon la position du pixel.
func _shade(ramp: Array, value: float, x: int, y: int) -> String:
	var dither: float = (BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.5) * 0.6
	var index := clampi(floori(value * ramp.size() + dither), 0, ramp.size() - 1)
	return ramp[index]


## Lumière venant d'en haut à gauche : +`strength`/2 dans ce coin, -`strength`/2 à l'opposé.
func _light(x: int, y: int, strength: float) -> float:
	return (0.5 - (float(x) / WIDTH + float(y) / HEIGHT) / 2.0) * strength


## Bruit de valeur lissé (deux octaves), de 0 à 1 : des taches douces plutôt que des pixels isolés.
class SmoothNoise:
	var _grids: Array = []
	var _steps := [8.0, 4.0]
	var _weights := [0.65, 0.35]

	func _init(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for step in _steps:
			var grid := []
			for i in 16 * 16:
				grid.append(rng.randf())
			_grids.append(grid)

	func sample(x: float, y: float) -> float:
		var total := 0.0
		for octave in _grids.size():
			var fx: float = x / _steps[octave]
			var fy: float = y / _steps[octave]
			var ix := floori(fx)
			var iy := floori(fy)
			var tx := smoothstep(0.0, 1.0, fx - ix)
			var ty := smoothstep(0.0, 1.0, fy - iy)
			var top := lerpf(_at(octave, ix, iy), _at(octave, ix + 1, iy), tx)
			var bottom := lerpf(_at(octave, ix, iy + 1), _at(octave, ix + 1, iy + 1), tx)
			total += lerpf(top, bottom, ty) * _weights[octave]
		return total

	func _at(octave: int, ix: int, iy: int) -> float:
		return _grids[octave][posmod(iy, 16) * 16 + posmod(ix, 16)]


## Hexagone rempli de `ramp` selon un bruit lissé, éclairé d'en haut à gauche.
func _textured(seed_value: int, ramp: Array, light: float) -> Image:
	var noise := SmoothNoise.new(seed_value)
	var image := Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			var value := noise.sample(x, y) + _light(x, y, light)
			_plot(image, x, y, _shade(ramp, value, x, y))
	return image


## Position au hasard, assez loin des bords pour y dessiner un petit motif.
func _random_spot(rng: RandomNumberGenerator, border: int) -> Vector2i:
	while true:
		var spot := Vector2i(rng.randi_range(border, WIDTH - 1 - border), rng.randi_range(border, HEIGHT - 1 - border))
		if _inside(spot.x - border, spot.y) and _inside(spot.x + border, spot.y) \
				and _inside(spot.x, spot.y - border) and _inside(spot.x, spot.y + border):
			return spot
	return Vector2i.ZERO


func _prairie() -> Image:
	var image := _textured(1, PRAIRIE_RAMP, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Brins d'herbe clairs, ombrés à leur pied.
	for i in 14:
		var spot := _random_spot(rng, 2)
		_plot(image, spot.x, spot.y, PRAIRIE_RAMP[6])
		_plot(image, spot.x - 1, spot.y + 1, PRAIRIE_RAMP[5])
		_plot(image, spot.x, spot.y + 1, PRAIRIE_RAMP[2])
	# Quelques fleurs pastel, avec un pixel d'ombre.
	for i in 6:
		var spot := _random_spot(rng, 2)
		_plot(image, spot.x, spot.y, FLOWERS[i % FLOWERS.size()])
		_plot(image, spot.x, spot.y + 1, PRAIRIE_RAMP[1])
	return image


func _water() -> Image:
	var image := _textured(3, WATER_RAMP, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	# Reflets en arc allongé, clairs au sommet, sombres dessous.
	for i in 9:
		var spot := _random_spot(rng, 3)
		for dx in range(-2, 3):
			var lift := 1 if absi(dx) <= 1 else 0
			_plot(image, spot.x + dx, spot.y - lift, WATER_RAMP[6] if absi(dx) < 2 else WATER_RAMP[5])
			_plot(image, spot.x + dx, spot.y - lift + 1, WATER_RAMP[2])
		if i % 3 == 0:
			_plot(image, spot.x, spot.y - 1, FOAM)
	return image


## Tuile peinte à la main `name` : l'image d'origine de SOURCE_DIR, réduite à TILE_SIZE (filtre de
## Lanczos, qui garde le détail sans crénelage).
func _from_source(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + name + ".png"))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(TILE_SIZE.x, TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return image


## Brouillard de guerre : nappes grises bleutées, sans lumière directionnelle.
func _fog() -> Image:
	return _textured(4, FOG_RAMP, 0.0)


## Forêt : sous-bois sombre couvert de frondaisons rondes qui se chevauchent, des plus lointaines (en
## haut) aux plus proches, chacune éclairée en haut à gauche, avec l'ombre de son tronc au pied.
func _forest() -> Image:
	var image := _textured(5, UNDERGROWTH_RAMP, 0.25)
	var noise := SmoothNoise.new(55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var crowns: Array[Vector2i] = []
	for i in 70:
		crowns.append(_random_spot(rng, 4))
	crowns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for crown in crowns:
		var radius := rng.randf_range(3.0, 4.6)
		_plot(image, crown.x, crown.y + roundi(radius), TRUNK)
		_plot(image, crown.x + 1, crown.y + roundi(radius) + 1, UNDERGROWTH_RAMP[0])
		for y in range(crown.y - 5, crown.y + 5):
			for x in range(crown.x - 5, crown.x + 5):
				var offset := Vector2(x + 0.5 - crown.x, y + 0.5 - crown.y)
				if offset.length() > radius:
					continue
				# Lumière d'en haut à gauche sur le dôme, assombri vers le bas à droite.
				var value := 0.62 - (offset.x + offset.y) / (radius * 3.2) + (noise.sample(x * 1.5, y * 1.5) - 0.5) * 0.3
				if offset.length() > radius - 1.0 and offset.x + offset.y > 0.0:
					value -= 0.25
				_plot(image, x, y, _shade(CANOPY_RAMP, value, x, y))
	return image


## Marais : sol vaseux, mares sombres aux reflets clairs, touffes de roseaux et massettes brunes.
func _marsh() -> Image:
	var image := _textured(7, MARSH_RAMP, 0.25)
	var noise := SmoothNoise.new(77)
	for pool in [[Vector2(13.0, 17.0), 7.5, 4.0], [Vector2(28.0, 25.0), 8.5, 4.5], [Vector2(16.0, 34.0), 7.0, 3.5]]:
		var center: Vector2 = pool[0]
		var radii := Vector2(pool[1], pool[2])
		for y in range(int(center.y - radii.y) - 1, int(center.y + radii.y) + 2):
			for x in range(int(center.x - radii.x) - 1, int(center.x + radii.x) + 2):
				var offset := (Vector2(x + 0.5, y + 0.5) - center) / radii
				var edge := offset.length() + (noise.sample(x * 2.0, y * 2.0) - 0.5) * 0.4
				if edge > 1.0:
					continue
				var value := 0.35 + offset.y * 0.2 + (noise.sample(x, y) - 0.5) * 0.2
				if edge > 0.85:
					value = 0.05
				_plot(image, x, y, _shade(POOL_RAMP, value, x, y))
		# Reflet du ciel sur l'eau.
		for dx in range(-1, 2):
			_plot(image, int(center.x) + dx - 1, int(center.y) - 1, POOL_RAMP[4])
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	for i in 9:
		var spot := _random_spot(rng, 4)
		for blade in [-1, 0, 1]:
			var height := 3 + (1 if blade == 0 else 0)
			for k in height:
				_plot(image, spot.x + blade, spot.y - k, REED[clampi(k, 0, REED.size() - 1)])
		if i % 2 == 0:
			_plot(image, spot.x, spot.y - 4, CATTAIL)
			_plot(image, spot.x, spot.y - 5, CATTAIL)
	return image
