class_name GameOverPopup
extends ModalPopup
## Fin de partie : fenêtre annonçant le résultat, avec l'évolution de la population, de la science et
## de la food de chaque joueur, puis un bouton de retour au menu.

## Émis au clic sur le bouton de retour au menu principal.
signal menu_requested

const CHART_SIZE := Vector2(340.0, 230.0)


## Construit la fenêtre de la partie finie, gagnée par `winner_id` (World.NO_PLAYER : pas de gagnant
## unique), vue par `viewer_id`, encore en lice ou non (`viewer_alive`) ; les joueurs sont nommés et
## colorés selon `names` et `colors` (par identifiant).
func setup(history: GameHistory, winner_id: int, viewer_id: int, viewer_alive: bool, names: Dictionary,
		colors: Dictionary) -> void:
	var content := _build_frame()
	var headline := "Victoire !"
	var result := "%s remporte la partie." % names.get(winner_id, "")
	if winner_id != viewer_id:
		headline = "Défaite…"
		if winner_id == World.NO_PLAYER:
			result = "Vous avez été éliminé." if not viewer_alive else "Plus personne en lice."
	content.add_child(_label(headline, 30, INK))
	content.add_child(_label(result, 16, MUTED_INK))
	content.add_child(_legend(names, colors))

	var charts := HBoxContainer.new()
	charts.add_theme_constant_override("separation", 12)
	content.add_child(charts)
	var chart_list: Array[HistoryChart] = []
	var titles := {GameHistory.POPULATION: ["Population", Icons.POPULATION],
			GameHistory.SCIENCE: ["Science", Icons.SCIENCE], GameHistory.FOOD: ["Food / cycle", Icons.FOOD]}
	for metric in GameHistory.METRICS:
		var chart := HistoryChart.new()
		chart.history = history
		chart.metric = metric
		chart.title = titles[metric][0]
		chart.icon = titles[metric][1]
		chart.player_names = names
		chart.player_colors = colors
		chart.custom_minimum_size = CHART_SIZE
		charts.add_child(chart)
		chart_list.append(chart)
	# Un seul réticule partagé : survoler un graphique place le même instant sur les trois.
	for chart in chart_list:
		chart.hovered.connect(func(index: int) -> void:
			for other in chart_list:
				other.hover_index = index)

	var menu := _main_button("Menu principal")
	menu.pressed.connect(menu_requested.emit)
	content.add_child(menu)


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
