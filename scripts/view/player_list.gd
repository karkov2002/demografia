class_name PlayerList
extends VBoxContainer
## Liste des joueurs dans la colonne de droite : une ligne par joueur, avec sa couleur, son nom et la part
## des terres de la carte qu'il possède. Un joueur que le joueur local n'a pas encore rencontré (aucune de
## ses cases vue) garde « ? » ; un joueur détruit est marqué « détruit ». D'autres informations
## s'ajouteront avec les technologies.

const INK := Color(0.22, 0.16, 0.1)
const MUTED_INK := Color(0.45, 0.38, 0.3)
const FONT_SIZE := 13

var _rows: Dictionary[int, Label] = {}


## Construit une ligne par joueur de `world`, nommé selon `names` (par identifiant).
func setup(world: World, names: Dictionary) -> void:
	add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	header.add_child(_label(Locale.text("PLAYER_LIST_PLAYERS"), MUTED_INK, true))
	header.add_child(_label(Locale.text("PLAYER_LIST_TERRITORY"), MUTED_INK, false))
	add_child(header)
	for current in world.players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = CellBackground.PLAYER_COLORS[current.id]
		swatch.custom_minimum_size = Vector2(14.0, 14.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_label(names[current.id], INK, true))
		var value := _label(Locale.text("PLAYER_LIST_UNKNOWN"), INK, false)
		row.add_child(value)
		_rows[current.id] = value
		add_child(row)


## Met à jour les lignes vues par `viewer_id` : part du territoire des joueurs rencontrés, « ? » pour les
## autres.
func refresh(world: World, viewer_id: int) -> void:
	for player_id in _rows:
		var text := Locale.text("PLAYER_LIST_UNKNOWN")
		if world.has_started(player_id) and world.total_population(player_id) == 0:
			text = Locale.text("PLAYER_LIST_DESTROYED")
		elif world.player(viewer_id).has_met(player_id):
			text = "%.1f %%" % (world.territory_share(player_id) * 100.0)
		_rows[player_id].text = text


func _label(text: String, color: Color, expand: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label
