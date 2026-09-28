extends SceneTree
## Simulation d'équilibrage : joue N parties entre IA, sans affichage et en accéléré, puis écrit un
## rapport (victoires, durées, batailles, conquêtes, et moyennes par niveau d'IA). Permet de changer des
## réglages de GameRules ou des profils d'IA le temps d'une simulation, pour mesurer leur effet.
##
## Usage :
##   godot --headless --path . -s res://tools/balance_sim.gd -- [options]
## Options (toutes facultatives) :
##   games=10                  nombre de parties
##   players=pacifist,normal,aggressive,normal
##                             niveau de chaque IA (2 à 4 joueurs : pacifist, normal, aggressive)
##   size=10x10                taille de la carte
##   minutes=30                durée maximale d'une partie (temps de jeu)
##   seed=1                    graine de la première partie (les suivantes : seed + 1, seed + 2…)
##   rules.<réglage>=<valeur>  change un réglage de GameRules (ex. rules.army_per_garrison=3)
##   <niveau>.<réglage>=<valeur>
##                             change un réglage d'un profil d'IA (ex. aggressive.attack_margin=1.5)
##   report=<fichier.md>       écrit aussi le rapport dans ce fichier
##
## Le déroulement reproduit celui du jeu (main.gd) : à chaque cycle, le monde avance (tick), chaque IA
## joue ses commandes, puis l'horloge rapide fait la famine et le trajet des colons et des troupes.

## Instants (s de jeu) où le rapport relève les cases de chacun, pour mesurer la vitesse d'expansion.
const SNAPSHOTS := [300.0, 600.0]
const LEVELS := {
	"pacifist": AIProfile.Level.PACIFIST,
	"normal": AIProfile.Level.NORMAL,
	"aggressive": AIProfile.Level.AGGRESSIVE,
}

var _options := {
	"games": "10",
	"players": "pacifist,normal,aggressive,normal",
	"size": "10x10",
	"minutes": "30",
	"seed": "1",
	"report": "",
}
var _rule_overrides := {}
var _profile_overrides := {}  # niveau → { réglage: valeur }


func _init() -> void:
	if not _parse_arguments():
		quit(1)
		return
	var levels: Array[String] = []
	for name in _options.players.split(","):
		levels.append(name.strip_edges())
	var games := int(_options.games)
	var results: Array[Dictionary] = []
	for game in games:
		var result := _play(levels, int(_options.seed) + game)
		results.append(result)
		print("Partie %d/%d : %s en %s (%d batailles, %d conquêtes)" % [game + 1, games,
				_winner_text(result), _duration(result.duration), result.battles, result.conquests])
	var report := _report(levels, results)
	print("\n" + report)
	if _options.report != "":
		var file := FileAccess.open(_options.report, FileAccess.WRITE)
		file.store_string(report)
		print("Rapport écrit dans ", _options.report)
	quit()


## Lit les options de la ligne de commande ; renvoie false (après un message) si l'une est invalide.
func _parse_arguments() -> bool:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			printerr("Option invalide (attendu nom=valeur) : ", argument)
			return false
		var key := parts[0]
		if _options.has(key):
			_options[key] = parts[1]
		elif key.begins_with("rules."):
			_rule_overrides[key.trim_prefix("rules.")] = parts[1]
		elif key.contains(".") and LEVELS.has(key.get_slice(".", 0)):
			var level := key.get_slice(".", 0)
			if not _profile_overrides.has(level):
				_profile_overrides[level] = {}
			_profile_overrides[level][key.get_slice(".", 1)] = parts[1]
		else:
			printerr("Option inconnue : ", key)
			return false
	return true


## Donne à la propriété `property` de `resource` la valeur `text`, convertie dans le type de la valeur
## actuelle ; renvoie false (après un message) si la propriété n'existe pas.
func _override(resource: Resource, property: String, text: String) -> bool:
	var current: Variant = resource.get(property)
	if current == null:
		printerr("Réglage inconnu : ", property)
		return false
	match typeof(current):
		TYPE_INT:
			resource.set(property, int(text))
		TYPE_FLOAT:
			resource.set(property, float(text))
		TYPE_BOOL:
			resource.set(property, text == "true")
		_:
			resource.set(property, text)
	return true


