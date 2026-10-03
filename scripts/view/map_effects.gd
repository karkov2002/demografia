class_name MapEffects
extends RefCounted
## Effets éphémères posés sur les cases de la carte, dessinés par-dessus tout le reste :
## - VICTORY, DEFEAT, COLONY, CITY, VILLAGE : un picto et son titre surgissent de la case, montent et
##   s'effacent en fondu, sur des feux d'artifice (victoire, ville fondée), une pluie de braises (défaite,
##   ville redevenue village) ou une onde et des étincelles (terre conquise) ;
## - DESTROYED : un joueur ennemi vient d'être détruit ; comme VICTORY, mais en grand au centre de la carte
##   (sans case), avec le titre donné ;
## - FLASH : éclair blanc et onde à la couleur du nouveau propriétaire, quand une case change de main
##   par la guerre ;
## - BOOST : « +N » qui s'envole de la case.

enum Kind { VICTORY, DEFEAT, COLONY, CITY, VILLAGE, DESTROYED, FLASH, BOOST }

## Durée (s) de chaque effet.
const DURATIONS := {Kind.VICTORY: 2.4, Kind.DEFEAT: 2.4, Kind.COLONY: 2.0, Kind.CITY: 2.4, Kind.VILLAGE: 2.0,
		Kind.DESTROYED: 3.5, Kind.FLASH: 0.7, Kind.BOOST: 0.8}
## Titre de chaque effet (clé de texte, voir Locale).
const LABELS := {Kind.VICTORY: "EFFECT_VICTORY", Kind.DEFEAT: "EFFECT_DEFEAT", Kind.COLONY: "EFFECT_COLONY",
		Kind.CITY: "EFFECT_CITY", Kind.VILLAGE: "EFFECT_VILLAGE", Kind.DESTROYED: "EFFECT_DESTROYED"}
const LABEL_COLORS := {
	Kind.VICTORY: Color("ffd84a"),
	Kind.DEFEAT: Color("ff5a4a"),
	Kind.COLONY: Color("7cf06a"),
	Kind.CITY: Color("d8a8ff"),
	Kind.VILLAGE: Color("c8b89a"),
	Kind.DESTROYED: Color("ffd84a"),
}
const FIREWORK_COLORS := [Color("ffd84a"), Color("ff5ad2"), Color("5ae0ff"), Color("ffffff"), Color("9cff5a")]
const EMBER_COLORS := [Color("ff5a2a"), Color("ffa030"), Color("8a8480"), Color("c83c32")]
const SPARKLE_COLORS := [Color("7cf06a"), Color("ffd84a"), Color("e8ffd0")]
const BOOST_COLOR := Color("ffc233")

var _effects: Array[Dictionary] = []


## Ajoute un effet `kind` sur `cell`, dans la couleur `color` (onde du flash et de la terre conquise),
## avec le texte `text` (celui de BOOST, ou un titre qui remplace le titre habituel).
func add(kind: Kind, cell: Vector2i, color: Color = Color.WHITE, text: String = "") -> void:
	_effects.append({"kind": kind, "cell": cell, "start": _now(), "color": color, "text": text, "seed": randi()})


func is_empty() -> bool:
	return _effects.is_empty()


## Dessine les effets en cours (les flashs d'abord, sous les autres) et oublie ceux qui sont finis.
## `center_of` donne le centre d'une case à l'écran, `radius` le rayon des cases.
func draw(canvas: CanvasItem, font: Font, center_of: Callable, radius: float) -> void:
	var now := _now()
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return now - effect.start < DURATIONS[effect.kind])
	var destroyed_rank := 0
	for pass_flash in [true, false]:
		for effect in _effects:
			if (effect.kind == Kind.FLASH) != pass_flash:
				continue
			var t: float = (now - effect.start) / DURATIONS[effect.kind]
			if effect.kind == Kind.DESTROYED:
				# En grand, au centre de la carte ; plusieurs annonces à la fois s'empilent vers le bas.
				var area: Vector2 = (canvas as Control).size
				var big := minf(area.x, area.y) * 0.12
				_draw_event(canvas, font, area / 2.0 + Vector2(0.0, destroyed_rank * big * 2.2), big, t, effect)
				destroyed_rank += 1
				continue
			var center: Vector2 = center_of.call(effect.cell)
			match effect.kind:
				Kind.FLASH:
					_draw_flash(canvas, center, radius, t, effect.color)
				Kind.BOOST:
					var rise := center - Vector2(0.0, radius * (0.2 + 0.8 * t))
					_text(canvas, font, effect.text, rise, int(radius * 0.4), BOOST_COLOR, 1.0 - t * t)
				_:
					_draw_event(canvas, font, center, radius, t, effect)


