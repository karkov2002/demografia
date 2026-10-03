extends Control
## Écran d'accueil : titre du jeu, bouton « New game » qui ouvre la fenêtre de paramètres de la partie,
## et bouton « Quit ».

const GAME_SCENE := "res://scenes/main.tscn"
const BACKGROUND := Color("141413")
const TITLE_COLOR := Color(0.95, 0.85, 0.55)


func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := ModalPopup._label(ProjectSettings.get_setting("application/config/name"), 64, TITLE_COLOR)
	column.add_child(title)
	column.add_child(Control.new())  # Espace entre le titre et les boutons.
	var new_game := _menu_button(Locale.text("MENU_NEW_GAME"))
	new_game.pressed.connect(_open_new_game)
	column.add_child(new_game)
	var quit := _menu_button(Locale.text("MENU_QUIT"))
	quit.pressed.connect(get_tree().quit)
	column.add_child(quit)
	new_game.grab_focus()
	# Bruit de clic sur les boutons du menu et de la fenêtre « New game », et musique de fond.
	add_child(SoundFx.new())
	add_child(BackgroundMusic.new())


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)
	return button


func _open_new_game() -> void:
	var popup := NewGamePopup.new()
	popup.start_requested.connect(func(setup: GameSetup) -> void:
		GameSetup.current = setup
		get_tree().change_scene_to_file(GAME_SCENE))
	add_child(popup)
