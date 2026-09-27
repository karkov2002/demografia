class_name Population
extends RefCounted
## Effectifs d'une case par rôle, et leur croissance à chaque cycle.

## Rôles, dans l'ordre d'affichage.
const ROLES := ["worker", "scientist", "fighter"]

## Pseudo-rôle utilisable dans les transferts : les colons, des workers mis de côté pour partir
## coloniser une case voisine. Ils ne se reproduisent pas mais comptent dans la population de la case.
const SETTLER := "settler"
## Pseudo-rôle utilisable dans les transferts : la troupe, des fighters rassemblés pour partir vers une
## case voisine (renfort ou attaque). Comme les colons, elle compte dans la population de la case.
const ARMY := "army"

## Rôle → effectif, en flottant (l'affichage arrondit à l'entier inférieur).
var counts: Dictionary[String, float] = {}
## Colons prêts à partir.
var settlers: int = 0
## Fighters de la troupe prêts à partir.
var army: int = 0
## Identifiant du joueur à qui appartient cette population.
var owner: int


func _init(owner_id: int, initial: Dictionary[String, float] = {}) -> void:
	owner = owner_id
	for role in ROLES:
		counts[role] = initial.get(role, 0.0)


func total() -> float:
	var sum := float(settlers + army)
	for role in counts:
		sum += counts[role]
	return sum


## Nombre entier d'individus, tous rôles, colons et troupe compris, celui qu'affiche le jeu.
func whole_total() -> int:
	var sum := settlers + army
	for role in counts:
		sum += whole(role)
	return sum


## Nombre entier d'individus de `role` (ou de colons, ou de la troupe), celui qu'affiche le jeu.
func whole(role: String) -> int:
	if role == SETTLER:
		return settlers
	if role == ARMY:
		return army
	# Marge pour qu'un 3.9999… dû aux arrondis flottants compte bien pour 4.
	return floori(counts[role] + 1e-6)


## Plus aucun worker, scientist ou fighter entier, ni fighter dans la troupe (les colons ne défendent
## pas la case).
func is_defenseless() -> bool:
	if army >= 1:
		return false
	for role in counts:
		if whole(role) >= 1:
			return false
	return true


## Retire jusqu'à `amount` individus entiers de `role` ; renvoie le nombre retiré.
func lose(role: String, amount: int) -> int:
	var lost := mini(amount, whole(role))
	counts[role] -= lost
	return lost


func can_transfer(from_role: String, amount: int = 1) -> bool:
	return whole(from_role) >= amount


## Fait passer jusqu'à `amount` individus de `from_role` à `to_role`, dans la limite des individus
## entiers disponibles ; renvoie le nombre réellement déplacé.
func transfer(from_role: String, to_role: String, amount: int = 1) -> int:
	var moved := mini(amount, whole(from_role))
	if moved <= 0:
		return 0
	_add(from_role, -moved)
	_add(to_role, moved)
	return moved


func _add(role: String, amount: int) -> void:
	match role:
		SETTLER:
			settlers += amount
		ARMY:
			army += amount
		_:
			counts[role] += amount


## Applique `rates` (rôle → multiplicateur) sans que le total dépasse `capacity` (règle d'or) :
## si la place manque, la place restante est partagée au prorata de la croissance de chaque rôle.
## Un rôle sans au moins un individu entier ne se reproduit pas.
func grow(rates: Dictionary[String, float], capacity: float) -> void:
	var growth: Dictionary[String, float] = {}
	var total_growth := 0.0
	for role in counts:
		growth[role] = counts[role] * (rates.get(role, 1.0) - 1.0) if can_grow(role) else 0.0
		total_growth += growth[role]
	if total_growth <= 0.0:
		return
	var ratio := minf(1.0, maxf(0.0, capacity - total()) / total_growth)
	for role in counts:
		counts[role] += growth[role] * ratio


## Avancement (0 à 1) de chaque rôle vers sa prochaine unité, en temps : la croissance est
## supposée continue entre deux cycles, `cycle_fraction` étant la part écoulée du cycle en cours.
## Les rôles qui ne se reproduisent jamais (taux ≤ 1) sont absents du résultat ; 0 pour un rôle
## bloqué pour l'instant (aucun individu entier, case pleine).
func progress(rates: Dictionary[String, float], capacity: float, cycle_fraction: float) -> Dictionary[String, float]:
	var full := total() >= capacity - 1e-6
	var result: Dictionary[String, float] = {}
	for role in counts:
		var rate: float = rates.get(role, 1.0)
		if rate <= 1.0:
			continue
		if full or not can_grow(role):
			result[role] = 0.0
			continue
		# Temps écoulé depuis `reached` rapporté au temps pour passer de `reached` à `reached + 1`.
		var reached := float(whole(role))
		var current := counts[role] * pow(rate, cycle_fraction)
		result[role] = clampf(log(current / reached) / log((reached + 1.0) / reached), 0.0, 1.0)
	return result


## Il faut au moins un individu entier pour qu'un rôle se reproduise.
func can_grow(role: String) -> bool:
	return whole(role) >= 1