## Éclair blanc sur la case, et onde hexagonale à la couleur `color` qui s'élargit.
func _draw_flash(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color) -> void:
	canvas.draw_colored_polygon(HexUtils.hex_points(center, radius), Color(1.0, 1.0, 1.0, 0.85 * pow(1.0 - t, 2.0)))
	var ring := HexUtils.closed(HexUtils.hex_points(center, radius * (1.0 + 0.7 * t)))
	canvas.draw_polyline(ring, Color(color, 1.0 - t), maxf(1.0, radius * 0.12 * (1.0 - t)), true)


## Victoire, défaite ou terre conquise : particules, puis picto et titre qui surgissent (petit rebond),
## montent et s'effacent en fondu ; le picto de la défaite vacille.
func _draw_event(canvas: CanvasItem, font: Font, center: Vector2, radius: float, t: float, effect: Dictionary) -> void:
	var kind: Kind = effect.kind
	var rng := RandomNumberGenerator.new()
	rng.seed = effect.seed
	match kind:
		Kind.VICTORY, Kind.CITY, Kind.DESTROYED:
			_draw_fireworks(canvas, center, radius, t, rng)
		Kind.DEFEAT, Kind.VILLAGE:
			_draw_embers(canvas, center, radius, t, rng)
		Kind.COLONY:
			_draw_sparkles(canvas, center, radius, t, rng, effect.color)
	var alpha := 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.3
	var scale := 1.0
	if t < 0.12:
		scale = lerpf(0.3, 1.3, t / 0.12)
	elif t < 0.22:
		scale = lerpf(1.3, 1.0, (t - 0.12) / 0.1)
	var position := center - Vector2(0.0, radius * 1.1 * (1.0 - pow(1.0 - t, 2.0)))
	var label_color: Color = LABEL_COLORS[kind]
	# Halo qui pulse derrière le picto, et rayons tournants pour la victoire.
	var pulse := 0.5 + 0.5 * sin(t * TAU * 3.0)
	if kind in [Kind.VICTORY, Kind.DESTROYED]:
		for ray in 10:
			var angle := t * 2.0 + ray * TAU / 10.0
			var tip := position + Vector2.from_angle(angle) * radius * 1.1 * scale
			var side := Vector2.from_angle(angle + PI / 2.0) * radius * 0.12 * scale
			canvas.draw_colored_polygon(PackedVector2Array([position, tip + side, tip - side]),
					Color(label_color, 0.28 * alpha))
	for layer in 5:
		canvas.draw_circle(position, radius * scale * (0.75 - layer * 0.12) * (0.9 + 0.2 * pulse),
				Color(label_color, 0.12 * alpha))
	var icon: Texture2D = {Kind.VICTORY: Icons.VICTORY, Kind.DESTROYED: Icons.VICTORY, Kind.DEFEAT: Icons.DEFEAT,
			Kind.COLONY: Icons.COLONY, Kind.CITY: Icons.settlement_icon(1), Kind.VILLAGE: Icons.settlement_icon(0)}[kind]
	# Les icônes de la ville et du village, en niveaux de gris, prennent la couleur du joueur.
	var tint: Color = effect.color if kind in [Kind.CITY, Kind.VILLAGE] else Color.WHITE
	var wobble := sin(t * 28.0) * 0.3 * (1.0 - t) if kind == Kind.DEFEAT else 0.0
	var size := Vector2.ONE * radius * 1.0
	canvas.draw_set_transform(position, wobble, Vector2.ONE * scale)
	canvas.draw_texture_rect(icon, Rect2(-size / 2.0, size), false, Color(tint, alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# `text`, s'il est donné, remplace le titre habituel.
	var label: String = effect.text if effect.text != "" else Locale.text(LABELS[kind])
	_text(canvas, font, label, position + Vector2(0.0, size.y * 0.7 * scale), int(radius * 0.32 * scale),
			label_color, alpha)


## Feux d'artifice : quatre gerbes décalées dans le temps, en haut de la case, chacune d'une couleur,
## dont les étincelles filent en traînées puis retombent.
func _draw_fireworks(canvas: CanvasItem, center: Vector2, radius: float, t: float, rng: RandomNumberGenerator) -> void:
	for burst in 4:
		var start := 0.05 + burst * 0.18
		var origin := center + Vector2(rng.randf_range(-1.2, 1.2), -rng.randf_range(0.5, 1.6)) * radius
		var color: Color = FIREWORK_COLORS[rng.randi() % FIREWORK_COLORS.size()]
		var sparks := 14
		var local := (t - start) / 0.4
		if local < 0.0 or local > 1.0:
			for i in sparks:
				rng.randf()  # même tirage à chaque image, que la gerbe soit visible ou non
			continue
		if local < 0.25:
			canvas.draw_circle(origin, radius * 0.18 * (1.0 - local * 4.0), Color(1.0, 1.0, 1.0, 0.9))
		for i in sparks:
			var direction := Vector2.from_angle(i * TAU / sparks + rng.randf() * 0.3)
			var reach := radius * 0.7 * (1.0 - pow(1.0 - local, 2.0))
			var spark := origin + direction * reach + Vector2(0.0, radius * 0.25 * local * local)
			var trail := spark - direction * radius * 0.18 * (1.0 - local)
			var fade := Color(color, 1.0 - local)
			canvas.draw_line(trail, spark, fade, maxf(1.0, radius * 0.04), true)
			canvas.draw_circle(spark, maxf(1.0, radius * 0.05 * (1.0 - local)), Color(Color.WHITE.lerp(color, 0.4), 1.0 - local))


## Pluie de braises rougeoyantes et de cendres qui tombent en scintillant, et fumée sombre qui s'étale.
func _draw_embers(canvas: CanvasItem, center: Vector2, radius: float, t: float, rng: RandomNumberGenerator) -> void:
	for puff in 3:
		var spot := center + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.3)) * radius
		canvas.draw_circle(spot, radius * (0.25 + 0.5 * t), Color(0.15, 0.12, 0.12, 0.35 * (1.0 - t)))
	for i in 22:
		var start := rng.randf() * 0.5
		var x := rng.randf_range(-0.9, 0.9) * radius
		var speed := rng.randf_range(0.6, 1.3)
		var color: Color = EMBER_COLORS[rng.randi() % EMBER_COLORS.size()]
		var local := (t - start) / 0.5
		if local < 0.0 or local > 1.0:
			continue
		var ember := center + Vector2(x + sin(local * 9.0 + i) * radius * 0.08, -radius * 0.6 + radius * 1.3 * speed * local)
		var flicker := 0.6 + 0.4 * sin(local * 40.0 + i)
		canvas.draw_circle(ember, maxf(1.0, radius * 0.045), Color(color, (1.0 - local) * flicker))


