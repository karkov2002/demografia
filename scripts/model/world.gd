class_name World
extends RefCounted
## État de la partie : terrain de chaque case (indices à partir de 0), joueurs, et population de
## chaque case occupée (une case n'appartient qu'à un joueur à la fois). Toutes les actions des
## joueurs passent par execute() avec une commande, qui vérifie qu'ils n'agissent que sur leurs cases.

## Émis à chaque changement de population ou de ressources.
signal changed
## Émis quand `cell` change de propriétaire (World.NO_PLAYER quand personne) : par la guerre
## (`by_war`, défenseur tombé ou conquête) ou par la colonisation.
signal owner_changed(cell: Vector2i, previous_owner: int, new_owner: int, by_war: bool)
## Émis quand un village passe en ville.
signal city_founded(cell: Vector2i)
## Émis quand une ville redevient un village : rétrogradée par son propriétaire, ou par la famine
## (`by_famine`).
signal city_lost(cell: Vector2i, by_famine: bool)

const NO_CELL := Vector2i(-1, -1)
const NO_PLAYER := -1

var rules: GameRules
var columns: int
var rows: int
var players: Array[Player] = []
## Cases dont un scientist ou fighter a été reconverti en worker au dernier cycle, faute d'or.
var bankrupt_cells: Array[Vector2i] = []

var _terrains: Dictionary[Vector2i, Terrain.Type] = {}
var _populations: Dictionary[Vector2i, Population] = {}
## Depuis combien de secondes chaque case affamée manque de food.
var _hunger: Dictionary[Vector2i, float] = {}
## Depuis combien de secondes chaque case surpeuplée dépasse sa capacité.
var _overcrowding: Dictionary[Vector2i, float] = {}
## Batailles en cours, par case attaquée.
var _battles: Dictionary[Vector2i, Battle] = {}
## Colons en route vers une case voisine.
var _convoys: Array[Convoy] = []
## Cases passées en ville (les autres cases peuplées sont des villages). Le statut reste attaché à la
## case quand elle change de main par la guerre ; il se perd quand elle se vide.
var _cities: Dictionary[Vector2i, bool] = {}


func _init(game_rules: GameRules) -> void:
	rules = game_rules
	columns = rules.columns
	rows = rules.rows


# --- Joueurs et brouillard de guerre -----------------------------------------------------------

## Ajoute un joueur, à appeler une fois la carte générée : il connaît d'emblée les mers.
func add_player(is_ai: bool, growth_factor: float) -> Player:
	var new_player := Player.new(players.size(), is_ai, growth_factor)
	for row in rows:
		for column in columns:
			var cell := Vector2i(column, row)
			if capacity(cell) <= 0.0:
				new_player.explore(cell)
	players.append(new_player)
	return new_player


func player(player_id: int) -> Player:
	return players[player_id]


## Le joueur connaît-il le terrain de `cell` ? Il découvre ses cases et leurs voisines, et s'en souvient.
func is_explored(player_id: int, cell: Vector2i) -> bool:
	return player(player_id).has_explored(cell)


## Le joueur voit-il `cell` en ce moment (population comprise) ? Oui pour ses cases et leurs voisines.
func is_visible(player_id: int, cell: Vector2i) -> bool:
	if owner(cell) == player_id:
		return true
	for neighbor in neighbors(cell):
		if owner(neighbor) == player_id:
			return true
	return false


## Le joueur découvre `cell` et ses voisines.
func _reveal_around(player_id: int, cell: Vector2i) -> void:
	player(player_id).explore(cell)
	for neighbor in neighbors(cell):
		player(player_id).explore(neighbor)


# --- Carte ---------------------------------------------------------------------------------------

## Une case sans terrain défini est une prairie.
func terrain(cell: Vector2i) -> Terrain.Type:
	return _terrains.get(cell, Terrain.Type.PRAIRIE)


func set_terrain(cell: Vector2i, type: Terrain.Type) -> void:
	_terrains[cell] = type
	changed.emit()


## Population maximale de `cell` (règle d'or) : celle de son terrain pour une ville, au plus
## rules.village_capacity pour un village.
func capacity(cell: Vector2i) -> float:
	var terrain_limit := terrain_capacity(cell)
	return terrain_limit if is_city(cell) else minf(terrain_limit, rules.village_capacity)


## Capacité du terrain de `cell`, celle d'une ville : c'est elle qui freine la croissance (courbe en S).
func terrain_capacity(cell: Vector2i) -> float:
	return rules.capacity.get(terrain(cell), 0.0)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


## Cases adjacentes à `cell` sur la carte (disposition « odd-r » : rangées impaires décalées à droite).
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	const EVEN_ROW := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)]
	const ODD_ROW := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var result: Array[Vector2i] = []
	for offset in (ODD_ROW if cell.y % 2 == 1 else EVEN_ROW):
		if is_inside(cell + offset):
			result.append(cell + offset)
	return result


# --- Populations ---------------------------------------------------------------------------------

