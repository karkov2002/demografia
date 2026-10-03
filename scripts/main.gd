extends Control
## Point d'assemblage de la partie : crée le monde selon les paramètres choisis (GameSetup), les joueurs
## (le joueur local, humain, et les IA) et l'horloge, puis traduit les actions de l'interface en
## commandes du joueur humain.

const MENU_SCENE := "res://scenes/menu.tscn"

@export var rules: GameRules

@onready var _map: HexMap = $Layout/MapView
@onready var _preview: HexPreview = $Layout/InfoPanel/InfoBox/HexPreview
@onready var _science_stat: StatDisplay = $Layout/InfoPanel/InfoBox/StatsBar/ScienceStat
@onready var _population_stat: StatDisplay = $Layout/InfoPanel/InfoBox/StatsBar/PopulationStat
@onready var _gold_stat: StatDisplay = $Layout/InfoPanel/InfoBox/StatsBar/GoldStat
@onready var _food_stat: StatDisplay = $Layout/InfoPanel/InfoBox/StatsBar/FoodStat

var _world: World
var _clock: GameClock
## Horloge rapide de la famine : une mort toutes les rules.starvation_interval secondes par case affamée.
var _starvation_clock: GameClock
var _human: Player
var _ais: Array[AIController] = []
## Population du joueur au début du cycle en cours, pour la tendance affichée dans la barre d'action.
var _population_at_cycle_start: int = 0
## Évolution de la partie, pour les graphiques de fin de partie, et temps de jeu écoulé (s).
var _history := GameHistory.new()
var _elapsed: float = 0.0
var _game_over: bool = false
## Joueurs ennemis dont la destruction a déjà été annoncée.
var _destroyed: Dictionary[int, bool] = {}
## Fenêtre « Do you really want to quit ? » ouverte par Échap ou Menu > Quitter, ou null.
var _quit_confirmation: ConfirmPopup
var _sounds := SoundFx.new()
## Bouton son (haut-parleur), en bas à droite de l'écran.
var _sound_button: TextureButton
## Liste des joueurs et de leur territoire, sous la barre des ressources.
var _player_list := PlayerList.new()


func _ready() -> void:
	var setup := GameSetup.current if GameSetup.current != null else GameSetup.new()
	var game_rules: GameRules = rules.duplicate()
	game_rules.columns = setup.columns
	game_rules.rows = setup.rows
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_world = World.new(game_rules)
	var starts := MapGenerator.generate(_world, rng, setup.map_type, setup.ai_players.size())
	# Les joueurs sont créés dans l'ordre choisi, qui fixe leur identifiant et leur couleur ; le
	# premier humain est le joueur local.
	for index in setup.ai_players.size():
		var is_ai := setup.ai_players[index]
		var level: int = setup.ai_levels[index] if index < setup.ai_levels.size() else AIProfile.Level.NORMAL
		var profile := AIProfile.of_level(level) if is_ai else null
		# Le handicap de croissance d'une IA dépend de son niveau.
		var player := _world.add_player(is_ai, profile.growth_factor if is_ai else 1.0)
		if is_ai:
			_ais.append(AIController.new(_world, player.id, rng, profile))
		elif _human == null:
			_human = player
	# Chaque joueur, humain compris, démarre sur la case tirée au hasard pour lui par le générateur.
	for index in mini(starts.size(), _world.players.size()):
		_world.execute(StartCommand.new(index, starts[index]))
	_clock = GameClock.new(rules.cycle_duration)
	_clock.cycle.connect(_on_cycle)
	_starvation_clock = GameClock.new(rules.starvation_interval)
	_starvation_clock.cycle.connect(_world.starve)
	_starvation_clock.cycle.connect(func() -> void: _world.move_convoys(rules.starvation_interval))

	_map.viewer_id = _human.id
	_preview.viewer_id = _human.id
	_map.world = _world
	_preview.world = _world
	_world.changed.connect(_update_stats)
	_world.changed.connect(_check_destroyed)
	_world.changed.connect(_check_game_over)
	add_child(_sounds)
	add_child(BackgroundMusic.new())
	_world.owner_changed.connect(_on_owner_changed)
	_world.city_lost.connect(_on_city_lost)
	_update_stats()
	_map.cell_selected.connect(_on_cell_selected)
	_preview.transfer_requested.connect(_on_transfer_requested)
	_map.units_sent.connect(_on_units_sent)
	_preview.boost_requested.connect(_on_boost_requested)
	_preview.city_requested.connect(_on_city_requested)
	_preview.downgrade_requested.connect(_on_downgrade_requested)
	_preview.button_clicked.connect(_sounds.click)
	_add_player_list()
	_add_menu_button()
	_add_sound_button()
	# La partie commence aussitôt, la case de départ du joueur sélectionnée dans le zoom.
	var home := _world.cells_of(_human.id)
	if not home.is_empty():
		_map.selected_cell = home[0]
		_preview.cell = home[0]
	_clock.running = true
	_starvation_clock.running = true
	_history.record(_world, _elapsed)


