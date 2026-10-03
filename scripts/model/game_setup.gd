class_name GameSetup
extends RefCounted
## Paramètres d'une nouvelle partie, choisis dans la fenêtre « New game » et lus au lancement du jeu.

## Côté minimal absolu de la carte ; chaque type de carte a le sien, selon le nombre de joueurs (voir
## MapGenerator.min_side).
const MIN_SIZE := 4
const MAX_SIZE := 20
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4

## Paramètres de la prochaine partie ; null tant qu'aucun n'a été choisi (la scène de jeu lancée
## directement prend alors les valeurs par défaut).
static var current: GameSetup

var columns: int = 10
var rows: int = 10
## Type de carte (MapGenerator.MapType).
var map_type: int = MapGenerator.MapType.CONTINENTS
## Pour chaque joueur, dans l'ordre (qui fixe aussi son identifiant et sa couleur) : IA ou humain.
## Le premier est le joueur local, humain.
var ai_players: Array[bool] = [false, true]
## Pour chaque joueur, dans le même ordre : niveau de l'IA (AIProfile.Level), ignoré pour un humain.
var ai_levels: Array[int] = [AIProfile.Level.NORMAL, AIProfile.Level.NORMAL]
