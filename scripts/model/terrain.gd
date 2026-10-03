class_name Terrain
extends RefCounted
## Types de terrain d'une case. Leurs effets sont réglés dans GameRules : capacité (la règle d'or),
## food produite par worker, or des workers (montagne) et défense (montagne, colline).

## Les nouveaux types s'ajoutent à la fin : leur valeur sert de clé dans les réglages.
enum Type { PRAIRIE, MOUNTAIN, WATER, FOREST, HILL, MARSH }

## Nom affiché de chaque terrain (clé de texte, voir Locale).
const NAMES := {
	Type.PRAIRIE: "TERRAIN_PRAIRIE",
	Type.MOUNTAIN: "TERRAIN_MOUNTAIN",
	Type.WATER: "TERRAIN_WATER",
	Type.FOREST: "TERRAIN_FOREST",
	Type.HILL: "TERRAIN_HILL",
	Type.MARSH: "TERRAIN_MARSH",
}
