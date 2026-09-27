class_name HexUtils
extends RefCounted
## Géométrie partagée des hexagones « pointe en haut ».


## Les 6 sommets d'un hexagone ; `radius` = distance centre → sommet.
static func hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Même polygone refermé sur son premier sommet, pour draw_polyline.
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


## Écrit `text` centré sur `center`.
static func draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# draw_string place la ligne de base : on remonte de la moitié de la hauteur, puis on descend de l'ascent.
	var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Direction à l'écran (normalisée) de la case `from` vers sa voisine `to`, en disposition « odd-r »
## (hexagones pointe en haut, rangées impaires décalées d'une demi-case vers la droite).
static func neighbor_direction(from: Vector2i, to: Vector2i) -> Vector2:
	var from_x := from.x + (0.5 if from.y % 2 == 1 else 0.0)
	var to_x := to.x + (0.5 if to.y % 2 == 1 else 0.0)
	return Vector2((to_x - from_x) * sqrt(3.0), (to.y - from.y) * 1.5).normalized()
