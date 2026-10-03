class_name SoundFx
extends Node
## Bruitages du jeu (sons CC0, voir res://assets/sounds/CREDITS.md). Chaque bruitage est composé de
## plusieurs sons joués à des instants, volumes et hauteurs un peu tirés au hasard, pour ne jamais sonner
## exactement pareil :
## - battle : mêlée d'une case en guerre (une lame tirée, puis des chocs de fer) ;
## - wagon : chariot de colons en route (grincement et cahots des roues, le temps du trajet) ;
## - victory : clameur de foule ; city : clameur plus légère et plus aiguë (ville fondée) ;
##   defeat : choc sourd et rumeur de foule, plus grave et plus lente ;
## - click : petit clic de bouton, joué automatiquement par tous les boutons de la scène (fenêtres
##   ouvertes ensuite comprises) ; laser : petit tir laser du bouton Boost.

const BLADES: Array[AudioStream] = [
	preload("res://assets/sounds/blade_0.ogg"),
	preload("res://assets/sounds/blade_1.ogg"),
	preload("res://assets/sounds/blade_2.ogg"),
]
const CLASHES: Array[AudioStream] = [
	preload("res://assets/sounds/clash_0.ogg"),
	preload("res://assets/sounds/clash_1.ogg"),
	preload("res://assets/sounds/clash_2.ogg"),
	preload("res://assets/sounds/clash_3.ogg"),
	preload("res://assets/sounds/clash_4.ogg"),
]
const WAGON_CREAKS: Array[AudioStream] = [
	preload("res://assets/sounds/wagon_creak_0.ogg"),
	preload("res://assets/sounds/wagon_creak_1.ogg"),
	preload("res://assets/sounds/wagon_creak_2.ogg"),
]
const WAGON_BUMPS: Array[AudioStream] = [
	preload("res://assets/sounds/wagon_bump_0.ogg"),
	preload("res://assets/sounds/wagon_bump_1.ogg"),
	preload("res://assets/sounds/wagon_bump_2.ogg"),
	preload("res://assets/sounds/wagon_bump_3.ogg"),
	preload("res://assets/sounds/wagon_bump_4.ogg"),
]
const CLICKS: Array[AudioStream] = [
	preload("res://assets/sounds/click_0.ogg"),
	preload("res://assets/sounds/click_1.ogg"),
	preload("res://assets/sounds/click_2.ogg"),
	preload("res://assets/sounds/click_3.ogg"),
	preload("res://assets/sounds/click_4.ogg"),
]
const LASERS: Array[AudioStream] = [
	preload("res://assets/sounds/laser_0.ogg"),
	preload("res://assets/sounds/laser_1.ogg"),
	preload("res://assets/sounds/laser_2.ogg"),
	preload("res://assets/sounds/laser_3.ogg"),
	preload("res://assets/sounds/laser_4.ogg"),
]
const CROWD: AudioStream = preload("res://assets/sounds/crowd.ogg")
const DEFEAT_THUD: AudioStream = preload("res://assets/sounds/defeat_thud.ogg")
## Sons joués en même temps au maximum ; au-delà, le plus ancien est coupé.
const VOICES := 12
## Durée (s) de l'extrait de foule, et de son fondu de sortie.
const CROWD_DURATION := 2.6
const CROWD_FADE := 0.8

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	# Clic sur tous les boutons, présents et à venir.
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_hook_button(node)
	get_tree().node_added.connect(_hook_button)


## Petit clic de bouton.
func click() -> void:
	_play(_pick(CLICKS), -6.0, _rng.randf_range(0.95, 1.08))


## Petit tir laser (bouton Boost), un peu plus aigu ou grave à chaque fois.
func laser() -> void:
	_play(_pick(LASERS), -10.0, _rng.randf_range(0.9, 1.15))


func _hook_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(click):
		node.pressed.connect(click)


## Mêlée : une lame tirée, puis quatre chocs de fer en 1,2 s environ.
func battle() -> void:
	_play(_pick(BLADES), -8.0, _rng.randf_range(0.9, 1.1))
	for i in 4:
		_later(0.15 + i * 0.25 + _rng.randf() * 0.1, func() -> void:
			_play(_pick(CLASHES), -4.0, _rng.randf_range(0.85, 1.15)))


## Chariot : un grincement, et les cahots des roues pendant `seconds` (la durée du trajet).
func wagon(seconds: float) -> void:
	_play(_pick(WAGON_CREAKS), -10.0, _rng.randf_range(0.9, 1.1))
	var bumps := maxi(2, roundi(seconds / 0.2))
	for i in bumps:
		_later(i * seconds / bumps + _rng.randf() * 0.05, func() -> void:
			_play(_pick(WAGON_BUMPS), -12.0, _rng.randf_range(0.75, 0.95)))


## Victoire : clameur de foule.
func victory() -> void:
	_play_crowd(-2.0, 1.05)


## Ville fondée : clameur de foule plus légère et plus aiguë que celle d'une victoire.
func city() -> void:
	_play_crowd(-8.0, 1.2)


## Défaite : choc sourd, puis rumeur de foule plus grave et plus lente, comme consternée.
func defeat() -> void:
	_play(DEFEAT_THUD, -4.0, 0.8)
	_play_crowd(-6.0, 0.72)


## Extrait de CROWD_DURATION secondes de la foule, pris à un endroit tiré au hasard, qui finit en fondu.
func _play_crowd(volume_db: float, pitch: float) -> void:
	var start := _rng.randf_range(0.0, CROWD.get_length() - CROWD_DURATION * 1.5)
	var player := _play(CROWD, volume_db, pitch, start)
	var fade := create_tween()
	fade.tween_interval(CROWD_DURATION - CROWD_FADE)
	fade.tween_property(player, "volume_db", -60.0, CROWD_FADE)
	fade.tween_callback(player.stop)


## Joue `stream` sur le prochain lecteur (le plus ancien est réutilisé), à partir de `from` secondes.
func _play(stream: AudioStream, volume_db: float, pitch: float, from: float = 0.0) -> AudioStreamPlayer:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play(from)
	return player


func _pick(streams: Array[AudioStream]) -> AudioStream:
	return streams[_rng.randi() % streams.size()]


func _later(seconds: float, action: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(action)
