class_name GameSetup
extends RefCounted
## Paramètres d'une nouvelle partie, choisis dans la fenêtre « New game » et lus au lancement du jeu.

const MIN_SIZE := 2
const MAX_SIZE := 20
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4

## Paramètres de la prochaine partie ; null tant qu'aucun n'a été choisi (la scène de jeu lancée
## directement prend alors les valeurs par défaut).
static var current: GameSetup

var columns: int = 10
var rows: int = 10
## Pour chaque joueur, dans l'ordre (qui fixe aussi son identifiant et sa couleur) : IA ou humain.
## Le premier est le joueur local, humain.
var ai_players: Array[bool] = [false, true]
