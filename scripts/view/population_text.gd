class_name PopulationText
extends RefCounted
## Dessin des lignes « rôle : effectif » d'une case, dans la couleur de chaque rôle.

## Convention de couleur des rôles, pour les libellés, les boutons et les barres de progression.
const ROLE_COLORS := {
	"worker": Color(0.45, 0.95, 0.35),
	"scientist": Color(0.4, 0.65, 1.0),
	"fighter": Color(1.0, 0.35, 0.35),
	Population.SETTLER: Color(0.95, 0.75, 0.45),
}
## Nom affiché de chaque rôle, quand il diffère de son identifiant : les fighters restés dans la case
## forment sa garnison (ceux qui partent forment l'armée).
const ROLE_LABELS := {"fighter": "garrison"}
## Contour sombre autour du texte, pour qu'il reste lisible sur le fond vert des cases.
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const BAR_BACKGROUND := Color(0.0, 0.0, 0.0, 0.35)
const DISABLED_COLOR := Color(0.5, 0.5, 0.5)


## Une ligne par rôle, le bloc centré sur `center` : libellé dans la couleur du rôle, effectif entier
## dans `value_color`.
static func draw(canvas: CanvasItem, font: Font, population: Population, center: Vector2, font_size: int,
		value_color: Color) -> void:
	var labels := PackedStringArray()
	var values := PackedStringArray()
	var label_width := 0.0
	var value_width := 0.0
	for role in population.counts:
		labels.append(label(role) + " : ")
		values.append(NumberFormat.compact(population.whole(role)))
		label_width = maxf(label_width, _width(font, labels[-1], font_size))
		value_width = maxf(value_width, _width(font, values[-1], font_size))

	var line_height := font.get_height(font_size)
	var text_left := center.x - (label_width + value_width) / 2.0
	var line_y := center.y - line_height * (population.counts.size() - 1) / 2.0
	# draw_string place la ligne de base : on la décale pour centrer la ligne verticalement.
	var baseline_offset := (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var outline := maxi(2, int(font_size / 3.0))
	var i := 0
	for role in population.counts:
		var baseline_y := line_y + baseline_offset
		draw_outlined(canvas, font, labels[i], Vector2(text_left, baseline_y), font_size, ROLE_COLORS.get(role, value_color), outline)
		draw_outlined(canvas, font, values[i], Vector2(text_left + label_width, baseline_y), font_size, value_color, outline)
		line_y += line_height
		i += 1


## Nom affiché de `role` (voir ROLE_LABELS).
static func label(role: String) -> String:
	return ROLE_LABELS.get(role, role)


## Bouton carré dans la couleur du rôle, marqué `button_sign`.
static func draw_button(canvas: CanvasItem, font: Font, rect: Rect2, button_sign: String, color: Color,
		sign_color: Color) -> void:
	canvas.draw_rect(rect, color.darkened(0.5))
	canvas.draw_rect(rect, color, false, 2.0)
	HexUtils.draw_centered_text(canvas, font, button_sign, rect.get_center(), int(rect.size.y * 0.9), sign_color)


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Écrit `text` à partir de la ligne de base `baseline`, cerné du contour sombre OUTLINE_COLOR.
static func draw_outlined(canvas: CanvasItem, font: Font, text: String, baseline: Vector2,
		font_size: int, color: Color, outline: int) -> void:
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, OUTLINE_COLOR)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Rangée centrée sur `center` d'éléments [icône, texte, couleur] ou [icône, texte, couleur, teinte de
## l'icône] : chaque icône (null = aucune) est suivie de son texte (vide = aucun), les éléments étant
## séparés d'un espace. Les icônes font `icon_scale` fois la hauteur du texte.
static func draw_icon_row(canvas: CanvasItem, font: Font, items: Array, center: Vector2, font_size: int,
		icon_scale: float = 1.2) -> void:
	var icon_size := Vector2.ONE * font.get_height(font_size) * icon_scale
	var gap := font_size * 0.3
	var item_gap := font_size * 1.0
	var widths: Array[float] = []
	var total := 0.0
	for item in items:
		var width := 0.0
		if item[0] != null:
			width += icon_size.x
		if item[1] != "":
			width += (gap if item[0] != null else 0.0) + _width(font, item[1], font_size)
		widths.append(width)
		total += width
	total += item_gap * (items.size() - 1)
	var left := center.x - total / 2.0
	var baseline_y := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var outline := maxi(2, int(font_size / 3.0))
	for i in items.size():
		var x := left
		if items[i][0] != null:
			var tint: Color = items[i][3] if items[i].size() > 3 else Color.WHITE
			canvas.draw_texture_rect(items[i][0], Rect2(Vector2(x, center.y - icon_size.y / 2.0), icon_size), false, tint)
			x += icon_size.x + gap
		if items[i][1] != "":
			draw_outlined(canvas, font, items[i][1], Vector2(x, baseline_y), font_size, items[i][2], outline)
		left += widths[i] + item_gap


## Écrit `text` centré sur `center`, cerné du contour sombre OUTLINE_COLOR.
static func draw_outlined_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int,
		color: Color) -> void:
	var baseline := center + Vector2(-_width(font, text, font_size) / 2.0,
			(font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_outlined(canvas, font, text, baseline, font_size, color, maxi(2, int(font_size / 3.0)))
