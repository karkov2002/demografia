class_name NewGamePopup
extends ModalPopup
## Fenêtre « New game » : type et taille de la carte, nombre de joueurs, type de chaque joueur (le premier est
## le joueur local, humain ; les autres sont des IA, pacifiste, normale ou agressive, un autre joueur
## humain n'étant pas encore possible) et dirigeant de chaque IA (au hasard, ou choisi parmi ceux de son
## niveau). La fenêtre garde une taille fixe quel que soit le nombre de joueurs. Elle se ferme par la croix en haut à droite, ou par Échap.

## Émis au lancement de la partie, avec les paramètres choisis.
signal start_requested(setup: GameSetup)
## Émis à la fermeture par la croix.
signal closed

## Types proposés pour un joueur (clés de texte, voir Locale) : un par niveau d'IA (identifiant =
## AIProfile.Level), puis humain.
const AI_ITEMS := {
	AIProfile.Level.PACIFIST: "AI_TYPE_PACIFIST",
	AIProfile.Level.NORMAL: "AI_TYPE_NORMAL",
	AIProfile.Level.AGGRESSIVE: "AI_TYPE_AGGRESSIVE",
}
const HUMAN_ITEM := 100
## Niveau d'IA tiré au hasard au lancement de la partie (son dirigeant l'est alors aussi).
const RANDOM_ITEM := 101
## Dimensions fixes de la fenêtre : largeur du contenu, hauteur d'une ligne de joueur (la liste garde
## toujours la place de GameSetup.MAX_PLAYERS lignes, pour que la fenêtre ne change pas de taille), largeur
## des listes de type et de dirigeant, taille des portraits dans la liste des dirigeants.
const CONTENT_WIDTH := 640.0
const ROW_HEIGHT := 34.0
const ROW_GAP := 6.0
const TYPE_WIDTH := 150.0
const LEADER_WIDTH := 230.0
const PORTRAIT_SIZE := 24

var _map_type: OptionButton
var _width: SpinBox
var _height: SpinBox
var _player_count: SpinBox
var _players_box: VBoxContainer
var _types: Array[OptionButton] = []
## Choix du dirigeant de chaque joueur (inactif pour un humain).
var _leaders: Array[OptionButton] = []


func _ready() -> void:
	var content := _build_frame()
	content.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)

	var header := HBoxContainer.new()
	header.add_child(_label(Locale.text("NEW_GAME_TITLE"), 24, INK, HORIZONTAL_ALIGNMENT_LEFT))
	header.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.tooltip_text = Locale.text("NEW_GAME_CLOSE")
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_close)
	header.add_child(close)
	content.add_child(header)

	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 16)
	settings.add_theme_constant_override("v_separation", 8)
	content.add_child(settings)
	settings.add_child(_label(Locale.text("NEW_GAME_MAP_TYPE"), 15, INK, HORIZONTAL_ALIGNMENT_LEFT))
	_map_type = OptionButton.new()
	for type in MapGenerator.MAP_TYPE_NAMES:
		_map_type.add_item(Locale.text(MapGenerator.MAP_TYPE_NAMES[type]), type)
	_map_type.select(_map_type.get_item_index(MapGenerator.MapType.CONTINENTS))
	_map_type.item_selected.connect(func(_index: int) -> void: _update_min_size())
	settings.add_child(_map_type)
	_width = _add_spin(settings, Locale.text("NEW_GAME_WIDTH"), GameSetup.MIN_SIZE, GameSetup.MAX_SIZE, 10)
	_height = _add_spin(settings, Locale.text("NEW_GAME_HEIGHT"), GameSetup.MIN_SIZE, GameSetup.MAX_SIZE, 10)
	_player_count = _add_spin(settings, Locale.text("NEW_GAME_PLAYER_COUNT"), GameSetup.MIN_PLAYERS, GameSetup.MAX_PLAYERS, 2)
	_player_count.value_changed.connect(func(_value: float) -> void:
		_rebuild_players()
		_update_min_size())
	_update_min_size()

	content.add_child(_label(Locale.text("NEW_GAME_PLAYERS"), 16, MUTED_INK, HORIZONTAL_ALIGNMENT_LEFT))
	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", int(ROW_GAP))
	# Place réservée pour le nombre maximal de joueurs : la fenêtre garde sa taille.
	_players_box.custom_minimum_size = Vector2(0.0, GameSetup.MAX_PLAYERS * ROW_HEIGHT + (GameSetup.MAX_PLAYERS - 1) * ROW_GAP)
	content.add_child(_players_box)
	_rebuild_players()

	var start := _main_button(Locale.text("NEW_GAME_START"))
	start.pressed.connect(_on_start_pressed)
	content.add_child(start)


## Taille minimale de la carte selon son type et le nombre de joueurs (voir MapGenerator.min_side) : la
## largeur et la hauteur sont relevées si besoin.
func _update_min_size() -> void:
	var side := MapGenerator.min_side(_map_type.get_selected_id(), int(_player_count.value))
	for spin in [_width, _height]:
		spin.min_value = side
		spin.tooltip_text = Locale.text("NEW_GAME_MIN_SIZE", {"size": side})


func _add_spin(grid: GridContainer, text: String, minimum: int, maximum: int, value: int) -> SpinBox:
	grid.add_child(_label(text, 15, INK, HORIZONTAL_ALIGNMENT_LEFT))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.rounded = true
	spin.custom_minimum_size = Vector2(110.0, 0.0)
	grid.add_child(spin)
	return spin


