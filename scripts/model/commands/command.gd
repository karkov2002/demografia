class_name Command
extends RefCounted
## Action d'un joueur sur le monde. Humains et IA passent par les mêmes commandes, exécutées par
## World.execute qui en vérifie la validité pour `player_id` (un joueur n'agit que sur ses propres
## cases). En réseau, ce sont ces commandes qui transiteront entre les machines.

var player_id: int


## Applique la commande à `world` ; renvoie false si elle n'est pas valide. À redéfinir.
func apply(_world: World) -> bool:
	return false
