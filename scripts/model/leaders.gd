class_name Leaders
extends RefCounted
## Dirigeants des IA : des personnalités célèbres, tirées au hasard selon le niveau de l'IA, sans doublon
## dans une partie. Chacun a son nom (clé de texte LEADER_<ID>, voir Locale) et son portrait en pixel art
## (res://assets/portraits/<id>.png, généré par res://tools/generate_portraits.gd).

const BY_LEVEL := {
	AIProfile.Level.AGGRESSIVE: ["alexander", "caesar", "attila", "genghis", "ivan", "napoleon", "mao"],
	AIProfile.Level.NORMAL: ["augustus", "charlemagne", "elizabeth", "louis_xiv", "lincoln", "taizong", "churchill"],
	AIProfile.Level.PACIFIST: ["gandhi", "mlk", "mandela", "dalai_lama", "saint_louis", "marcus_aurelius", "confucius"],
}


## Dirigeant tiré au hasard pour une IA de niveau `level`, parmi ceux qui ne sont pas déjà dans `taken`
## (tous si la liste est épuisée).
static func pick(level: AIProfile.Level, rng: RandomNumberGenerator, taken: Array) -> String:
	var free: Array = BY_LEVEL[level].filter(func(id: String) -> bool: return id not in taken)
	if free.is_empty():
		free = BY_LEVEL[level]
	return free[rng.randi_range(0, free.size() - 1)]


## Nom affiché du dirigeant `id`, dans la langue du jeu.
static func display_name(id: String) -> String:
	return Locale.text("LEADER_" + id.to_upper())


## Portrait d'un dirigeant pas encore rencontré.
static func unknown_portrait() -> Texture2D:
	return load("res://assets/portraits/unknown.png")


## Portrait du dirigeant `id`.
static func portrait(id: String) -> Texture2D:
	return load("res://assets/portraits/%s.png" % id)
