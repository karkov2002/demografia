extends SceneTree
## Génère les tuiles de terrain en pixel art (hexagones pointe en haut, 42×48) dans res://assets/tiles/.
## Style doux : palettes en dégradé peu saturées, bruit lissé plutôt que pixels isolés, lumière venant
## d'en haut à gauche, tramage ordonné pour adoucir le passage d'une nuance à l'autre.
## À relancer après modification :
##   godot --headless --path . -s res://tools/generate_tiles.gd

const RADIUS := 24
const WIDTH := 42
const HEIGHT := 48
const OUT_DIR := "res://assets/tiles/"

## Nuances du plus sombre au plus clair.
const PRAIRIE_RAMP := ["2f5d3a", "3b7043", "4a8248", "5c9450", "72a65a", "8bb866", "a7c97a"]
const FLOWERS := ["f2d479", "e8a0a8", "f4efd8"]
const GROUND_RAMP := ["44533a", "4f6140", "5b6e47", "687b50", "788a5c"]
const ROCK_RAMP := ["464b62", "565d78", "6a7290", "8088a3", "9aa1b8", "b4bacb"]
const SNOW_RAMP := ["c3cedb", "dfe6ef", "f4f7fa"]
const WATER_RAMP := ["1e4f7a", "25628f", "2e76a3", "3a8bb5", "4f9fc4", "6db4d2", "93cadf"]
const FOG_RAMP := ["2b2f3a", "343947", "3e4454", "4a5163", "575f73"]
const FOAM := "e3f1f5"

## Matrice de Bayer 4×4, pour le tramage ordonné.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_prairie(), "prairie")
	_save(_mountain(), "mountain")
	_save(_water(), "water")
	_save(_fog(), "fog")
	quit()


func _save(image: Image, name: String) -> void:
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


func _mountain() -> Image:
	var image := _textured(2, GROUND_RAMP, 0.3)
	var noise := SmoothNoise.new(22)
	_peak(image, noise, 29, 15, 37, 10, 6)
	_peak(image, noise, 18, 6, 39, 16, 11)
	return image


## Pic rocheux : face gauche éclairée, face droite dans l'ombre, dégradé selon la distance à l'arête,
## calotte de neige au bord irrégulier sur les `snow_depth` premières rangées.
func _peak(image: Image, noise: SmoothNoise, apex_x: int, apex_y: int, base_y: int, half_width: int,
		snow_depth: int) -> void:
	for y in range(apex_y, base_y + 1):
		var half := roundi(float(y - apex_y) / (base_y - apex_y) * half_width)
		for x in range(apex_x - half, apex_x + half + 1):
			# 0 sur l'arête, 1 sur le bord du pic.
			var from_ridge := absf(x - apex_x) / maxf(1.0, half)
			var texture := (noise.sample(x, y) - 0.5) * 0.35
			var value: float
			if x <= apex_x:
				value = 0.95 - from_ridge * 0.35 + texture
			else:
				value = 0.4 - from_ridge * 0.3 + texture
			var snow_line := snow_depth + roundi((noise.sample(x * 2.0, 3.0) - 0.5) * 4.0)
			if y - apex_y < snow_line:
				_plot(image, x, y, _shade(SNOW_RAMP, value, x, y))
			elif x == apex_x - half or x == apex_x + half or y == base_y:
				_plot(image, x, y, ROCK_RAMP[0])
			else:
				_plot(image, x, y, _shade(ROCK_RAMP, value, x, y))


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


## Brouillard de guerre : nappes grises bleutées, sans lumière directionnelle.
func _fog() -> Image:
	return _textured(4, FOG_RAMP, 0.0)