## Onde hexagonale à la couleur du joueur, et étincelles vertes et dorées qui montent en tourbillon.
func _draw_sparkles(canvas: CanvasItem, center: Vector2, radius: float, t: float, rng: RandomNumberGenerator,
		color: Color) -> void:
	if t < 0.5:
		var wave := t / 0.5
		var ring := HexUtils.closed(HexUtils.hex_points(center, radius * (0.3 + 0.9 * wave)))
		canvas.draw_polyline(ring, Color(color.lerp(Color.WHITE, 0.3), 1.0 - wave), maxf(1.0, radius * 0.1 * (1.0 - wave)), true)
	for i in 18:
		var start := rng.randf() * 0.45
		var angle := rng.randf() * TAU
		var color_i: Color = SPARKLE_COLORS[rng.randi() % SPARKLE_COLORS.size()]
		var local := (t - start) / 0.55
		if local < 0.0 or local > 1.0:
			continue
		var turn := angle + local * 4.0
		var sparkle := center + Vector2(cos(turn) * radius * 0.6 * (0.4 + 0.6 * local), radius * 0.5 - radius * 1.4 * local)
		var size := radius * 0.07 * (1.0 - local) + 1.0
		var diamond := PackedVector2Array([sparkle + Vector2(0, -size), sparkle + Vector2(size * 0.6, 0),
				sparkle + Vector2(0, size), sparkle + Vector2(-size * 0.6, 0)])
		canvas.draw_colored_polygon(diamond, Color(color_i, 1.0 - local))


## `text` centré sur `center`, cerné de sombre, avec l'opacité `alpha`.
func _text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color,
		alpha: float) -> void:
	font_size = maxi(8, font_size)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			maxi(3, int(font_size / 4.0)), Color(0.1, 0.07, 0.05, alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
