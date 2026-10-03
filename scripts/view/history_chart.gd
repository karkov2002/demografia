class_name HistoryChart
extends Control
## Courbe dans le temps d'une mesure de la partie (voir GameHistory), une ligne par joueur dans sa
## couleur. Un seul axe vertical par graphique : les mesures d'échelles différentes vont dans des
## graphiques séparés. Au survol, un réticule vertical donne les valeurs de chaque joueur à cet instant.

## Émis quand la souris survole le relevé `index` (-1 : hors du graphique), pour synchroniser le
## réticule des graphiques voisins.
signal hovered(index: int)

const INK := Color(0.92, 0.91, 0.88)
const MUTED_INK := Color(0.62, 0.61, 0.58)
const GRID := Color(1.0, 1.0, 1.0, 0.07)
const BASELINE := Color(1.0, 1.0, 1.0, 0.25)
const TOOLTIP_BACKGROUND := Color(0.07, 0.07, 0.07, 0.95)
const FONT_SIZE := 12
const TITLE_FONT_SIZE := 14
## Marges (px) autour du tracé : titre en haut, graduations à gauche et en bas, étiquettes des fins de
## ligne à droite.
const PLOT_MARGINS := {"left": 46.0, "top": 30.0, "right": 110.0, "bottom": 22.0}

var history: GameHistory
var metric: String
var title: String
var icon: Texture2D
## Identifiant de joueur → nom et couleur.
var player_names: Dictionary = {}
var player_colors: Dictionary = {}
## Relevé sous le réticule, ou -1.
var hover_index: int = -1:
	set(value):
		hover_index = value
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(func() -> void: hovered.emit(-1))


func _plot_rect() -> Rect2:
	return Rect2(Vector2(PLOT_MARGINS.left, PLOT_MARGINS.top),
			size - Vector2(PLOT_MARGINS.left + PLOT_MARGINS.right, PLOT_MARGINS.top + PLOT_MARGINS.bottom))


func _draw() -> void:
	var font := get_theme_default_font()
	_draw_title(font)
	if history == null or history.times.size() < 2:
		return
	var plot := _plot_rect()
	var range_y := _value_range()
	var step := _nice_step(range_y.y - range_y.x)
	# Graduations horizontales discrètes, et la ligne du zéro un peu plus marquée.
	var tick := ceilf(range_y.x / step) * step
	while tick <= range_y.y + step * 0.001:
		var y := _y(tick, plot, range_y)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), BASELINE if is_zero_approx(tick) else GRID, 1.0)
		_draw_text(font, NumberFormat.compact(tick), Vector2(plot.position.x - 6.0, y), MUTED_INK, HORIZONTAL_ALIGNMENT_RIGHT)
		tick += step
	for i in [0, history.times.size() - 1]:
		var x := _x(i, plot)
		_draw_text(font, _clock_text(history.times[i]), Vector2(x, plot.end.y + 12.0), MUTED_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var ends := []
	for player_id in player_colors:
		ends.append(_draw_series(player_id, plot, range_y))
	_draw_end_labels(font, ends)
	if hover_index >= 0:
		_draw_crosshair(font, plot, range_y)


func _draw_title(font: Font) -> void:
	var left := 4.0
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2(left, 4.0), Vector2.ONE * 18.0), false)
		left += 24.0
	draw_string(font, Vector2(left, 4.0 + font.get_ascent(TITLE_FONT_SIZE)), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TITLE_FONT_SIZE, INK)


## Ligne de 2 px du joueur, point final marqué ; renvoie [point final, étiquette] pour _draw_end_labels.
func _draw_series(player_id: int, plot: Rect2, range_y: Vector2) -> Array:
	var values := history.series(metric, player_id)
	var points := PackedVector2Array()
	for i in values.size():
		points.append(Vector2(_x(i, plot), _y(values[i], plot, range_y)))
	var color: Color = player_colors[player_id]
	draw_polyline(points, color, 2.0, true)
	var last := points[points.size() - 1]
	draw_circle(last, 4.0, color)
	return [last, "%s %s" % [player_names[player_id], NumberFormat.compact(values[values.size() - 1])]]


