extends SceneTree
## Génère les portraits en pixel art (32×32) des dirigeants des IA dans res://assets/portraits/, un par
## dirigeant de Leaders. Chaque portrait est un buste de face, composé de calques : cheveux de derrière
## (perruque, cheveux longs), vêtement, cou, tête, cheveux, barbe, couvre-chef et accessoires. Chaque
## dirigeant est décrit par quelques traits reconnaissables (voir LOOKS). Lumière venant d'en haut à
## gauche, contour sombre, fond transparent.
## À relancer après modification :
##   godot --headless --path . -s res://tools/generate_portraits.gd

const SIZE := 32
const OUT_DIR := "res://assets/portraits/"

## Teintes de peau : [clair, ombre, contour].
const SKINS := {
	"pale": [Color("f6dccb"), Color("dcb49c"), Color("8a5a48")],
	"light": [Color("eec5a4"), Color("d09c7a"), Color("7a4a34")],
	"rosy": [Color("f2c0a8"), Color("d8967c"), Color("7e4636")],
	"tan": [Color("dcae7e"), Color("bc8a5c"), Color("6a4224")],
	"brown": [Color("b07a50"), Color("8e5c38"), Color("4e2e18")],
	"dark": [Color("7c4c30"), Color("5e3620"), Color("2e1a0e")],
}
const OUTLINE := Color("2a1c14")
const EYE := Color("1e1410")
const LIP := Color("a05a4a")
const WHITE := Color("eeeae0")
const WHITE_SHADE := Color("c8c2b4")
const GOLD := Color("f0c040")
const GOLD_SHADE := Color("b8862a")
const LAUREL := [Color("4e8a32"), Color("74ae44")]
const FUR := [Color("6a4a2e"), Color("8e6a42"), Color("a8845a")]
const BLACK := Color("22201e")
const BLACK_SHINE := Color("4a4844")

## Apparence de chaque dirigeant : peau, cheveux (style, couleur), barbe, couvre-chef, vêtement (style,
## couleur, couleur d'accent), accessoire.
const LOOKS := {
	"alexander": {"skin": "light", "hair": ["curly", "d8a848"], "beard": "", "hat": "", "clothes": ["armor", "c08a3a", "b02a2a"], "extra": ""},
	"caesar": {"skin": "light", "hair": ["receding", "6a4a30"], "beard": "", "hat": "laurel", "clothes": ["toga", "eeeae0", "6a2a8a"], "extra": ""},
	"attila": {"skin": "tan", "hair": ["short", "1e1a18"], "beard": "goatee", "hat": "furhat", "clothes": ["fur", "6a4a2e", "8e6a42"], "extra": ""},
	"genghis": {"skin": "tan", "hair": ["short", "2a2420"], "beard": "thin", "hat": "mongol", "clothes": ["robe", "2a5a9a", "8e6a42"], "extra": ""},
	"ivan": {"skin": "light", "hair": ["long", "2a2018"], "beard": "long", "hat": "monomakh", "clothes": ["robe", "8a1e1e", "f0c040"], "extra": ""},
	"napoleon": {"skin": "light", "hair": ["short", "3a2a1e"], "beard": "", "hat": "bicorne", "clothes": ["coat", "2a3a8a", "f0c040"], "extra": ""},
	"mao": {"skin": "tan", "hair": ["short", "1a1816"], "beard": "", "hat": "", "clothes": ["maosuit", "7a7e78", "5e625c"], "extra": ""},
	"augustus": {"skin": "light", "hair": ["short", "7a5a38"], "beard": "", "hat": "laurel", "clothes": ["toga", "eeeae0", "b02a2a"], "extra": ""},
	"charlemagne": {"skin": "light", "hair": ["long", "e0ddd4"], "beard": "full", "hat": "crown", "clothes": ["robe", "9a2a2a", "f0c040"], "extra": ""},
	"elizabeth": {"skin": "pale", "hair": ["curly", "c8582a"], "beard": "", "hat": "tiara", "clothes": ["dress", "2a2a2e", "f0c040"], "extra": "ruff"},
	"louis_xiv": {"skin": "light", "hair": ["wig", "3a2618"], "beard": "mustache", "hat": "", "clothes": ["ermine", "2a3a9a", "f0c040"], "extra": ""},
	"lincoln": {"skin": "light", "hair": ["short", "2a2018"], "beard": "chin", "hat": "tophat", "clothes": ["suit", "22201e", "1e1a18"], "extra": ""},
	"taizong": {"skin": "tan", "hair": ["short", "1a1816"], "beard": "full", "hat": "futou", "clothes": ["robe", "d8a830", "8a2a1e"], "extra": ""},
	"churchill": {"skin": "rosy", "hair": ["bald", "c8b8a0"], "beard": "", "hat": "", "clothes": ["suit", "3a3e48", "2a4a8a"], "extra": "cigar"},
	"gandhi": {"skin": "brown", "hair": ["bald", "d8d4cc"], "beard": "mustache_white", "hat": "", "clothes": ["shawl", "eeeae0", "d8d0c0"], "extra": "glasses"},
	"mlk": {"skin": "dark", "hair": ["short", "1a1614"], "beard": "mustache", "hat": "", "clothes": ["suit", "2a2a30", "6a1e1e"], "extra": ""},
	"mandela": {"skin": "dark", "hair": ["short", "b8b4ac"], "beard": "", "hat": "", "clothes": ["madiba", "8a5a2a", "f0c040"], "extra": "smile"},
	"dalai_lama": {"skin": "tan", "hair": ["shaved", "4a3a2e"], "beard": "", "hat": "", "clothes": ["monk", "8a1e2a", "e8b830"], "extra": "glasses"},
	"saint_louis": {"skin": "light", "hair": ["bob", "a8783a"], "beard": "", "hat": "crown", "clothes": ["robe", "2a4a9a", "f0c040"], "extra": ""},
	"marcus_aurelius": {"skin": "light", "hair": ["curly", "6a4a2a"], "beard": "curly", "hat": "", "clothes": ["toga", "eeeae0", "6a2a8a"], "extra": ""},
	"confucius": {"skin": "tan", "hair": ["long", "c8c4bc"], "beard": "long", "hat": "scholar", "clothes": ["robe", "5a4a8a", "c8a060"], "extra": ""},
}

