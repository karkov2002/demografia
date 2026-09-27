class_name GameClock
extends RefCounted
## Horloge de jeu : transforme le temps réel écoulé en cycles. Après un blocage (fenêtre déplacée,
## ralentissement…), tous les cycles manqués sont rattrapés d'un coup ; la durée d'une partie ne
## dépend donc pas de la puissance de la machine.

## Émis une fois par cycle écoulé.
signal cycle

## Durée d'un cycle, en secondes.
var cycle_duration: float
## Multiplicateur de vitesse (2 = deux fois plus rapide).
var speed: float = 1.0
var running: bool = false

var _elapsed: float = 0.0  # temps accumulé dans le cycle en cours


func _init(duration: float) -> void:
	cycle_duration = duration


func advance(delta: float) -> void:
	if not running:
		return
	_elapsed += delta * speed
	while _elapsed >= cycle_duration:
		_elapsed -= cycle_duration
		cycle.emit()


## Part écoulée du cycle en cours, de 0 à 1.
func cycle_fraction() -> float:
	return _elapsed / cycle_duration
