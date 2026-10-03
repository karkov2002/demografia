class_name Locale
extends RefCounted
## Textes du jeu dans la langue choisie. Tous les textes affichés sont rangés par clé dans
## res://translations/translate.<langue> (une ligne « CLÉ = texte »), chargé une fois dans le
## TranslationServer de Godot. Le code n'écrit jamais un texte affiché en dur : il demande text(clé).

const DIRECTORY := "res://translations/"
const DEFAULT_LANGUAGE := "en"

## Langue chargée, ou "" tant qu'aucune ne l'est.
static var language: String = ""


## Charge les textes de `code` (translate.<code>) et en fait la langue du jeu.
static func load_language(code: String = DEFAULT_LANGUAGE) -> void:
	var path := DIRECTORY + "translate." + code
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Textes introuvables : %s" % path)
		return
	var translation := Translation.new()
	translation.locale = code
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var separator := line.find("=")
		if separator < 0:
			continue
		var key := line.left(separator).strip_edges()
		translation.add_message(key, line.substr(separator + 1).strip_edges().replace("\\n", "\n"))
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(code)
	language = code


## Texte de la clé `key`, ses marqueurs {nom} remplacés par `values` ({ "nom": valeur }). Charge la langue
## par défaut au premier appel.
static func text(key: String, values: Dictionary = {}) -> String:
	if language == "":
		load_language()
	return String(TranslationServer.translate(key)).format(values)