func _process(delta: float) -> void:
	_clock.advance(delta)
	_starvation_clock.advance(delta)
	_preview.cycle_fraction = _clock.cycle_fraction()
	_map.convoy_time_offset = _starvation_clock.cycle_fraction() * rules.starvation_interval


func _on_cycle() -> void:
	_population_at_cycle_start = _world.total_population(_human.id)
	_world.tick()
	for ai in _ais:
		for command in ai.play_cycle():
			_world.execute(command)
	_elapsed += rules.cycle_duration
	_history.record(_world, _elapsed)


func _on_cell_selected(cell: Vector2i) -> void:
	_preview.cell = cell
	# Bruits de mêlée quand on regarde une bataille en vue.
	if _world.is_at_war(cell) and _world.is_visible(_human.id, cell):
		_sounds.battle()


## Cris de victoire ou de défaite quand le joueur local gagne ou perd une case par la guerre.
func _on_owner_changed(_cell: Vector2i, previous_owner: int, new_owner: int, by_war: bool) -> void:
	if not by_war:
		return
	if new_owner == _human.id:
		_sounds.victory()
	elif previous_owner == _human.id:
		_sounds.defeat()


## Choc sourd et foule consternée quand la famine fait redevenir village une ville du joueur.
func _on_city_lost(cell: Vector2i, by_famine: bool) -> void:
	if by_famine and _world.owner(cell) == _human.id:
		_sounds.defeat()


## Boost sur la case du zoom ; s'il a ajouté des workers, un « +N » s'envole du bouton et de la case.
func _on_boost_requested() -> void:
	var cell := _preview.cell
	# Boost ajoute rules.boost_workers workers, dans la limite de la place libre.
	var added := mini(_world.rules.boost_workers, _world.free_room(cell))
	if _world.execute(BoostCommand.new(_human.id, cell)):
		_sounds.laser()
		_preview.show_boost(added)
		_map.show_boost(cell, added)


## Le village du zoom passe en ville.
func _on_city_requested() -> void:
	if _world.execute(FoundCityCommand.new(_human.id, _preview.cell)):
		_sounds.city()


## La ville du zoom redevient village, après confirmation : elle va perdre des habitants. Le jeu
## continue pendant la question.
func _on_downgrade_requested() -> void:
	var cell := _preview.cell
	var village := floori(_world.rules.village_capacity)
	var lost := maxi(0, floori(_world.population(cell).residents() + 1e-6) - village)
	var popup := ConfirmPopup.new()
	add_child(popup)
	var message := Locale.text("DOWNGRADE_MESSAGE", {"count": NumberFormat.compact(lost), "capacity": village})
	popup.setup(Locale.text("DOWNGRADE_TITLE"), message, Locale.text("DOWNGRADE_CANCEL"),
			Locale.text("DOWNGRADE_CONFIRM"))
	popup.confirmed.connect(func() -> void:
		_world.execute(DowngradeCityCommand.new(_human.id, cell))
		popup.queue_free())