## Une ligne par joueur : pastille et nom de sa couleur, son type, puis, pour une IA, son dirigeant
## (« Random » ou un dirigeant de son niveau, avec son portrait). Les choix déjà faits sont conservés
## quand le nombre de joueurs change.
func _rebuild_players() -> void:
	var previous_types: Array[int] = []
	var previous_leaders: Array[String] = []
	for index in _types.size():
		previous_types.append(_types[index].selected)
		previous_leaders.append(_selected_leader(index))
	# Retirées tout de suite (et pas en fin d'image) : la fenêtre ne doit pas grandir, même un instant.
	for child in _players_box.get_children():
		_players_box.remove_child(child)
		child.queue_free()
	_types.clear()
	_leaders.clear()
	for index in int(_player_count.value):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		var swatch := ColorRect.new()
		swatch.color = CellBackground.PLAYER_COLORS[index]
		swatch.custom_minimum_size = Vector2(18.0, 18.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var player_label := _label(Locale.text("NEW_GAME_PLAYER", {"number": index + 1,
				"color": Locale.text(CellBackground.PLAYER_COLOR_NAMES[index])}), 15, INK,
				HORIZONTAL_ALIGNMENT_LEFT)
		player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(player_label)
		var type := OptionButton.new()
		for level in AI_ITEMS:
			type.add_item(Locale.text(AI_ITEMS[level]), level)
		type.add_item(Locale.text("AI_TYPE_RANDOM"), RANDOM_ITEM)
		type.add_item(Locale.text("NEW_GAME_HUMAN"), HUMAN_ITEM)
		type.custom_minimum_size = Vector2(TYPE_WIDTH, 0.0)
		type.clip_text = true
		var human_index := type.get_item_index(HUMAN_ITEM)
		var leader := OptionButton.new()
		leader.custom_minimum_size = Vector2(LEADER_WIDTH, 0.0)
		leader.clip_text = true
		leader.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		leader.add_theme_constant_override("icon_max_width", PORTRAIT_SIZE)
		leader.get_popup().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		if index == 0:
			# Le joueur local : toujours humain, sans dirigeant à choisir.
			type.select(human_index)
			type.disabled = true
			type.tooltip_text = Locale.text("PLAYER_YOU")
			leader.disabled = true
			leader.modulate.a = 0.0
		else:
			# Pas encore d'autre joueur humain (il faudra le jeu en ligne) : IA seulement.
			type.set_item_disabled(human_index, true)
			type.set_item_tooltip(human_index, Locale.text("NEW_GAME_HUMAN_SOON"))
			type.select(previous_types[index] if index < previous_types.size() else type.get_item_index(AIProfile.Level.NORMAL))
			_fill_leaders(leader, type.get_selected_id(), previous_leaders[index] if index < previous_leaders.size() else "")
			type.item_selected.connect(func(_item: int) -> void:
				_fill_leaders(leader, type.get_selected_id(), "")
				_update_leader_choices())
			leader.item_selected.connect(func(_item: int) -> void: _update_leader_choices())
		row.add_child(type)
		row.add_child(leader)
		_players_box.add_child(row)
		_types.append(type)
		_leaders.append(leader)
	_update_leader_choices()


## Remplit le choix de dirigeant `option` pour une IA de niveau `level` : « Random », puis chaque dirigeant
## de ce niveau avec son portrait ; `selected` (identifiant de dirigeant) est choisi s'il y figure. Pour un niveau
## tiré au hasard (RANDOM_ITEM), seul « Random » est proposé : le dirigeant ne peut pas être choisi.
func _fill_leaders(option: OptionButton, level: int, selected: String) -> void:
	option.clear()
	option.disabled = level == RANDOM_ITEM
	option.add_icon_item(Leaders.unknown_portrait(), Locale.text("NEW_GAME_RANDOM_LEADER"))
	option.set_item_metadata(0, "")
	option.get_popup().set_item_icon_max_width(0, PORTRAIT_SIZE)
	if level == RANDOM_ITEM:
		option.select(0)
		return
	for id in Leaders.BY_LEVEL[level]:
		option.add_icon_item(Leaders.portrait(id), Leaders.display_name(id))
		var item := option.item_count - 1
		option.set_item_metadata(item, id)
		option.get_popup().set_item_icon_max_width(item, PORTRAIT_SIZE)
		if id == selected:
			option.select(item)
	if option.selected < 0:
		option.select(0)


## Dirigeant choisi pour le joueur `index` ("" : au hasard, ou pas une IA).
func _selected_leader(index: int) -> String:
	if index >= _leaders.size() or _leaders[index].disabled or _leaders[index].selected < 0:
		return ""
	return _leaders[index].get_item_metadata(_leaders[index].selected)


## Un dirigeant ne peut diriger qu'une IA : ceux déjà choisis pour un autre joueur sont grisés.
func _update_leader_choices() -> void:
	var chosen: Array[String] = []
	for index in _leaders.size():
		chosen.append(_selected_leader(index))
	for index in _leaders.size():
		var option := _leaders[index]
		for item in option.item_count:
			var id: String = option.get_item_metadata(item)
			option.set_item_disabled(item, id != "" and id != chosen[index] and id in chosen)


func _on_start_pressed() -> void:
	var setup := GameSetup.new()
	setup.columns = int(_width.value)
	setup.rows = int(_height.value)
	setup.map_type = _map_type.get_selected_id()
	setup.ai_players.clear()
	setup.ai_levels.clear()
	setup.ai_leaders.clear()
	for index in _types.size():
		var id := _types[index].get_selected_id()
		setup.ai_players.append(id != HUMAN_ITEM)
		var level: int = id
		if id == HUMAN_ITEM:
			level = AIProfile.Level.NORMAL
		elif id == RANDOM_ITEM:
			level = GameSetup.RANDOM_LEVEL
		setup.ai_levels.append(level)
		setup.ai_leaders.append(_selected_leader(index) if id != HUMAN_ITEM else "")
	start_requested.emit(setup)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