## Étiquette « nom valeur » à droite de chaque fin de ligne : le nom double la couleur, pour qu'on
## distingue les joueurs sans elle. Les étiquettes trop proches sont écartées verticalement.
func _draw_end_labels(font: Font, ends: Array) -> void:
	ends.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
	var spacing := font.get_height(FONT_SIZE)
	var previous_y := -INF
	for end in ends:
		var y := maxf(end[0].y, previous_y + spacing)
		_draw_text(font, end[1], Vector2(end[0].x + 8.0, y), INK, HORIZONTAL_ALIGNMENT_LEFT)
		previous_y = y


## Réticule vertical sur le relevé survolé, points sur chaque ligne et bulle des valeurs.
func _draw_crosshair(font: Font, plot: Rect2, range_y: Vector2) -> void:
	var x := _x(hover_index, plot)
	draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), MUTED_INK, 1.0)
	var lines: Array = [[null, _clock_text(history.times[hover_index])]]
	for player_id in player_colors:
		var value: float = history.series(metric, player_id)[hover_index]
		draw_circle(Vector2(x, _y(value, plot, range_y)), 4.0, player_colors[player_id])
		lines.append([player_colors[player_id], "%s: %s" % [player_names[player_id], NumberFormat.compact(value)]])
	var line_height := font.get_height(FONT_SIZE)
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var box_size := Vector2(width + 26.0, line_height * lines.size() + 8.0)
	# Bulle à droite du réticule, ou à gauche si elle déborderait.
	var box_x := x + 10.0 if x + 10.0 + box_size.x <= size.x else x - 10.0 - box_size.x
	var box := Rect2(Vector2(box_x, plot.position.y), box_size)
	draw_rect(box, TOOLTIP_BACKGROUND)
	for i in lines.size():
		var y := box.position.y + 4.0 + line_height * (i + 0.5)
		if lines[i][0] != null:
			draw_circle(Vector2(box.position.x + 10.0, y), 4.0, lines[i][0])
		_draw_text(font, lines[i][1], Vector2(box.position.x + 18.0, y), INK if i > 0 else MUTED_INK, HORIZONTAL_ALIGNMENT_LEFT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and history != null and history.times.size() >= 2:
		var plot := _plot_rect()
		if plot.grow(4.0).has_point(event.position):
			var ratio := clampf((event.position.x - plot.position.x) / plot.size.x, 0.0, 1.0)
			hovered.emit(roundi(ratio * (history.times.size() - 1)))
		else:
			hovered.emit(-1)


## Plage verticale : toujours le zéro, et toutes les valeurs de tous les joueurs, arrondie aux graduations.
func _value_range() -> Vector2:
	var low := 0.0
	var high := 0.0
	for player_id in player_colors:
		for value in history.series(metric, player_id):
			low = minf(low, value)
			high = maxf(high, value)
	if is_equal_approx(low, high):
		high = low + 1.0
	var step := _nice_step(high - low)
	return Vector2(floorf(low / step) * step, ceilf(high / step) * step)


## Pas de graduation « rond » (1, 2 ou 5 × 10^n) donnant environ 4 intervalles sur `span`.
static func _nice_step(span: float) -> float:
	var raw := span / 4.0
	var magnitude := pow(10.0, floorf(log(raw) / log(10.0)))
	for factor in [1.0, 2.0, 5.0, 10.0]:
		if raw <= factor * magnitude:
			return factor * magnitude
	return 10.0 * magnitude


func _x(index: int, plot: Rect2) -> float:
	return plot.position.x + plot.size.x * index / float(history.times.size() - 1)


func _y(value: float, plot: Rect2, range_y: Vector2) -> float:
	return plot.end.y - plot.size.y * (value - range_y.x) / (range_y.y - range_y.x)


## Durée en minutes et secondes : 4:05.
static func _clock_text(seconds: float) -> String:
	var total := roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Texte centré verticalement sur `anchor`, aligné selon `alignment` autour de son x.
func _draw_text(font: Font, text: String, anchor: Vector2, color: Color, alignment: HorizontalAlignment) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var x := anchor.x
	if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	elif alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width / 2.0
	var baseline := anchor.y + (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0
	draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