func _on_transfer_requested(from_role: String, to_role: String, amount: int) -> void:
	_world.execute(TransferCommand.new(_human.id, _preview.cell, from_role, to_role, amount))


## Colons et troupe de la case sélectionnée partent vers `to_cell`, chacun là où ses règles le permettent.
func _on_units_sent(to_cell: Vector2i) -> void:
	if _world.execute(SendSettlersCommand.new(_human.id, _map.selected_cell, to_cell)):
		_sounds.wagon(_world.rules.travel_time)
	_world.execute(SendArmyCommand.new(_human.id, _map.selected_cell, to_cell))


## Totaux du joueur dans la barre d'action, chacun avec sa tendance : science produite par cycle,
## évolution de la population depuis le début du cycle, revenu en or et solde de food par cycle.
func _update_stats() -> void:
	if _player_list.is_inside_tree():
		_player_list.refresh(_world, _human.id)
	var population := _world.total_population(_human.id)
	_science_stat.value = NumberFormat.compact(floori(_human.science))
	_science_stat.trend = _world.science_rate(_human.id)
	_population_stat.value = NumberFormat.compact(population)
	_population_stat.trend = population - _population_at_cycle_start
	_gold_stat.value = NumberFormat.compact(floori(_human.gold))
	_gold_stat.trend = _world.total_income(_human.id)
	var food := _world.total_food_balance(_human.id)
	_food_stat.value = NumberFormat.signed(food)
	_food_stat.trend = food


## Annonce chaque joueur ennemi qui vient d'être détruit (plus personne nulle part) : « Player #N has been
## destroyed » en grand sur la carte, avec feux d'artifice et clameur de victoire.
func _check_destroyed() -> void:
	for current in _world.players:
		if current == _human or _destroyed.has(current.id) or not current.started:
			continue
		if _world.total_population(current.id) == 0:
			_destroyed[current.id] = true
			_map.show_destroyed(Locale.text("PLAYER_DESTROYED", {"number": current.id + 1,
					"color": Locale.text(CellBackground.PLAYER_COLOR_NAMES[current.id])}))
			_sounds.victory()


## Fin de partie dès qu'au plus un joueur reste en lice, ou que le joueur local est éliminé : les
## horloges s'arrêtent et la fenêtre de fin annonce le résultat, avec l'évolution de chaque joueur.
func _check_game_over() -> void:
	var human_eliminated := _world.has_started(_human.id) and _human.id not in _world.alive_players()
	if _game_over or not (_world.is_game_over() or human_eliminated):
		return
	_end_game(_world.winner(), not human_eliminated, false)


## Arrête la partie et ouvre la fenêtre de fin : gagnée par `winner_id` (World.NO_PLAYER : pas de
## gagnant unique), le joueur local encore en lice ou non (`human_alive`), ou abandonnée par lui
## (`abandoned`).
func _end_game(winner_id: int, human_alive: bool, abandoned: bool) -> void:
	_game_over = true
	_clock.running = false
	_starvation_clock.running = false
	_history.record(_world, _elapsed + _clock.cycle_fraction() * rules.cycle_duration)
	var names := {}
	var colors := {}
	for current in _world.players:
		names[current.id] = _player_name(current)
		colors[current.id] = CellBackground.PLAYER_COLORS[current.id]
	var popup := GameOverPopup.new()
	add_child(popup)
	popup.setup(_history, winner_id, _human.id, human_alive, names, colors, abandoned)
	popup.menu_requested.connect(_go_to_menu)