## Joue une partie entre les IA `levels` avec la graine `seed` ; renvoie ses mesures.
func _play(levels: Array[String], seed_value: int) -> Dictionary:
	var rules: GameRules = load("res://data/game_rules.tres").duplicate(true)
	var size: PackedStringArray = _options.size.split("x")
	rules.columns = int(size[0])
	rules.rows = int(size[1])
	for property in _rule_overrides:
		_override(rules, property, _rule_overrides[property])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var world := World.new(rules)
	MapGenerator.generate(world, rng, levels.size())
	var ais: Array[AIController] = []
	for level in levels:
		var profile: AIProfile = AIProfile.of_level(LEVELS[level]).duplicate()
		for property in _profile_overrides.get(level, {}):
			_override(profile, property, _profile_overrides[level][property])
		var player := world.add_player(true, profile.growth_factor)
		ais.append(AIController.new(world, player.id, rng, profile))
	for ai in ais:
		var command := ai.choose_start()
		if command != null:
			world.execute(command)

	var result := {"duration": 0.0, "winner": World.NO_PLAYER, "battles": 0, "conquests": 0, "players": []}
	var eliminated := {}
	world.owner_changed.connect(func(_cell: Vector2i, _previous: int, new_owner: int, by_war: bool) -> void:
		if by_war and new_owner != World.NO_PLAYER:
			result.conquests += 1)
	var known_battles := {}
	var snapshots := {}  # instant (s) → cases de chaque joueur
	var fast_steps := roundi(rules.cycle_duration / rules.starvation_interval)
	var cycles := roundi(float(_options.minutes) * 60.0 / rules.cycle_duration)
	for cycle in cycles:
		world.tick()
		for ai in ais:
			for command in ai.play_cycle():
				world.execute(command)
		for step in fast_steps:
			world.starve()
			world.move_convoys(rules.starvation_interval)
		for cell in world.battle_cells():
			if not known_battles.has(cell):
				result.battles += 1
		known_battles.clear()
		for cell in world.battle_cells():
			known_battles[cell] = true
		result.duration = (cycle + 1) * rules.cycle_duration
		for player in world.players:
			if not eliminated.has(player.id) and world.total_population(player.id) == 0:
				eliminated[player.id] = result.duration
		# Vitesse d'expansion : cases de chacun à chaque instant de SNAPSHOTS.
		for moment in SNAPSHOTS:
			if is_equal_approx(result.duration, moment):
				snapshots[moment] = _cells_by_player(world)
		if world.is_game_over():
			break
	result.winner = world.winner()
	# Partie finie avant un instant de SNAPSHOTS : les cases de la fin comptent.
	for moment in SNAPSHOTS:
		if not snapshots.has(moment):
			snapshots[moment] = _cells_by_player(world)
	for i in levels.size():
		var player := {
			"level": levels[i],
			"eliminated_at": eliminated.get(i, -1.0),
			"population": world.total_population(i),
			"cells": world.cells_of(i).size(),
			"science": world.player(i).science,
		}
		for moment in SNAPSHOTS:
			player["cells_%d" % moment] = snapshots[moment][i]
		result.players.append(player)
	return result


func _cells_by_player(world: World) -> Array[int]:
	var cells: Array[int] = []
	for player in world.players:
		cells.append(world.cells_of(player.id).size())
	return cells


## Rapport en Markdown : réglages modifiés, chaque partie, puis les moyennes par niveau d'IA.
func _report(levels: Array[String], results: Array[Dictionary]) -> String:
	var lines: Array[String] = ["# Simulation d'équilibrage", ""]
	lines.append("%d parties, joueurs : %s, carte %s, %s min au plus, graines %s à %d." % [results.size(),
			", ".join(levels), _options.size, _options.minutes, _options.seed, int(_options.seed) + results.size() - 1])
	var changes: Array[String] = []
	for property in _rule_overrides:
		changes.append("rules.%s=%s" % [property, _rule_overrides[property]])
	for level in _profile_overrides:
		for property in _profile_overrides[level]:
			changes.append("%s.%s=%s" % [level, property, _profile_overrides[level][property]])
	lines.append("Réglages modifiés : %s." % (", ".join(changes) if not changes.is_empty() else "aucun"))
	lines.append_array(["", "## Parties", "", "| Partie | Résultat | Durée | Batailles | Conquêtes |", "|---|---|---|---|---|"])
	for i in results.size():
		var result := results[i]
		lines.append("| %d | %s | %s | %d | %d |" % [i + 1, _winner_text(result), _duration(result.duration),
				result.battles, result.conquests])
	# Moyennes par niveau (un niveau présent plusieurs fois compte chacune de ses IA).
	var stats := {}
	for result in results:
		for i in result.players.size():
			var player: Dictionary = result.players[i]
			var level: String = player.level
			if not stats.has(level):
				stats[level] = {"count": 0, "wins": 0, "eliminated": 0, "survival": 0.0, "population": 0.0,
						"cells": 0.0, "science": 0.0, "cells_300": 0.0, "cells_600": 0.0}
			var entry: Dictionary = stats[level]
			entry.count += 1
			entry.cells_300 += player.cells_300
			entry.cells_600 += player.cells_600
			if result.winner == i:
				entry.wins += 1
			if player.eliminated_at >= 0.0:
				entry.eliminated += 1
			entry.survival += player.eliminated_at if player.eliminated_at >= 0.0 else result.duration
			entry.population += player.population
			entry.cells += player.cells
			entry.science += player.science
	lines.append_array(["", "## Par niveau d'IA", "",
			"| Niveau | IA | Victoires | Éliminées | Survie moyenne | Cases à 5 min | à 10 min | à la fin | Population finale | Science |",
			"|---|---|---|---|---|---|---|---|---|---|"])
	for level in stats:
		var entry: Dictionary = stats[level]
		var count: float = entry.count
		lines.append("| %s | %d | %d (%d %%) | %d | %s | %.1f | %.1f | %.1f | %d | %d |" % [level, entry.count,
				entry.wins, roundi(100.0 * entry.wins / count), entry.eliminated, _duration(entry.survival / count),
				entry.cells_300 / count, entry.cells_600 / count, entry.cells / count, roundi(entry.population / count),
				roundi(entry.science / count)])
	lines.append("")
	return "\n".join(lines)


func _winner_text(result: Dictionary) -> String:
	if result.winner == World.NO_PLAYER:
		return "pas de vainqueur"
	return "victoire de l'IA %d (%s)" % [result.winner + 1, result.players[result.winner].level]


func _duration(seconds: float) -> String:
	return "%d min %02d" % [floori(seconds / 60.0), roundi(seconds) % 60]
