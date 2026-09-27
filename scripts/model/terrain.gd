class_name Terrain
extends RefCounted
## Types de terrain d'une case.

enum Type { PRAIRIE, MOUNTAIN, WATER }

## Règle d'or : population maximale d'une case, tous rôles confondus. Ne peut jamais être dépassée.
const CAPACITY := {Type.PRAIRIE: 1024.0, Type.MOUNTAIN: 256.0, Type.WATER: 0.0}
