class_name PlayerList
extends GridContainer
## Liste des joueurs dans la colonne de droite, une ligne par joueur : sa couleur, son portrait, son nom,
## la part des terres de la carte qu'il possède, sa population totale et l'ère de sa civilisation. Tant
## que le joueur local n'a pas rencontré un joueur (aucune de ses cases vue), seule sa couleur est
## connue : portrait de silhouette, nom « Unknown » et « ? » partout ailleurs. Un joueur détruit est
## marqué « destroyed ». D'autres colonnes s'ajouteront avec les technologies.

const INK := Color(0.22, 0.16, 0.1)
const MUTED_INK := Color(0.45, 0.38, 0.3)
const FONT_SIZE := 13
## Taille (px) du portrait de chaque joueur (son dirigeant pour une IA).
const PORTRAIT_SIZE := 24.0
## Colonnes : couleur, portrait, nom, territoire, population, ère.
const COLUMNS := 6

## Nom de chaque joueur (par identifiant), affiché une fois rencontré.
var _names: Dictionary = {}
## Par joueur : { "portrait": TextureRect, "name", "territory", "population", "era": Label }.
var _rows: Dictionary[int, Dictionary] = {}


## Construit une ligne par joueur de `world`, nommé selon `names` (par identifiant).
func setup(world: World, names: Dictionary) -> void:
	_names = names
	columns = COLUMNS
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 2)
	for text in ["", "", Locale.text("PLAYER_LIST_PLAYERS"), Locale.text("PLAYER_LIST_TERRITORY"),
			Locale.text("PLAYER_LIST_POPULATION"), Locale.text("PLAYER_LIST_ERA")]:
		add_child(_label(text, MUTED_INK, text == Locale.text("PLAYER_LIST_PLAYERS")))
	for current in world.players:
		var swatch := ColorRect.new()
		swatch.color = CellBackground.PLAYER_COLORS[current.id]
		swatch.custom_minimum_size = Vector2(14.0, 14.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(swatch)
		var row := {"portrait": portrait_picture(current, PORTRAIT_SIZE), "name": _label("", INK, true),
				"territory": _label("", INK, false), "population": _label("", INK, false), "era": _label("", INK, false)}
		for key in ["portrait", "name", "territory", "population", "era"]:
			add_child(row[key])
		_rows[current.id] = row


## Met à jour les lignes vues par `viewer_id` : tout pour les joueurs rencontrés (et soi-même), seulement
## « ? » et une silhouette pour les autres.
func refresh(world: World, viewer_id: int) -> void:
	var unknown := Locale.text("PLAYER_LIST_UNKNOWN")
	for player_id in _rows:
		var row: Dictionary = _rows[player_id]
		var current := world.player(player_id)
		var met := world.player(viewer_id).has_met(player_id)
		row.name.text = _names[player_id] if met else Locale.text("PLAYER_LIST_UNKNOWN_NAME")
		row.portrait.texture = _portrait(current) if met else Leaders.unknown_portrait()
		if not met:
			row.territory.text = unknown
			row.population.text = unknown
			row.era.text = unknown
		elif world.has_started(player_id) and world.total_population(player_id) == 0:
			row.territory.text = Locale.text("PLAYER_LIST_DESTROYED")
			row.population.text = ""
			row.era.text = ""
		else:
			row.territory.text = "%.1f %%" % (world.territory_share(player_id) * 100.0)
			row.population.text = NumberFormat.compact(world.total_population(player_id))
			row.era.text = Locale.text("ERA_" + current.era.to_upper())


## Portrait de `player` en `size` pixels, sans lissage : son dirigeant pour une IA, le buste de la
## population pour un humain.
static func portrait_picture(player: Player, size: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = _portrait(player)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2.ONE * size
	return picture


static func _portrait(player: Player) -> Texture2D:
	return Leaders.portrait(player.leader) if player.leader != "" else Icons.POPULATION


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
