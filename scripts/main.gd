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
@onready var _start_button: Button = $Layout/InfoPanel/InfoBox/StartButton

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
## Fenêtre « Retourner au menu ? » ouverte par Échap, ou null.
var _quit_confirmation: ConfirmPopup


func _ready() -> void:
	var setup := GameSetup.current if GameSetup.current != null else GameSetup.new()
	var game_rules: GameRules = rules.duplicate()
	game_rules.columns = setup.columns
	game_rules.rows = setup.rows
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_world = World.new(game_rules)
	MapGenerator.generate(_world, rng, setup.ai_players.size())
	# Les joueurs sont créés dans l'ordre choisi, qui fixe leur identifiant et leur couleur ; le
	# premier humain est le joueur local.
	for index in setup.ai_players.size():
		var is_ai := setup.ai_players[index]
		var player := _world.add_player(is_ai, rules.ai_growth_factor if is_ai else 1.0)
		if is_ai:
			var level: int = setup.ai_levels[index] if index < setup.ai_levels.size() else AIProfile.Level.NORMAL
			_ais.append(AIController.new(_world, player.id, rng, AIProfile.of_level(level)))
		elif _human == null:
			_human = player
	_clock = GameClock.new(rules.cycle_duration)
	_clock.cycle.connect(_on_cycle)
	_starvation_clock = GameClock.new(rules.starvation_interval)
	_starvation_clock.cycle.connect(_world.starve)

	_map.viewer_id = _human.id
	_preview.viewer_id = _human.id
	_map.world = _world
	_preview.world = _world
	_world.changed.connect(_update_stats)
	_world.changed.connect(_check_game_over)
	_update_stats()
	# Inactif tant qu'aucune case n'est sélectionnée.
	_start_button.disabled = true
	_map.cell_selected.connect(_on_cell_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_preview.transfer_requested.connect(_on_transfer_requested)
	_map.units_sent.connect(_on_units_sent)
	_preview.boost_requested.connect(func() -> void: _world.execute(BoostCommand.new(_human.id, _preview.cell)))


func _process(delta: float) -> void:
	_clock.advance(delta)
	_starvation_clock.advance(delta)
	_preview.cycle_fraction = _clock.cycle_fraction()


func _on_cycle() -> void:
	_population_at_cycle_start = _world.total_population(_human.id)
	_world.tick()
	for ai in _ais:
		for command in ai.play_cycle():
			_world.execute(command)
	_elapsed += rules.cycle_duration
	_history.record(_world, _elapsed)


func _on_cell_selected(cell: Vector2i) -> void:
	# Pas de départ sur l'eau ; une montagne inexplorée reste possible, c'est le jeu.
	_start_button.disabled = not _world.can_start_at(_human.id, cell)
	_preview.cell = cell


## L'humain choisit sa case en premier, puis chaque IA tire la sienne au hasard.
func _on_start_pressed() -> void:
	if not _world.execute(StartCommand.new(_human.id, _map.selected_cell)):
		return
	for ai in _ais:
		var command := ai.choose_start()
		if command != null:
			_world.execute(command)
	_start_button.hide()
	_clock.running = true
	_starvation_clock.running = true
	_history.record(_world, _elapsed)


func _on_transfer_requested(from_role: String, to_role: String, amount: int) -> void:
	_world.execute(TransferCommand.new(_human.id, _preview.cell, from_role, to_role, amount))


## Colons et troupe de la case sélectionnée partent vers `to_cell`, chacun là où ses règles le permettent.
func _on_units_sent(to_cell: Vector2i) -> void:
	_world.execute(SendSettlersCommand.new(_human.id, _map.selected_cell, to_cell))
	_world.execute(SendArmyCommand.new(_human.id, _map.selected_cell, to_cell))


## Totaux du joueur dans la barre d'action, chacun avec sa tendance : science produite par cycle,
## évolution de la population depuis le début du cycle, revenu en or et solde de food par cycle.
func _update_stats() -> void:
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


## Fin de partie dès qu'au plus un joueur reste en lice, ou que le joueur local est éliminé : les
## horloges s'arrêtent et la fenêtre de fin annonce le résultat, avec l'évolution de chaque joueur.
func _check_game_over() -> void:
	var human_eliminated := _world.has_started(_human.id) and _human.id not in _world.alive_players()
	if _game_over or not (_world.is_game_over() or human_eliminated):
		return
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
	popup.setup(_history, _world.winner(), _human.id, not human_eliminated, names, colors)
	popup.menu_requested.connect(_go_to_menu)


## « Vous » pour le joueur local, sinon « IA » suivi de sa couleur et de son niveau.
func _player_name(player: Player) -> String:
	if player == _human:
		return "Vous"
	for ai in _ais:
		if ai.player_id == player.id:
			return "IA %s (%s)" % [CellBackground.PLAYER_COLOR_NAMES[player.id], ai.profile.label]
	return "IA %s" % CellBackground.PLAYER_COLOR_NAMES[player.id]


## Échap : en fin de partie, retour direct au menu ; sinon, pause et confirmation, car la partie en cours
## serait perdue.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _quit_confirmation != null:
		return
	get_viewport().set_input_as_handled()
	if _game_over:
		_go_to_menu()
		return
	var was_running := _clock.running
	_clock.running = false
	_starvation_clock.running = false
	_quit_confirmation = ConfirmPopup.new()
	add_child(_quit_confirmation)
	_quit_confirmation.setup("Retourner au menu ?", "La partie en cours sera perdue.", "Continuer", "Menu principal")
	_quit_confirmation.confirmed.connect(_go_to_menu)
	_quit_confirmation.cancelled.connect(func() -> void:
		_clock.running = was_running
		_starvation_clock.running = was_running
		_quit_confirmation = null)


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