## « You » pour le joueur local, sinon « AI » suivi de sa couleur et de son niveau (dans la langue du jeu).
func _player_name(player: Player) -> String:
	if player == _human:
		return Locale.text("PLAYER_YOU")
	var color := Locale.text(CellBackground.PLAYER_COLOR_NAMES[player.id])
	for ai in _ais:
		if ai.player_id == player.id:
			return Locale.text("PLAYER_AI", {"color": color, "level": Locale.text(ai.profile.label)})
	return Locale.text("PLAYER_AI_SHORT", {"color": color})


## Échap : comme Menu > Quitter (voir _ask_quit).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _quit_confirmation != null:
		return
	get_viewport().set_input_as_handled()
	_ask_quit()


## Quitter la partie : en fin de partie, retour direct au menu ; sinon, pause et confirmation, car la
## partie en cours serait perdue.
func _ask_quit() -> void:
	if _quit_confirmation != null:
		return
	if _game_over:
		_go_to_menu()
		return
	var was_running := _clock.running
	_clock.running = false
	_starvation_clock.running = false
	_quit_confirmation = ConfirmPopup.new()
	add_child(_quit_confirmation)
	_quit_confirmation.setup(Locale.text("QUIT_CONFIRM"), "", Locale.text("COMMON_NO"), Locale.text("COMMON_YES"))
	_quit_confirmation.confirmed.connect(func() -> void:
		_quit_confirmation.queue_free()
		_quit_confirmation = null
		_end_game(World.NO_PLAYER, true, true))
	_quit_confirmation.cancelled.connect(func() -> void:
		_clock.running = was_running
		_starvation_clock.running = was_running
		_quit_confirmation = null)


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## Liste des joueurs (voir PlayerList), juste sous la barre des ressources, avec une marge sur les côtés.
func _add_player_list() -> void:
	var names := {}
	for current in _world.players:
		names[current.id] = _player_name(current)
	_player_list.setup(_world, names)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_child(_player_list)
	var info_box := $Layout/InfoPanel/InfoBox
	info_box.add_child(margin)
	info_box.move_child(margin, 1)
	_player_list.refresh(_world, _human.id)


## Bouton « Menu » au bout de la barre d'action, en haut du panneau de droite : pour l'instant un seul
## choix, « Quitter », qui ramène au menu principal après confirmation (voir _ask_quit).
func _add_menu_button() -> void:
	const QUIT_ID := 0
	var menu := MenuButton.new()
	menu.text = Locale.text("HUD_MENU")
	menu.flat = false
	menu.focus_mode = Control.FOCUS_NONE
	menu.get_popup().add_item(Locale.text("HUD_QUIT"), QUIT_ID)
	menu.get_popup().id_pressed.connect(func(id: int) -> void:
		if id == QUIT_ID:
			_ask_quit())
	$Layout/InfoPanel/InfoBox/StatsBar.add_child(menu)


## Bouton son en bas à droite de l'écran : un clic coupe tous les sons du jeu (bruitages et musique) et
## barre le haut-parleur, un autre les remet. C'est le bus principal qui est rendu muet : le réglage
## tient jusqu'au menu et dans les parties suivantes.
func _add_sound_button() -> void:
	const BUTTON_SIZE := 36.0
	const MARGIN := 10.0
	_sound_button = TextureButton.new()
	_sound_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sound_button.ignore_texture_size = true
	_sound_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_sound_button.focus_mode = Control.FOCUS_NONE
	_sound_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_sound_button.offset_left = -MARGIN - BUTTON_SIZE
	_sound_button.offset_top = -MARGIN - BUTTON_SIZE
	_sound_button.offset_right = -MARGIN
	_sound_button.offset_bottom = -MARGIN
	_sound_button.pressed.connect(func() -> void:
		var master := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(master, not AudioServer.is_bus_mute(master))
		_update_sound_button())
	add_child(_sound_button)
	_update_sound_button()


func _update_sound_button() -> void:
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_sound_button.texture_normal = Icons.SOUND_OFF if muted else Icons.SOUND_ON
	_sound_button.tooltip_text = Locale.text("HUD_UNMUTE" if muted else "HUD_MUTE")
