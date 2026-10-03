class_name GameOverPopup
extends ModalPopup
## Fin de partie : fenêtre annonçant le résultat (victoire, défaite ou abandon) avec son illustration,
## puis l'évolution de la population, de la science et de la food de chaque joueur, un graphique par
## onglet, et un bouton de retour au menu.

## Émis au clic sur le bouton de retour au menu principal.
signal menu_requested

## Taille maximale (px) des graphiques ; ils rétrécissent pour que la fenêtre tienne à l'écran, bouton de
## retour compris (CHROME_HEIGHT : hauteur de tout le reste de la fenêtre), jusqu'à CHART_MIN_SIZE.
const CHART_SIZE := Vector2(720.0, 340.0)
const CHART_MIN_SIZE := Vector2(380.0, 150.0)
const CHROME_HEIGHT := 400.0
const CHROME_WIDTH := 80.0
## Taille (px) de l'illustration du résultat (icône en pixel art agrandie).
const ILLUSTRATION_SIZE := 72.0


## Construit la fenêtre de la partie finie, gagnée par `winner_id` (World.NO_PLAYER : pas de gagnant
## unique), vue par `viewer_id`, encore en lice ou non (`viewer_alive`), ou abandonnée par lui
## (`abandoned`) ; les joueurs sont nommés, colorés et illustrés selon `names`, `colors` et `portraits` (par
## identifiant).
func setup(history: GameHistory, winner_id: int, viewer_id: int, viewer_alive: bool, names: Dictionary,
		colors: Dictionary, abandoned: bool = false, portraits: Dictionary = {}) -> void:
	var content := _build_frame()
	var headline := Locale.text("GAME_OVER_VICTORY")
	var result := Locale.text("GAME_OVER_YOU_WIN") if winner_id == viewer_id \
			else Locale.text("GAME_OVER_WINNER", {"player": names.get(winner_id, "")})
	var illustration := Icons.VICTORY
	if abandoned:
		headline = Locale.text("GAME_OVER_ABANDONED")
		result = Locale.text("GAME_OVER_ABANDONED_RESULT")
		illustration = Icons.SURRENDER
	elif winner_id != viewer_id:
		headline = Locale.text("GAME_OVER_DEFEAT")
		illustration = Icons.DEFEAT
		if winner_id == World.NO_PLAYER:
			result = Locale.text("GAME_OVER_ELIMINATED" if not viewer_alive else "GAME_OVER_NOBODY")
	content.add_child(_illustration(illustration))
	content.add_child(_label(headline, 30, INK))
	content.add_child(_label(result, 16, MUTED_INK))
	content.add_child(_legend(names, colors, portraits))

	# Un onglet par graphique, pour bien voir chacun.
	var screen := get_viewport_rect().size
	var chart_size := Vector2(clampf(screen.x - CHROME_WIDTH, CHART_MIN_SIZE.x, CHART_SIZE.x),
			clampf(screen.y - CHROME_HEIGHT, CHART_MIN_SIZE.y, CHART_SIZE.y))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = chart_size + Vector2(0.0, 36.0)
	content.add_child(tabs)
	var chart_list: Array[HistoryChart] = []
	var titles := {GameHistory.POPULATION: [Locale.text("CHART_POPULATION"), Icons.POPULATION],
			GameHistory.SCIENCE: [Locale.text("CHART_SCIENCE"), Icons.SCIENCE],
			GameHistory.FOOD: [Locale.text("CHART_FOOD"), Icons.FOOD]}
	for metric in GameHistory.METRICS:
		var chart := HistoryChart.new()
		chart.name = titles[metric][0]
		chart.history = history
		chart.metric = metric
		chart.title = titles[metric][0]
		chart.icon = titles[metric][1]
		chart.player_names = names
		chart.player_colors = colors
		chart.custom_minimum_size = chart_size
		tabs.add_child(chart)
		tabs.set_tab_icon(tabs.get_tab_count() - 1, titles[metric][1])
		tabs.set_tab_icon_max_width(tabs.get_tab_count() - 1, 20)
		chart_list.append(chart)
	# Un seul réticule partagé : l'instant survolé reste le même d'un onglet à l'autre.
	for chart in chart_list:
		chart.hovered.connect(func(index: int) -> void:
			for other in chart_list:
				other.hover_index = index)

	var menu := _main_button(Locale.text("GAME_OVER_MENU"))
	menu.pressed.connect(menu_requested.emit)
	content.add_child(menu)


## Illustration du résultat, centrée : l'icône en pixel art agrandie sans lissage.
func _illustration(icon: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = icon
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2.ONE * ILLUSTRATION_SIZE
	return picture


## Légende : une pastille de la couleur de chaque joueur, son portrait s'il en a un, puis son nom.
func _legend(names: Dictionary, colors: Dictionary, portraits: Dictionary) -> HBoxContainer:
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 18)
	for player_id in names:
		var entry := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = colors[player_id]
		swatch.custom_minimum_size = Vector2(14.0, 14.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(swatch)
		if portraits.has(player_id):
			var picture := _illustration(portraits[player_id])
			picture.custom_minimum_size = Vector2.ONE * 28.0
			entry.add_child(picture)
		entry.add_child(_label(names[player_id], 14, INK))
		legend.add_child(entry)
	return legend