var _image: Image
var _skin: Array


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id in LOOKS:
		var path: String = OUT_DIR + id + ".png"
		_portrait(LOOKS[id]).save_png(ProjectSettings.globalize_path(path))
		print("Portrait généré : ", path)
	_unknown().save_png(ProjectSettings.globalize_path(OUT_DIR + "unknown.png"))
	print("Portrait généré : ", OUT_DIR + "unknown.png")
	quit()


func _portrait(look: Dictionary) -> Image:
	_image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_skin = SKINS[look.skin]
	var hair_color := Color(look.hair[1])
	if look.hair[0] in ["wig", "long", "bob"]:
		_back_hair(look.hair[0], hair_color)
	_clothes(look.clothes[0], Color(look.clothes[1]), Color(look.clothes[2]))
	if look.extra == "ruff":
		_ruff()
	_neck()
	_head(look.extra == "smile")
	_hair(look.hair[0], hair_color)
	_beard(look.beard, hair_color)
	_hat(look.hat)
	match look.extra:
		"glasses":
			_glasses()
		"cigar":
			_cigar()
	return _image


# --- Outils ---------------------------------------------------------------------------------------

func _plot(x: int, y: int, color: Color) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
		_image.set_pixel(x, y, color)


func _is_set(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE and _image.get_pixel(x, y).a > 0.0


## Remplit la forme `inside(x, y)` avec `fill(x, y)`, cernée de `outline` sur ses bords (sauf ceux qui
## touchent un pixel déjà dessiné, si `merge`).
func _shape(inside: Callable, fill: Callable, outline: Color = OUTLINE) -> void:
	var pixels: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if inside.call(x, y):
				pixels.append(Vector2i(x, y))
	for p in pixels:
		var border: bool = not (inside.call(p.x - 1, p.y) and inside.call(p.x + 1, p.y)
				and inside.call(p.x, p.y - 1) and inside.call(p.x, p.y + 1))
		_plot(p.x, p.y, outline if border else fill.call(p.x, p.y))


## Dans l'ellipse de centre `c` et de demi-axes `r` ?
static func _in_ellipse(x: int, y: int, c: Vector2, r: Vector2) -> bool:
	return pow((x + 0.5 - c.x) / r.x, 2) + pow((y + 0.5 - c.y) / r.y, 2) <= 1.0


## Centre et demi-axes de la tête.
const HEAD_C := Vector2(16.0, 14.0)
const HEAD_R := Vector2(6.2, 7.6)


func _in_head(x: int, y: int) -> bool:
	return _in_ellipse(x, y, HEAD_C, HEAD_R)


## Couleur `base` assombrie à droite (lumière d'en haut à gauche).
static func _lit(base: Color, x: int, from_x: float) -> Color:
	return base.darkened(0.25) if x + 0.5 > from_x else base


# --- Corps ----------------------------------------------------------------------------------------

func _neck() -> void:
	_shape(func(x: int, y: int) -> bool: return x >= 14 and x <= 18 and y >= 19 and y <= 24,
			func(x: int, _y: int) -> Color: return _skin[1] if x >= 17 else _skin[0], _skin[2])


func _head(smile: bool) -> void:
	# Oreilles, puis visage.
	for ear in [[8, 9], [22, 23]]:
		_shape(func(x: int, y: int) -> bool: return x >= ear[0] and x <= ear[1] and y >= 13 and y <= 16,
				func(_x: int, _y: int) -> Color: return _skin[1], _skin[2])
	_shape(_in_head, func(x: int, y: int) -> Color:
		if x >= 20 or (y >= 19 and x >= 18):
			return _skin[1]
		return _skin[0], _skin[2])
	# Sourcils, yeux, nez, bouche.
	for eye_x in [13, 19]:
		_plot(eye_x - 1, 12, _skin[2])
		_plot(eye_x, 12, _skin[2])
		_plot(eye_x, 14, EYE)
		_plot(eye_x - 1, 14, WHITE)
	_plot(16, 15, _skin[1])
	_plot(16, 16, _skin[1])
	_plot(17, 17, _skin[2])
	if smile:
		for x in range(14, 19):
			_plot(x, 19, LIP)
		_plot(15, 19, WHITE)
		_plot(16, 19, WHITE)
		_plot(17, 19, WHITE)
		_plot(13, 18, LIP)
		_plot(19, 18, LIP)
	else:
		for x in range(15, 18):
			_plot(x, 19, LIP)


## Vêtement : buste en trapèze sous le cou, selon le style.
func _clothes(style: String, base: Color, accent: Color) -> void:
	var inside := func(x: int, y: int) -> bool:
		if y < 22 or y > 31:
			return false
		var half := 7.0 + (y - 22) * 1.2
		return absf(x + 0.5 - 16.0) <= half
	_shape(inside, func(x: int, y: int) -> Color:
		var color := base
		match style:
			"toga":
				# Drapé en diagonale et bande colorée.
				if absi((x - 8) - (y - 22)) <= 1:
					color = accent
				elif (x + y) % 4 == 0 and x > 16:
					color = WHITE_SHADE
			"armor":
				color = base if (y - 22) % 3 != 0 else base.darkened(0.3)
				if x <= 7 or x >= 25:
					color = accent
			"coat":
				if absi(x - 16) <= 1 and y >= 23:
					color = WHITE
				elif absi(x - 16) == 2:
					color = accent
				if y <= 24 and (x <= 9 or x >= 23):
					color = accent
			"suit":
				if absi(x - 16) <= 2 - int(y >= 28) and y <= 28:
					color = WHITE
				if x == 16 and y >= 24 and y <= 29:
					color = accent
				if absi(x - 16) == 3 and y <= 27:
					color = base.lightened(0.15)
			"robe":
				if absi(absi(x - 16) - (y - 22)) <= 1 and y <= 29:
					color = accent
			"fur":
				if y <= 25:
					color = FUR[(x * 7 + y * 3) % 3]
			"dress":
				if absi(x - 16) <= 1:
					color = accent
				elif (x + y) % 5 == 0:
					color = accent.darkened(0.4)
			"ermine":
				if x <= 10 or x >= 22:
					color = WHITE if (x * 3 + y * 5) % 7 != 0 else BLACK
				elif absi(x - 16) <= 1:
					color = accent
			"madiba":
				color = accent if (x / 2 + y / 2) % 3 == 0 else (base if (x + y) % 2 == 0 else base.lightened(0.15))
			"maosuit":
				if x == 16 and (y - 23) % 2 == 0:
					color = accent
				if y <= 23 and absi(x - 16) <= 3:
					color = base.lightened(0.1)
			"shawl":
				if x >= 20 and y >= 24:
					color = _skin[0]
				elif (x - y) % 4 == 0:
					color = WHITE_SHADE
			"monk":
				if x >= 18 and absi((x - 18) - (y - 22)) <= 2:
					color = accent
		return _lit(color, x, 22.0))


## Fraise plissée blanche autour du cou.
func _ruff() -> void:
	_shape(func(x: int, y: int) -> bool: return _in_ellipse(x, y, Vector2(16.0, 22.5), Vector2(8.5, 3.2)),
			func(x: int, _y: int) -> Color: return WHITE_SHADE if x % 2 == 0 else WHITE)


# --- Cheveux et barbe ----------------------------------------------------------------------------

## Cheveux de derrière, dessinés avant la tête : perruque bouclée jusqu'aux épaules, cheveux longs, ou
## coupe au carré.
func _back_hair(style: String, color: Color) -> void:
	var bottom: int = {"wig": 28, "long": 24, "bob": 21}[style]
	var width: float = {"wig": 10.5, "long": 8.4, "bob": 8.6}[style]
	_shape(func(x: int, y: int) -> bool:
		if y < 5 or y > bottom:
			return false
		var half: float = width + (sin(y * 1.3) * 0.8 if style == "wig" else 0.0)
		return absf(x + 0.5 - 16.0) <= half and (y <= 14 or absf(x + 0.5 - 16.0) >= 4.5),
			func(x: int, y: int) -> Color:
				if style == "wig" and (x + y * 2) % 4 == 0:
					return color.lightened(0.25)
				return _lit(color, x, 20.0))


func _hair(style: String, color: Color) -> void:
	match style:
		"short", "wig", "long", "bob":
			_shape(func(x: int, y: int) -> bool:
				return _in_ellipse(x, y, HEAD_C + Vector2(0.0, -1.0), HEAD_R + Vector2(0.6, 0.0)) and (y <= 10 or (y <= 14 and absf(x + 0.5 - 16.0) >= 5.2)),
					func(x: int, _y: int) -> Color: return _lit(color, x, 19.0))
		"curly":
			_shape(func(x: int, y: int) -> bool:
				var bump := 0.7 if (x + y) % 3 == 0 else 0.0
				return _in_ellipse(x, y, HEAD_C + Vector2(0.0, -1.5), HEAD_R + Vector2(1.8 + bump, 1.0)) and (y <= 10 or (y <= 14 and absf(x + 0.5 - 16.0) >= 5.3)),
					func(x: int, y: int) -> Color:
						if (x * 3 + y) % 5 == 0:
							return color.lightened(0.3)
						return _lit(color, x, 19.0))
		"receding":
			_shape(func(x: int, y: int) -> bool:
				return _in_ellipse(x, y, HEAD_C + Vector2(0.0, -1.0), HEAD_R + Vector2(0.6, 0.0)) and (y <= 8 or (y <= 13 and absf(x + 0.5 - 16.0) >= 5.3)),
					func(x: int, _y: int) -> Color: return _lit(color, x, 19.0))
		"bald":
			# Quelques cheveux sur les tempes.
			for side in [-1, 1]:
				_shape(func(x: int, y: int) -> bool: return absf(x + 0.5 - 16.0 - side * 5.8) <= 0.9 and y >= 10 and y <= 13,
						func(_x: int, _y: int) -> Color: return color)
		"shaved":
			_shape(func(x: int, y: int) -> bool:
				return _in_head(x, y) and y <= 8,
					func(x: int, _y: int) -> Color: return _lit(color.lerp(_skin[1], 0.5), x, 19.0), _skin[2])


func _beard(style: String, color: Color) -> void:
	match style:
		"full", "long", "curly":
			var bottom: int = {"full": 24, "long": 28, "curly": 23}[style]
			_shape(func(x: int, y: int) -> bool:
				var on_face: bool = _in_ellipse(x, y, HEAD_C + Vector2(0.0, 1.5), HEAD_R + Vector2(0.4, 0.8)) and y >= 16
				var below: bool = y >= 20 and y <= bottom and absf(x + 0.5 - 16.0) <= 5.0 - (y - 20) * (0.6 if style == "long" else 1.0)
				return (on_face or below) and not (y == 19 and absi(x - 16) <= 1),
					func(x: int, y: int) -> Color:
						if style == "curly" and (x + y) % 3 == 0:
							return color.lightened(0.3)
						return _lit(color, x, 19.0))
			_mustache(color)
		"goatee":
			_shape(func(x: int, y: int) -> bool: return absi(x - 16) <= 1 and y >= 20 and y <= 23,
					func(x: int, _y: int) -> Color: return _lit(color, x, 17.0))
			_mustache(color)
		"thin":
			_mustache(color)
			for y in range(19, 23):
				_plot(13, y, color)
				_plot(19, y, color)
			_plot(16, 21, color)
			_plot(16, 22, color)
		"chin":
			_shape(func(x: int, y: int) -> bool:
				return _in_ellipse(x, y, HEAD_C + Vector2(0.0, 1.8), HEAD_R + Vector2(0.5, 1.0)) and y >= 18 and not (y <= 20 and absi(x - 16) <= 2),
					func(x: int, _y: int) -> Color: return _lit(color, x, 19.0))
		"mustache":
			_mustache(color)
		"mustache_white":
			_mustache(WHITE_SHADE)


func _mustache(color: Color) -> void:
	for x in range(14, 19):
		_plot(x, 18, color)
	_plot(13, 19, color)
	_plot(19, 19, color)


# --- Couvre-chefs et accessoires -------------------------------------------------------------------

func _hat(style: String) -> void:
	match style:
		"laurel":
			for x in range(9, 24):
				var y := 9 - roundi(sqrt(maxf(0.0, 1.0 - pow((x + 0.5 - 16.0) / 7.5, 2))) * 3.0)
				_plot(x, y, LAUREL[x % 2])
				_plot(x, y + 1, LAUREL[(x + 1) % 2].darkened(0.2))
				if x % 2 == 0:
					_plot(x, y - 1, LAUREL[1])
		"crown", "tiara":
			var top := 3 if style == "crown" else 5
			_shape(func(x: int, y: int) -> bool:
				if x < 10 or x > 22 or y > 8:
					return false
				if y >= 6:
					return true
				return y >= top and (x - 10) % 4 == 0 or (y >= top + 1 and (x - 10) % 4 <= 1),
					func(x: int, _y: int) -> Color: return _lit(GOLD, x, 19.0), GOLD_SHADE.darkened(0.4))
			_plot(16, 7, Color("c02a2a"))
			_plot(12, 7, Color("2a6ac0"))
			_plot(20, 7, Color("2a6ac0"))
		"bicorne":
			# Bicorne porté « en bataille » : grand croissant noir, pointes sur les côtés.
			_shape(func(x: int, y: int) -> bool:
				return _in_ellipse(x, y, Vector2(16.0, 9.0), Vector2(13.5, 7.5)) and y <= 8,
					func(x: int, y: int) -> Color: return BLACK_SHINE if y <= 4 and x < 14 else BLACK)
			for x in range(4, 29):
				_plot(x, 8, GOLD_SHADE)
			_plot(16, 4, Color("2a4ac0"))
			_plot(16, 5, WHITE)
			_plot(16, 6, Color("c02a2a"))
		"tophat":
			_shape(func(x: int, y: int) -> bool:
				return (x >= 11 and x <= 21 and y >= 0 and y <= 7) or (x >= 8 and x <= 24 and y >= 7 and y <= 8),
					func(x: int, y: int) -> Color:
						if y == 6:
							return BLACK_SHINE
						return BLACK_SHINE if x == 12 else BLACK)
		"furhat":
			_shape(func(x: int, y: int) -> bool: return x >= 8 and x <= 24 and y >= 1 and y <= 8,
					func(x: int, y: int) -> Color: return FUR[(x * 5 + y * 3) % 3])
		"mongol":
			_shape(func(x: int, y: int) -> bool: return absf(x + 0.5 - 16.0) <= (y - 0.5) * 1.3 and y >= 1 and y <= 6,
					func(x: int, _y: int) -> Color: return _lit(Color("b02a2a"), x, 18.0))
			_shape(func(x: int, y: int) -> bool: return x >= 8 and x <= 24 and y >= 6 and y <= 9,
					func(x: int, y: int) -> Color: return FUR[(x * 5 + y * 3) % 3])
		"monomakh":
			_shape(func(x: int, y: int) -> bool: return _in_ellipse(x, y, Vector2(16.0, 7.0), Vector2(6.0, 5.0)) and y <= 7,
					func(x: int, y: int) -> Color: return GOLD_SHADE if (x + y) % 3 == 0 else _lit(GOLD, x, 18.0), GOLD_SHADE.darkened(0.4))
			_shape(func(x: int, y: int) -> bool: return x >= 8 and x <= 24 and y >= 7 and y <= 9,
					func(x: int, y: int) -> Color: return FUR[(x * 5 + y * 3) % 3])
			_plot(16, 0, GOLD)
			_plot(15, 1, GOLD)
			_plot(16, 1, GOLD)
			_plot(17, 1, GOLD)
		"futou":
			_shape(func(x: int, y: int) -> bool:
				return (_in_ellipse(x, y, Vector2(16.0, 7.0), Vector2(6.5, 5.0)) and y <= 8) or (y == 6 and absi(x - 16) <= 13),
					func(x: int, _y: int) -> Color: return BLACK_SHINE if x < 14 else BLACK)
		"scholar":
			_shape(func(x: int, y: int) -> bool: return x >= 13 and x <= 19 and y >= 1 and y <= 6,
					func(x: int, _y: int) -> Color: return BLACK_SHINE if x < 15 else BLACK)
			for x in range(11, 22):
				_plot(x, 6, BLACK)


## Lunettes rondes cerclées de sombre autour des yeux.
func _glasses() -> void:
	for eye_x in [13, 19]:
		for p in [Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -1), Vector2i(1, 0),
				Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-2, 0)]:
			_plot(eye_x + p.x, 14 + p.y, BLACK)
	_plot(15, 14, BLACK)
	_plot(16, 14, BLACK)
	_plot(17, 14, BLACK)


