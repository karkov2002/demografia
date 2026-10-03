class_name GameOverPopup
extends ModalPopup
## Fin de partie : fenêtre annonçant le résultat (victoire, défaite ou abandon) avec son illustration,
## puis l'évolution de la population, de la science et de la food de chaque joueur, un graphique par
## onglet, et un bouton de retour au menu.

## Émis au clic sur le bouton de retour au menu principal.
signal menu_requested

const CHART_SIZE := Vector2(720.0, 340.0)
## Taille (px) de l'illustration du résultat (icône en pixel art agrandie).
const ILLUSTRATION_SIZE := 96.0


## Construit la fenêtre de la partie finie, gagnée par `winner_id` (World.NO_PLAYER : pas de gagnant
## unique), vue par `viewer_id`, encore en lice ou non (`viewer_alive`), ou abandonnée par lui
## (`abandoned`) ; les joueurs sont nommés et colorés selon `names` et `colors` (par identifiant).
func setup(history: GameHistory, winner_id: int, viewer_id: int, viewer_alive: bool, names: Dictionary,
		colors: Dictionary, abandoned: bool = false) -> void:
	var content := _build_frame()
	var headline := "Victoire !"
	var result := "%s remporte la partie." % names.get(winner_id, "")
	var illustration := Icons.VICTORY
	if abandoned:
		headline = "Vous avez abandonné"
		result = "La partie s'arrête ici."
		illustration = Icons.SURRENDER
	elif winner_id != viewer_id:
		headline = "Défaite…"
		illustration = Icons.DEFEAT
		if winner_id == World.NO_PLAYER:
			result = "Vous avez été éliminé." if not viewer_alive else "Plus personne en lice."
	content.add_child(_illustration(illustration))
	content.add_child(_label(headline, 30, INK))
	content.add_child(_label(result, 16, MUTED_INK))
	content.add_child(_legend(names, colors))

	# Un onglet par graphique, pour bien voir chacun.
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = CHART_SIZE + Vector2(0.0, 36.0)
	content.add_child(tabs)
	var chart_list: Array[HistoryChart] = []
	var titles := {GameHistory.POPULATION: ["Population", Icons.POPULATION],
			GameHistory.SCIENCE: ["Science", Icons.SCIENCE], GameHistory.FOOD: ["Food / cycle", Icons.FOOD]}
	for metric in GameHistory.METRICS:
		var chart := HistoryChart.new()
		chart.name = titles[metric][0]
		chart.history = history
		chart.metric = metric
		chart.title = titles[metric][0]
		chart.icon = titles[metric][1]
		chart.player_names = names
		chart.player_colors = colors
		chart.custom_minimum_size = CHART_SIZE
		tabs.add_child(chart)
		tabs.set_tab_icon(tabs.get_tab_count() - 1, titles[metric][1])
		tabs.set_tab_icon_max_width(tabs.get_tab_count() - 1, 20)
		chart_list.append(chart)
	# Un seul réticule partagé : l'instant survolé reste le même d'un onglet à l'autre.
	for chart in chart_list:
		chart.hovered.connect(func(index: int) -> void:
			for other in chart_list:
				other.hover_index = index)

	var menu := _main_button("Menu principal")
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


## Légende : une pastille de la couleur de chaque joueur suivie de son nom.
func _legend(names: Dictionary, colors: Dictionary) -> HBoxContainer:
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
		entry.add_child(_label(names[player_id], 14, INK))
		legend.add_child(entry)
	return legend
