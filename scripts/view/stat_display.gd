class_name StatDisplay
extends HBoxContainer
## Une ressource de la barre d'action : son icône, sa flèche de tendance juste à côté, puis sa valeur.

@export var icon: Texture2D
@export var value_color: Color = Color.WHITE
## Taille (px) des icônes.
@export var icon_size: float = 22.0

## Valeur la plus large que peut afficher la barre (voir NumberFormat), qui fixe la largeur du texte.
const WIDEST_VALUE := "+88.8M"

var value: String = "":
	set(text):
		value = text
		if _label != null:
			_label.text = text
## Tendance de la ressource : son signe choisit la flèche (hausse, stabilité, baisse).
var trend: float = 0.0:
	set(change):
		trend = change
		if _trend_picture != null:
			_trend_picture.texture = Icons.trend(change)

var _label: Label
var _trend_picture: TextureRect


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_picture(icon))
	_label = Label.new()
	_label.add_theme_color_override("font_color", value_color)
	_label.text = value
	# Largeur fixe, celle de la valeur la plus large (NumberFormat en donne au plus 6 caractères) : la
	# barre, et donc la colonne de droite, ne change pas de taille quand les valeurs évoluent.
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	_label.custom_minimum_size.x = ceilf(font.get_string_size(WIDEST_VALUE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_label.clip_text = true
	# Flèche collée à l'icône, avant la valeur dont la largeur est fixe.
	_trend_picture = _picture(Icons.trend(trend), 0.7)
	add_child(_trend_picture)
	add_child(_label)


func _picture(texture: Texture2D, scale_factor: float = 1.0) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2.ONE * icon_size * scale_factor
	# Icône en pixel art : pas de lissage à l'agrandissement.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return picture