## Cigare au coin de la bouche, cendre et volute de fumée.
func _cigar() -> void:
	for x in range(18, 24):
		_plot(x, 19, Color("6a3a1e"))
		_plot(x, 20, Color("4a2814"))
	_plot(24, 19, Color("e85a2a"))
	_plot(24, 20, Color("9a9a9a"))
	_plot(25, 17, Color(0.85, 0.85, 0.85, 0.7))
	_plot(26, 15, Color(0.85, 0.85, 0.85, 0.5))
	_plot(25, 13, Color(0.85, 0.85, 0.85, 0.35))


## Portrait d'un dirigeant pas encore rencontré : silhouette grise, marquée d'un point d'interrogation.
func _unknown() -> Image:
	const MARK := [
		".XXX.",
		"X...X",
		"....X",
		"...X.",
		"..X..",
		"..X..",
		".....",
		"..X..",
	]
	_image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var body := Color("6a6a70")
	var shade := Color("54545a")
	_shape(func(x: int, y: int) -> bool:
		return y >= 22 and y <= 31 and absf(x + 0.5 - 16.0) <= 7.0 + (y - 22) * 1.2,
			func(x: int, _y: int) -> Color: return shade if x >= 20 else body)
	_shape(func(x: int, y: int) -> bool: return x >= 14 and x <= 18 and y >= 19 and y <= 24,
			func(_x: int, _y: int) -> Color: return shade)
	_shape(_in_head, func(x: int, _y: int) -> Color: return shade if x >= 20 else body)
	for row in MARK.size():
		for column in 5:
			if MARK[row][column] == "X":
				_plot(14 + column, 9 + row, WHITE)
	return _image
