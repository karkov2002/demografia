class_name NewGamePopup
extends ModalPopup
## Fenêtre « New game » : taille de la carte, nombre de joueurs et type de chaque joueur (le premier est
## le joueur local, humain ; les autres sont des IA, un autre joueur humain n'étant pas encore
## possible). Elle se ferme par la croix en haut à droite, ou par Échap.

## Émis au lancement de la partie, avec les paramètres choisis.
signal start_requested(setup: GameSetup)
## Émis à la fermeture par la croix.
signal closed

const AI_ITEM := 0
const HUMAN_ITEM := 1

var _width: SpinBox
var _height: SpinBox
var _player_count: SpinBox
var _players_box: VBoxContainer
var _types: Array[OptionButton] = []


func _ready() -> void:
	var content := _build_frame()
	content.custom_minimum_size = Vector2(440.0, 0.0)

	var header := HBoxContainer.new()
	header.add_child(_label("Nouvelle partie", 24, INK, HORIZONTAL_ALIGNMENT_LEFT))
	header.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.tooltip_text = "Fermer"
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_close)
	header.add_child(close)
	content.add_child(header)

	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 16)
	settings.add_theme_constant_override("v_separation", 8)
	content.add_child(settings)
	_width = _add_spin(settings, "Largeur de la carte", GameSetup.MIN_SIZE, GameSetup.MAX_SIZE, 10)
	_height = _add_spin(settings, "Hauteur de la carte", GameSetup.MIN_SIZE, GameSetup.MAX_SIZE, 10)
	_player_count = _add_spin(settings, "Nombre de joueurs", GameSetup.MIN_PLAYERS, GameSetup.MAX_PLAYERS, 2)
	_player_count.value_changed.connect(func(_value: float) -> void: _rebuild_players())

	content.add_child(_label("Joueurs", 16, MUTED_INK, HORIZONTAL_ALIGNMENT_LEFT))
	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", 6)
	content.add_child(_players_box)
	_rebuild_players()

	var start := _main_button("Lancer la partie")
	start.pressed.connect(_on_start_pressed)
	content.add_child(start)


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


## Une ligne par joueur : pastille et nom de sa couleur, puis son type. Les types déjà choisis sont
## conservés quand le nombre de joueurs change.
func _rebuild_players() -> void:
	var previous: Array[int] = []
	for option in _types:
		previous.append(option.selected)
	for child in _players_box.get_children():
		child.queue_free()
	_types.clear()
	for index in int(_player_count.value):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = CellBackground.PLAYER_COLORS[index]
		swatch.custom_minimum_size = Vector2(18.0, 18.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var player_label := _label("Joueur %d (%s)" % [index + 1, CellBackground.PLAYER_COLOR_NAMES[index]], 15, INK,
				HORIZONTAL_ALIGNMENT_LEFT)
		player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(player_label)
		var type := OptionButton.new()
		type.add_item("IA", AI_ITEM)
		type.add_item("Humain", HUMAN_ITEM)
		type.custom_minimum_size = Vector2(130.0, 0.0)
		if index == 0:
			# Le joueur local : toujours humain.
			type.select(HUMAN_ITEM)
			type.disabled = true
			type.tooltip_text = "Vous"
		else:
			# Pas encore d'autre joueur humain (il faudra le jeu en ligne) : IA seulement.
			type.set_item_disabled(HUMAN_ITEM, true)
			type.set_item_tooltip(HUMAN_ITEM, "Bientôt : un autre joueur humain, en ligne.")
			type.select(previous[index] if index < previous.size() else AI_ITEM)
		row.add_child(type)
		_players_box.add_child(row)
		_types.append(type)


func _on_start_pressed() -> void:
	var setup := GameSetup.new()
	setup.columns = int(_width.value)
	setup.rows = int(_height.value)
	setup.ai_players.clear()
	for option in _types:
		setup.ai_players.append(option.get_selected_id() == AI_ITEM)
	start_requested.emit(setup)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
