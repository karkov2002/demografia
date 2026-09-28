class_name BackgroundMusic
extends Node
## Musique de fond, discrète, de style antique (musiques CC0, voir res://assets/music/CREDITS.md) : les
## morceaux s'enchaînent en boucle, chacun commençant par un fondu d'entrée.

const TRACKS: Array[AudioStream] = [
	preload("res://assets/music/greek_instruments.ogg"),
	preload("res://assets/music/ancient_mysteries.ogg"),
]
## Volume (dB) : bas, pour rester en fond sous les bruitages.
const VOLUME_DB := -20.0
## Durée (s) du fondu d'entrée de chaque morceau.
const FADE_IN := 3.0

var _player := AudioStreamPlayer.new()
var _track: int = 0


func _ready() -> void:
	add_child(_player)
	_player.finished.connect(_next_track)
	# Premier morceau tiré au hasard, pour ne pas toujours commencer par le même.
	_track = randi() % TRACKS.size()
	_play_track()


func _next_track() -> void:
	_track = (_track + 1) % TRACKS.size()
	_play_track()


func _play_track() -> void:
	_player.stream = TRACKS[_track]
	_player.volume_db = -60.0
	_player.play()
	create_tween().tween_property(_player, "volume_db", VOLUME_DB, FADE_IN)