## Population de la case, ou null si personne n'y vit.
func population(cell: Vector2i) -> Population:
	return _populations.get(cell)


## Joueur qui occupe `cell`, ou NO_PLAYER.
func owner(cell: Vector2i) -> int:
	var cell_population := population(cell)
	return NO_PLAYER if cell_population == null else cell_population.owner


func occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_populations.keys())
	return cells


func cells_of(player_id: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _populations:
		if _populations[cell].owner == player_id:
			cells.append(cell)
	return cells


## Population entière du joueur sur toute la carte, tous rôles, colons (en route compris), troupes et
## fighters engagés dans ses batailles compris.
func total_population(player_id: int) -> int:
	var total := 0
	for cell in cells_of(player_id):
		total += _populations[cell].whole_total()
	for current in _battles.values():
		total += current.fighters.get(player_id, 0)
	for convoy in _convoys:
		if convoy.player_id == player_id:
			total += convoy.units
	return total


## Joueurs encore en lice : ceux qui ont démarré et gardent au moins un individu.
func alive_players() -> Array[int]:
	var alive: Array[int] = []
	for current in players:
		if has_started(current.id) and total_population(current.id) > 0:
			alive.append(current.id)
	return alive


## La partie est finie une fois que tous les joueurs ont démarré et qu'au plus un reste en lice.
func is_game_over() -> bool:
	for current in players:
		if not has_started(current.id):
			return false
	return alive_players().size() <= 1


## Dernier joueur en lice une fois la partie finie, ou NO_PLAYER (partie en cours, ou plus personne).
func winner() -> int:
	var alive := alive_players()
	return alive[0] if is_game_over() and alive.size() == 1 else NO_PLAYER


## Places libres pour les habitants de `cell` avant d'atteindre sa capacité (règle d'or) ; les fighters
## qui y livrent bataille et les colons en route vers elle avec une place réservée (voir Convoy) en
## occupent aussi. La troupe n'en prend pas : elle a sa propre place (voir army_room).
func free_room(cell: Vector2i) -> int:
	var cell_population := population(cell)
	var used := 0.0 if cell_population == null else cell_population.residents()
	if _battles.has(cell):
		used += _battles[cell].total_fighters()
	for convoy in _convoys:
		if convoy.to_cell == cell and convoy.reserves_room and not convoy.is_army:
			used += convoy.units
	return maxi(0, floori(capacity(cell) - used + 1e-6))


## La case compte-t-elle plus d'habitants que sa capacité (règle d'or) ? Seule une bataille peut y
## mener : renforts et attaquants n'y sont pas limités.
func is_overcrowded(cell: Vector2i) -> bool:
	return population(cell) != null and population(cell).residents() > capacity(cell) + 1e-6


## Multiplicateurs de croissance du joueur : ceux des règles, dont l'accroissement est modulé par
## son facteur de croissance (1 + (taux - 1) × facteur).
func growth_rates(player_id: int) -> Dictionary[String, float]:
	var rates := rules.growth_rates()
	for role in rates:
		rates[role] = 1.0 + (rates[role] - 1.0) * player(player_id).growth_factor
	return rates


## Multiplicateurs de croissance de `cell` : ceux de son propriétaire, ralentis dans une ville
## (rules.city_growth_factor).
func cell_growth_rates(cell: Vector2i) -> Dictionary[String, float]:
	var rates := growth_rates(owner(cell))
	if is_city(cell):
		for role in rates:
			rates[role] = 1.0 + (rates[role] - 1.0) * rules.city_growth_factor
	return rates


## Avancement de chaque rôle de `cell` vers sa prochaine unité (voir Population.progress).
func progress(cell: Vector2i, cycle_fraction: float) -> Dictionary[String, float]:
	var cell_population := population(cell)
	if cell_population == null:
		return {}
	# Case en guerre : figée, aucune croissance en cours.
	var room := 0.0 if is_at_war(cell) else terrain_capacity(cell)
	return cell_population.progress(cell_growth_rates(cell), room, cycle_fraction, _growth_limit(cell))


## Plafond net de croissance de `cell` (voir Population.grow) : la capacité d'un village, aucun (0) pour
## une ville.
func _growth_limit(cell: Vector2i) -> float:
	return 0.0 if is_city(cell) else capacity(cell)


# --- Villages et villes --------------------------------------------------------------------------

## Toute case peuplée est d'abord un village : au plus rules.village_capacity individus, des workers qui
## produisent de la food, aucun scientist. Une ville grandit jusqu'à la capacité de son terrain et
## accueille des scientists, mais ses workers ne produisent plus de food : elle doit être nourrie par
## ses voisines.
func is_city(cell: Vector2i) -> bool:
	return _cities.has(cell)


## Une mégapole est une ville remplie à au moins rules.megapolis_threshold de la capacité de son
## terrain (habitants seulement) ; ses remparts renforcent sa garnison (voir garrison_bonus).
func is_megapolis(cell: Vector2i) -> bool:
	return is_city(cell) and population(cell) != null \
			and population(cell).residents() >= rules.megapolis_threshold * terrain_capacity(cell) - 1e-6


## Le joueur peut-il faire passer `cell` en ville ? Seulement un village à lui, en paix, plein (la
## troupe ne compte pas).
func can_found_city(player_id: int, cell: Vector2i) -> bool:
	return can_command(player_id, cell) and not is_city(cell) \
			and population(cell).residents() >= capacity(cell) - 1e-3


## Fait passer `cell` en ville ; renvoie false si c'est impossible (voir can_found_city).
func found_city(player_id: int, cell: Vector2i) -> bool:
	if not can_found_city(player_id, cell):
		return false
	_cities[cell] = true
	city_founded.emit(cell)
	changed.emit()
	return true


## Le joueur peut-il faire redevenir `cell` un village ? Seulement une ville à lui, en paix.
func can_downgrade_city(player_id: int, cell: Vector2i) -> bool:
	return can_command(player_id, cell) and is_city(cell)


## Fait redevenir `cell` un village (voir _make_village) ; renvoie false si c'est impossible (voir
## can_downgrade_city).
func downgrade_city(player_id: int, cell: Vector2i) -> bool:
	if not can_downgrade_city(player_id, cell):
		return false
	_make_village(cell)
	city_lost.emit(cell, false)
	changed.emit()
	return true


## La ville `cell` redevient un village : ses scientists redeviennent workers (un village n'en accueille
## pas), puis les habitants qui dépassent la capacité d'un village disparaissent : des workers d'abord,
## puis la garnison, puis les colons. La troupe, qui a sa propre place, reste entière.
func _make_village(cell: Vector2i) -> void:
	_cities.erase(cell)
	var cell_population := population(cell)
	cell_population.counts["worker"] += cell_population.counts["scientist"]
	cell_population.counts["scientist"] = 0.0
	var excess := cell_population.residents() - capacity(cell)
	for role in ["worker", "fighter"]:
		var lost := clampf(excess, 0.0, cell_population.counts[role])
		cell_population.counts[role] -= lost
		excess -= lost
	cell_population.settlers -= clampi(ceili(excess - 1e-6), 0, cell_population.settlers)


# --- Économie ------------------------------------------------------------------------------------

## Science produite par le joueur à chaque cycle, par les scientists de ses villes (rien par ses cases
## en guerre, qui sont figées, ni par ses villages).
func science_rate(player_id: int) -> float:
	var rate := 0.0
	for cell in cells_of(player_id):
		if is_city(cell) and not is_at_war(cell):
			rate += _populations[cell].whole("scientist") * rules.science_per_scientist
	return rate


## Or rapporté par `cell` à son propriétaire à chaque cycle (négatif si ses scientists et fighters
## coûtent plus que ses workers ne rapportent).
func cell_income(cell: Vector2i) -> float:
	var cell_population := population(cell)
	if cell_population == null:
		return 0.0
	var income := 0.0
	for role in rules.gold_per_role:
		var gold: float = rules.gold_per_role[role]
		if role == "worker" and is_city(cell):
			gold = rules.city_gold_per_worker
		income += cell_population.whole(role) * gold
	return income


## Or rapporté au joueur par toutes ses cases à chaque cycle.
func total_income(player_id: int) -> float:
	var income := 0.0
	for cell in cells_of(player_id):
		income += cell_income(cell)
	return income


## Encaisse le revenu du cycle du joueur. Si son or passe sous 0, il reste à 0 et des scientists ou
## fighters redeviennent workers, un à un (rules.conversions_per_cycle par cycle), en commençant
## chaque fois par la case du joueur qui en compte le plus.
func _collect_gold(player_id: int) -> void:
	var current := player(player_id)
	current.gold += total_income(player_id)
	if current.gold >= 0.0:
		return
	current.gold = 0.0
	for i in rules.conversions_per_cycle:
		var cell := _most_costly_cell(player_id)
		if cell == NO_CELL:
			return
		var cell_population := population(cell)
		var role := "scientist" if cell_population.whole("scientist") >= cell_population.whole("fighter") else "fighter"
		cell_population.transfer(role, "worker")
		if cell not in bankrupt_cells:
			bankrupt_cells.append(cell)


## Case du joueur qui compte le plus de scientists et fighters réunis, ou NO_CELL s'il n'y en a nulle part
## (les cases en guerre, figées, ne sont pas reconverties).
func _most_costly_cell(player_id: int) -> Vector2i:
	var best := NO_CELL
	var best_count := 0
	for cell in cells_of(player_id):
		if is_at_war(cell):
			continue
		var count := _populations[cell].whole("scientist") + _populations[cell].whole("fighter")
		if count > best_count:
			best = cell
			best_count = count
	return best


# --- Nourriture ----------------------------------------------------------------------------------

## Solde de food de `cell` à chaque cycle : production des workers (dans un village seulement) moins la
## consommation de chaque worker, scientist ou fighter de la garnison (rules.food_per_individual, ou
## rules.city_food_per_individual dans une ville), et de la ration de sa troupe (rules.army_food). Les
## colons ne mangent pas. La troupe est ainsi nourrie par sa case avant que le surplus ne soit exporté.
func food_balance(cell: Vector2i) -> float:
	var cell_population := population(cell)
	if cell_population == null:
		return 0.0
	var eaters := 0
	for role in cell_population.counts:
		eaters += cell_population.whole(role)
	var produced := 0.0 if is_city(cell) else cell_population.whole("worker") * rules.food_per_worker
	var ration := rules.city_food_per_individual if is_city(cell) else rules.food_per_individual
	return produced - eaters * ration - cell_population.army * rules.army_food


## Solde de food de toutes les cases du joueur.
func total_food_balance(player_id: int) -> float:
	var balance := 0.0
	for cell in cells_of(player_id):
		balance += food_balance(cell)
	return balance


## Food envoyée par `cell` à chaque voisine ({ voisine: quantité }) : son surplus va seulement aux
## voisines de son propriétaire qui manquent de food (solde négatif), en proportion de leur manque et
## sans le dépasser ; ce qui reste est perdu. Les cases en guerre, figées, n'envoient ni ne reçoivent
## rien. Vide sans surplus ou sans voisine dans le besoin.
func food_exports(cell: Vector2i) -> Dictionary[Vector2i, float]:
	var exports: Dictionary[Vector2i, float] = {}
	var surplus := food_balance(cell)
	if surplus <= 0.0 or is_at_war(cell):
		return exports
	var needs: Dictionary[Vector2i, float] = {}
	var total_need := 0.0
	for neighbor in neighbors(cell):
		if owner(neighbor) == owner(cell) and not is_at_war(neighbor):
			var need := -food_balance(neighbor)
			if need > 0.0:
				needs[neighbor] = need
				total_need += need
	var share := minf(1.0, surplus / total_need) if total_need > 0.0 else 0.0
	for neighbor in needs:
		exports[neighbor] = needs[neighbor] * share
	return exports


## Échanges de food de `cell` à chaque cycle : ce qu'elle reçoit de ses voisines moins ce qu'elle leur envoie.
func food_trade(cell: Vector2i) -> float:
	var trade := 0.0
	for amount in food_imports(cell).values():
		trade += amount
	for amount in food_exports(cell).values():
		trade -= amount
	return trade


## Food dont dispose `cell` à chaque cycle : son propre solde plus ce que lui envoient ses voisines.
func food_available(cell: Vector2i) -> float:
	var available := food_balance(cell)
	for amount in food_imports(cell).values():
		available += amount
	return available


## La case manque-t-elle de food (famine) ?
func is_starving(cell: Vector2i) -> bool:
	return population(cell) != null and food_available(cell) < 0.0


## Famine et surpeuplement, appelés toutes les rules.starvation_interval secondes. Une case qui manque
## de food depuis plus de rules.starvation_grace secondes perd un individu, en priorité un fighter de sa
## troupe, puis un scientist, puis un fighter de la garnison, puis un worker, jusqu'à retrouver
## l'équilibre. Une case qui dépasse sa capacité (après une bataille) depuis aussi longtemps perd de
## même un fighter de sa garnison, jusqu'à revenir à sa capacité. Une ville que la famine ramène à
## rules.village_capacity habitants ou moins redevient un village.
func starve() -> void:
	var starving: Array[Vector2i] = []
	var overcrowded: Array[Vector2i] = []
	for cell in _populations:
		# Une case en guerre est figée : ni la famine ni le surpeuplement n'y tuent.
		if is_at_war(cell):
			continue
		if is_starving(cell):
			starving.append(cell)
		if is_overcrowded(cell):
			overcrowded.append(cell)
	var deaths := false
	for cell in _due_deaths(_hunger, starving):
		if _kill_one(cell, [Population.ARMY, "scientist", "fighter", "worker"]):
			deaths = true
			# Une ville affamée retombée à la taille d'un village redevient un village.
			if is_city(cell) and population(cell).residents() <= rules.village_capacity + 1e-6:
				_make_village(cell)
				city_lost.emit(cell, true)
	for cell in _due_deaths(_overcrowding, overcrowded):
		deaths = _kill_one(cell, ["fighter"]) or deaths
	if deaths:
		changed.emit()


## Avance d'un intervalle le compteur de chacune des `cells` dans `timers`, les autres cases repartant
## de zéro ; renvoie celles dont le délai de grâce est écoulé.
func _due_deaths(timers: Dictionary[Vector2i, float], cells: Array[Vector2i]) -> Array[Vector2i]:
	for cell in timers.keys():
		if cell not in cells:
			timers.erase(cell)
	var due: Array[Vector2i] = []
	for cell in cells:
		timers[cell] = timers.get(cell, 0.0) + rules.starvation_interval
		if timers[cell] > rules.starvation_grace + 1e-6:
			due.append(cell)
	return due


## Un individu de `cell` meurt : du premier rôle de `death_order` qui en compte un entier (la troupe
## s'écrit Population.ARMY) ; renvoie false si personne n'est mort.
func _kill_one(cell: Vector2i, death_order: Array) -> bool:
	var cell_population := population(cell)
	for role in death_order:
		if cell_population.whole(role) < 1:
			continue
		if role == Population.ARMY:
			cell_population.army -= 1
		else:
			cell_population.counts[role] -= 1.0
		return true
	return false


## Food reçue par `cell` de chaque voisine ({ voisine: quantité }).
func food_imports(cell: Vector2i) -> Dictionary[Vector2i, float]:
	var imports: Dictionary[Vector2i, float] = {}
	for neighbor in neighbors(cell):
		var from_neighbor := food_exports(neighbor)
		if from_neighbor.has(cell):
			imports[neighbor] = from_neighbor[cell]
	return imports


# --- Déroulement ---------------------------------------------------------------------------------

## Un cycle : les batailles en cours font leurs pertes, puis, pour chaque joueur, ses scientists
## produisent de la science, ses cases rapportent ou coûtent de l'or (reconversions si l'or manque),
## puis ses populations grandissent dans la limite de la capacité de leur case. Une case en guerre est
## figée : ni science, ni croissance, ni reconversion ; seule la bataille y fait des pertes.
func tick() -> void:
	bankrupt_cells.clear()
	_fight_battles()
	for current in players:
		current.science += science_rate(current.id)
		_collect_gold(current.id)
		for cell in cells_of(current.id):
			if not is_at_war(cell):
				_populations[cell].grow(cell_growth_rates(cell), terrain_capacity(cell), _growth_limit(cell))
	changed.emit()


## Exécute la commande d'un joueur ; renvoie false si elle n'est pas valide.
func execute(command: Command) -> bool:
	return command.apply(self)


## Le joueur a-t-il déjà choisi sa case de départ ?
func has_started(player_id: int) -> bool:
	return player(player_id).started


## Chaque joueur démarre une fois, sur une case libre capable d'accueillir une population (pas sur l'eau).
func can_start_at(player_id: int, cell: Vector2i) -> bool:
	return not has_started(player_id) and population(cell) == null and capacity(cell) > 0.0


## Installe la population de départ du joueur sur `cell` ; renvoie false si c'est impossible.
func start_at(player_id: int, cell: Vector2i) -> bool:
	if not can_start_at(player_id, cell):
		return false
	_populations[cell] = Population.new(player_id, rules.starting_population)
	player(player_id).started = true
	_reveal_around(player_id, cell)
	changed.emit()
	return true


## Fait passer jusqu'à `amount` individus de `from_role` à `to_role` dans une case du joueur (les
## colons ne dépassent jamais rules.max_settlers) ; renvoie le nombre réellement déplacé. La troupe se
## forme en priorité avec les fighters de la case : des workers ne s'y enrôlent qu'une fois ceux-ci
## épuisés. Un village n'accueille pas de scientist. Les fighters qui quittent la troupe (garnison ou
## workers) doivent trouver de la place parmi les habitants (voir free_room).
func transfer(player_id: int, cell: Vector2i, from_role: String, to_role: String, amount: int = 1) -> int:
	if not can_command(player_id, cell) or (to_role == "scientist" and not is_city(cell)):
		return 0
	var cell_population := population(cell)
	if to_role == Population.ARMY:
		amount = mini(amount, rules.max_army - cell_population.army)
	if to_role == Population.SETTLER:
		amount = mini(amount, rules.max_settlers - cell_population.settlers)
	# Les fighters qui quittent la troupe redeviennent des habitants : il leur faut de la place.
	if from_role == Population.ARMY and to_role != Population.ARMY:
		amount = mini(amount, free_room(cell))
	var moved := 0
	if to_role == Population.ARMY and from_role == "worker":
		moved = cell_population.transfer("fighter", to_role, amount)
	moved += cell_population.transfer(from_role, to_role, amount - moved)
	if moved > 0:
		changed.emit()
	return moved


## Boost : ajoute rules.boost_workers workers dans une case du joueur, dans la limite de sa place
## libre ; renvoie le nombre ajouté.
func boost(player_id: int, cell: Vector2i) -> int:
	if not can_command(player_id, cell):
		return 0
	var added := mini(rules.boost_workers, free_room(cell))
	if added > 0:
		population(cell).counts["worker"] += added
		changed.emit()
	return added


## Cases où peuvent partir les colons de `cell`, si elle appartient au joueur : voisines, prairie ou
## montagne, libres ou à lui (hors cases en guerre), avec de la place.
func colonization_targets(player_id: int, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_command(player_id, cell) or population(cell).settlers <= 0:
		return result
	for neighbor in neighbors(cell):
		if capacity(neighbor) > 0.0 and owner(neighbor) in [NO_PLAYER, player_id] and free_room(neighbor) > 0 \
				and not is_at_war(neighbor):
			result.append(neighbor)
	return result


## Les colons de `from_cell` partent pour `to_cell`, dans la limite de sa place libre (le reste attend),
## qu'ils réservent pendant leur trajet (voir move_convoys) ; renvoie le nombre de colons partis.
func send_settlers(player_id: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if to_cell not in colonization_targets(player_id, from_cell):
		return 0
	var source := population(from_cell)
	var moved := mini(source.settlers, free_room(to_cell))
	source.settlers -= moved
	_convoys.append(Convoy.new(player_id, from_cell, to_cell, moved, false, true))
	changed.emit()
	return moved


## Colons et troupes en route.
func convoys() -> Array[Convoy]:
	return _convoys


## Colons (`army` faux) ou fighters (`army` vrai) du joueur en route vers `cell`.
func incoming(player_id: int, cell: Vector2i, army: bool) -> int:
	var count := 0
	for convoy in _convoys:
		if convoy.player_id == player_id and convoy.to_cell == cell and convoy.is_army == army:
			count += convoy.units
	return count


## Colons et troupes en route avancent de `seconds` (appelé toutes les rules.starvation_interval
## secondes) ; au bout de rules.travel_time, ils arrivent (voir _settle et _deploy). Ceux qui ne
## peuvent pas s'installer rentrent dans leur case de départ, comme colons (dans la limite de sa place et
## de rules.max_settlers) ou comme troupe (dans la limite de rules.max_army) ; ceux qui ne peuvent pas rentrer
## (case de départ perdue, assiégée ou pleine) sont perdus.
func move_convoys(seconds: float) -> void:
	var arrived: Array[Convoy] = []
	for convoy in _convoys:
		convoy.elapsed += seconds
		if convoy.elapsed >= rules.travel_time - 1e-6:
			arrived.append(convoy)
	for convoy in arrived:
		_convoys.erase(convoy)
		var left := _deploy(convoy) if convoy.is_army else _settle(convoy)
		if left > 0 and can_command(convoy.player_id, convoy.from_cell):
			var source := population(convoy.from_cell)
			var limit := rules.max_army - source.army if convoy.is_army else rules.max_settlers - source.settlers
			var room := 1 << 30 if convoy.is_army else free_room(convoy.from_cell)
			var back := mini(left, mini(room, limit))
			if convoy.is_army:
				source.army += back
			else:
				source.settlers += back
	if not arrived.is_empty():
		changed.emit()


## Colons arrivés : ils deviennent des workers de la case d'arrivée si elle est toujours libre ou au
## joueur, en paix, dans la limite de sa place (la leur était réservée). Renvoie ceux qui restent.
func _settle(convoy: Convoy) -> int:
	var cell := convoy.to_cell
	if owner(cell) not in [NO_PLAYER, convoy.player_id] or is_at_war(cell):
		return convoy.units
	var settled := mini(convoy.units, free_room(cell))
	if settled > 0:
		var founded := not _populations.has(cell)
		if founded:
			_populations[cell] = Population.new(convoy.player_id)
		_populations[cell].counts["worker"] += settled
		_reveal_around(convoy.player_id, cell)
		if founded:
			owner_changed.emit(cell, NO_PLAYER, convoy.player_id, false)
	return convoy.units - settled


## Troupe arrivée, selon ce qu'est devenue la case d'arrivée : chez le joueur en paix, elle reste une
## troupe (dans la limite de rules.max_army, sa place à part) ; dans une de ses cases assiégées, elle en
## renforce la garnison ; sur une case ennemie ou en guerre, elle livre bataille. Une case devenue
## libre et en paix ne l'accueille pas. Renvoie les fighters qui restent.
func _deploy(convoy: Convoy) -> int:
	var cell := convoy.to_cell
	var cell_owner := owner(cell)
	if cell_owner == convoy.player_id and not is_at_war(cell):
		var placed := mini(convoy.units, rules.max_army - population(cell).army)
		population(cell).army += placed
		return convoy.units - placed
	if cell_owner == convoy.player_id:
		population(cell).counts["fighter"] += convoy.units
		return 0
	if cell_owner != NO_PLAYER or is_at_war(cell):
		if not _battles.has(cell):
			_battles[cell] = Battle.new()
		_battles[cell].add(convoy.player_id, convoy.units)
		return 0
	return convoy.units


# --- Guerre --------------------------------------------------------------------------------------

## Bataille en cours sur `cell`, ou null.
func battle(cell: Vector2i) -> Battle:
	return _battles.get(cell)


func battle_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_battles.keys())
	return cells


## Une case assiégée est en guerre : elle est figée (ni croissance, ni science, ni famine, ni
## reconversion, ni commande) et seule la bataille y fait évoluer la population.
func is_at_war(cell: Vector2i) -> bool:
	return _battles.has(cell)


## Le joueur peut-il donner des ordres à `cell` ? Seulement si elle est à lui et n'est pas en guerre.
func can_command(player_id: int, cell: Vector2i) -> bool:
	return owner(cell) == player_id and not is_at_war(cell)


## Places qu'offre `to_cell` à la troupe du joueur. Chez lui en paix, la troupe a sa propre place, en
## plus de la capacité de la case : jusqu'à rules.max_army fighters, troupes en route comprises. Sur une
## case en guerre (renforts pour la défendre, ou pour rejoindre la bataille, même entre deux autres joueurs) ou sur une case ennemie,
## il n'y a pas de limite ; l'excédent éventuel meurt après la bataille (voir starve). Aucune place
## sur une case vide en paix : on la colonise avec des colons.
func army_room(player_id: int, to_cell: Vector2i) -> int:
	const UNLIMITED := 1 << 30
	var target_owner := owner(to_cell)
	if is_at_war(to_cell) or target_owner not in [NO_PLAYER, player_id]:
		return UNLIMITED
	if target_owner == NO_PLAYER:
		return 0
	return rules.max_army - population(to_cell).army - incoming(player_id, to_cell, true)


## Cases où peut partir la troupe de `cell`, si elle appartient au joueur : voisines qui sont à lui
## (déplacement, ou renfort si elle est assiégée), à un ennemi (attaque) ou en guerre, avec de la
## place (voir army_room).
func army_targets(player_id: int, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_command(player_id, cell) or population(cell).army <= 0:
		return result
	for neighbor in neighbors(cell):
		if army_room(player_id, neighbor) > 0:
			result.append(neighbor)
	return result


## La troupe de `from_cell` part pour `to_cell`, dans la limite de la place offerte (le reste attend),
## et y arrive au bout de rules.travel_time (voir move_convoys et _deploy). Chez le joueur en paix, sa
## place y est réservée pendant le trajet. Renvoie le nombre de fighters partis.
func send_army(player_id: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if to_cell not in army_targets(player_id, from_cell):
		return 0
	var source := population(from_cell)
	var moved := mini(source.army, army_room(player_id, to_cell))
	source.army -= moved
	var reserved := can_command(player_id, to_cell)
	_convoys.append(Convoy.new(player_id, from_cell, to_cell, moved, true, reserved))
	changed.emit()
	return moved


## Pertes du cycle dans chaque bataille, en mêlée générale : chaque camp (le défenseur, propriétaire de
## la case, avec toute sa population, et chaque attaquant avec son armée) fait un échange avec chacun
## des autres, les pertes étant simultanées (forces prises en début de cycle). Pertes habituelles d'un
## échange avec le défenseur : celui-ci perd un fighter de sa garnison, qui coûte
## rules.army_per_garrison fighters à l'attaquant ; à défaut un fighter de son armée, ou
## rules.workers_per_fighter workers, ou rules.scientists_per_fighter scientists, qui en coûtent un.
## Entre deux attaquants, chacun perd un fighter. Dans chaque échange, le camp le plus faible voit ses
## pertes multipliées par le rapport des forces (voir loss_factor). Un camp sans combattant quitte la
## bataille (la case d'un défenseur tombé se libère). Quand il ne reste qu'un camp, la bataille prend
## fin : le défenseur garde sa case, ou le dernier attaquant la prend, ses survivants y formant la
## garnison. Si tous tombent, la case reste libre.
func _fight_battles() -> void:
	for cell in _battles.keys():
		var current: Battle = _battles[cell]
		var defenders := population(cell)
		var attackers := current.fighters.keys()
		var strengths := {}
		for attacker in attackers:
			strengths[attacker] = attacker_strength(current.fighters[attacker])
		var defense := defender_strength(cell)
		# Pertes de chaque attaquant : ses échanges avec les autres attaquants, plus le prix de son
		# échange avec le défenseur.
		var losses := {}
		for attacker in attackers:
			losses[attacker] = 0.0
			for other in attackers:
				if other != attacker:
					losses[attacker] += loss_factor(strengths[attacker], strengths[other])
			if defenders != null:
				var price := _defender_loses(defenders, current, loss_factor(defense, strengths[attacker]))
				losses[attacker] += price * loss_factor(strengths[attacker], defense)
		if defenders != null and defenders.is_defenseless():
			_populations.erase(cell)
			owner_changed.emit(cell, defenders.owner, NO_PLAYER, true)
			defenders = null
		for attacker in attackers:
			var wounds: float = current.wounds.get(attacker, 0.0) + losses[attacker]
			var dead := mini(floori(wounds + 1e-6), current.fighters[attacker])
			current.fighters[attacker] -= dead
			current.wounds[attacker] = wounds - dead
			if current.fighters[attacker] <= 0:
				current.fighters.erase(attacker)
				current.wounds.erase(attacker)
		var survivors := current.fighters.keys()
		if survivors.is_empty():
			_battles.erase(cell)
			if defenders == null:
				# Plus personne : la ville tombe en ruine.
				_cities.erase(cell)
		elif defenders == null and survivors.size() == 1:
			var winner_id: int = survivors[0]
			_populations[cell] = Population.new(winner_id, {"fighter": float(current.fighters[winner_id])})
			_reveal_around(winner_id, cell)
			_battles.erase(cell)
			owner_changed.emit(cell, NO_PLAYER, winner_id, true)


## Force d'un camp attaquant de `fighters` fighters.
func attacker_strength(fighters: int) -> float:
	return fighters * rules.army_strength


## Force du défenseur de `cell` : sa garnison, son armée et ses workers, chacun selon sa force (voir
## GameRules.garrison_strength), multipliée par defense_bonus(cell). 0 si la case est vide.
func defender_strength(cell: Vector2i) -> float:
	var defenders := population(cell)
	if defenders == null:
		return 0.0
	var strength := defenders.whole("fighter") * rules.garrison_strength + defenders.army * rules.army_strength \
			+ defenders.whole("worker") * rules.worker_strength
	return strength * defense_bonus(cell)


## Multiplicateur de la force du défenseur de `cell` : rules.mountain_defense en montagne, 1 sinon.
func defense_bonus(cell: Vector2i) -> float:
	return rules.mountain_defense if terrain(cell) == Terrain.Type.MOUNTAIN else 1.0


## Multiplicateur de la force de la garnison de `cell` dû à ses remparts : rules.megapolis_defense dans une
## mégapole, 1 sinon.
func walls_bonus(cell: Vector2i) -> float:
	return rules.megapolis_defense if is_megapolis(cell) else 1.0


## Multiplicateur total de la force d'un fighter de la garnison de `cell` : terrain et remparts.
func garrison_bonus(cell: Vector2i) -> float:
	return defense_bonus(cell) * walls_bonus(cell)


## Multiplicateur des pertes d'un camp de force `own` face à un camp de force `enemy` : le rapport
## (enemy ÷ own) ^ rules.force_ratio_exponent s'il est le plus faible, 1 sinon (le plus fort garde ses
## pertes habituelles). Une force inférieure à 1 compte pour 1.
func loss_factor(own: float, enemy: float) -> float:
	return maxf(1.0, pow(maxf(enemy, 1.0) / maxf(own, 1.0), rules.force_ratio_exponent))


## Le défenseur subit `exchanges` échanges (fractionnaires, voir loss_factor) : il perd autant de
## fighters de sa garnison, puis de son armée (les fractions s'accumulent dans `current`), puis
## rules.workers_per_fighter workers ou rules.scientists_per_fighter scientists par échange restant.
## Renvoie le prix d'un échange pour l'attaquant : rules.army_per_garrison fighters contre la garnison,
## qui défend mieux, un sinon, et aucun si le défenseur n'a déjà plus personne.
func _defender_loses(defenders: Population, current: Battle, exchanges: float) -> int:
	if defenders.is_defenseless():
		return 0
	var price := rules.army_per_garrison if defenders.whole("fighter") >= 1 else 1
	var left := _lose_fraction(defenders, "fighter", exchanges, 1.0)
	var army_left := defenders.army - current.defender_army_wounds
	if left > 0.0 and army_left > 0.0:
		var taken := minf(left, army_left)
		left -= taken
		current.defender_army_wounds += taken
		var dead := mini(floori(current.defender_army_wounds + 1e-6), defenders.army)
		defenders.army -= dead
		current.defender_army_wounds -= dead
	left = _lose_fraction(defenders, "worker", left, rules.workers_per_fighter)
	_lose_fraction(defenders, "scientist", left, rules.scientists_per_fighter)
	return price


## Retire de `role` jusqu'à `exchanges` × `per_exchange` individus (fractions comprises) ; renvoie les
## échanges qui restent à subir faute d'individus.
func _lose_fraction(defenders: Population, role: String, exchanges: float, per_exchange: float) -> float:
	if exchanges <= 0.0:
		return 0.0
	var lost := minf(exchanges * per_exchange, defenders.counts[role])
	defenders.counts[role] -= lost
	return exchanges - lost / per_exchange


## Survivants d'une armée de `army` fighters qui attaque seule une garnison de `garrison` fighters sur
## `cell` (terrain et remparts compris), selon les règles de bataille ; 0 si elle ne l'emporte pas. Sert aux IA à
## estimer une attaque.
func assault_survivors(army: int, garrison: int, cell: Vector2i) -> int:
	var attack := float(army)
	var defense := float(garrison)
	var bonus := garrison_bonus(cell)
	while attack >= 1.0 - 1e-6 and defense >= 1.0 - 1e-6:
		var attack_strength := floorf(attack + 1e-6) * rules.army_strength
		var defense_strength := floorf(defense + 1e-6) * rules.garrison_strength * bonus
		defense -= loss_factor(defense_strength, attack_strength)
		attack -= rules.army_per_garrison * loss_factor(attack_strength, defense_strength)
	return floori(attack + 1e-6) if defense < 1.0 - 1e-6 else 0
