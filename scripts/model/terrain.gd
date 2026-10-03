class_name Terrain
extends RefCounted
## Types de terrain d'une case. Leurs effets sont réglés dans GameRules : capacité (la règle d'or),
## food produite par worker, or des workers (montagne) et défense (montagne, colline).

## Les nouveaux types s'ajoutent à la fin : leur valeur sert de clé dans les réglages.
enum Type { PRAIRIE, MOUNTAIN, WATER, FOREST, HILL, MARSH }

## Nom affiché de chaque terrain.
const NAMES := {
	Type.PRAIRIE: "plaine",
	Type.MOUNTAIN: "montagne",
	Type.WATER: "eau",
	Type.FOREST: "forêt",
	Type.HILL: "colline",
	Type.MARSH: "marais",
}
