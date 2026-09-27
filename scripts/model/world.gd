class_name World
extends RefCounted
## État de la partie : terrain de chaque case (indices à partir de 0), joueurs, et population de
## chaque case occupée (une case n'appartient qu'à un joueur à la fois). Toutes les actions des
## joueurs passent par execute() avec une commande, qui vérifie qu'ils n'agissent que sur leurs cases.

## Émis à chaque changement de population ou de ressources.
signal changed

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


func capacity(cell: Vector2i) -> float:
	return Terrain.CAPACITY[terrain(cell)]


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


## Population entière du joueur sur toute la carte, tous rôles, colons, troupes et fighters engagés
## dans ses batailles compris.
func total_population(player_id: int) -> int:
	var total := 0
	for cell in cells_of(player_id):
		total += _populations[cell].whole_total()
	for current in _battles.values():
		total += current.fighters.get(player_id, 0)
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


## Places libres dans `cell` avant d'atteindre sa capacité (règle d'or) ; les fighters qui y livrent
## bataille occupent aussi de la place.
func free_room(cell: Vector2i) -> int:
	var cell_population := population(cell)
	var used := 0.0 if cell_population == null else cell_population.total()
	if _battles.has(cell):
		used += _battles[cell].total_fighters()
	return maxi(0, floori(capacity(cell) - used + 1e-6))


## La case compte-t-elle plus d'individus que sa capacité (règle d'or) ? Seule une bataille peut y
## mener : renforts et attaquants n'y sont pas limités.
func is_overcrowded(cell: Vector2i) -> bool:
	return population(cell) != null and population(cell).total() > capacity(cell) + 1e-6


## Multiplicateurs de croissance du joueur : ceux des règles, dont l'accroissement est modulé par
## son facteur de croissance (1 + (taux - 1) × facteur).
func growth_rates(player_id: int) -> Dictionary[String, float]:
	var rates := rules.growth_rates()
	for role in rates:
		rates[role] = 1.0 + (rates[role] - 1.0) * player(player_id).growth_factor
	return rates


## Avancement de chaque rôle de `cell` vers sa prochaine unité (voir Population.progress).
func progress(cell: Vector2i, cycle_fraction: float) -> Dictionary[String, float]:
	var cell_population := population(cell)
	if cell_population == null:
		return {}
	# Case en guerre : figée, aucune croissance en cours.
	var room := 0.0 if is_at_war(cell) else capacity(cell)
	return cell_population.progress(growth_rates(cell_population.owner), room, cycle_fraction)


# --- Économie ------------------------------------------------------------------------------------

## Science produite par le joueur à chaque cycle (rien par ses cases en guerre, qui sont figées).
func science_rate(player_id: int) -> float:
	var rate := 0.0
	for cell in cells_of(player_id):
		if not is_at_war(cell):
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
		income += cell_population.whole(role) * rules.gold_per_role[role]
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

## Solde de food de `cell` à chaque cycle : production des workers moins la consommation de chaque
## worker, scientist ou fighter (les colons ne mangent pas).
func food_balance(cell: Vector2i) -> float:
	var cell_population := population(cell)
	if cell_population == null:
		return 0.0
	var eaters := 0
	for role in cell_population.counts:
		eaters += cell_population.whole(role)
	return cell_population.whole("worker") * rules.food_per_worker - eaters * rules.food_per_individual


## Solde de food de toutes les cases du joueur.
func total_food_balance(player_id: int) -> float:
	var balance := 0.0
	for cell in cells_of(player_id):
		balance += food_balance(cell)
	return balance


## Food envoyée par `cell` à chaque voisine ({ voisine: quantité }) : son surplus est partagé à
## parts égales entre les cases voisines de son propriétaire. Vide sans surplus ou sans voisine.
func food_exports(cell: Vector2i) -> Dictionary[Vector2i, float]:
	var exports: Dictionary[Vector2i, float] = {}
	var surplus := food_balance(cell)
	if surplus <= 0.0:
		return exports
	var recipients: Array[Vector2i] = []
	for neighbor in neighbors(cell):
		if owner(neighbor) == owner(cell):
			recipients.append(neighbor)
	for neighbor in recipients:
		exports[neighbor] = surplus / recipients.size()
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
## de food depuis plus de rules.starvation_grace secondes perd un individu, en priorité un scientist,
## puis un fighter, puis un worker, jusqu'à retrouver l'équilibre. Une case qui dépasse sa capacité
## (après une bataille) depuis aussi longtemps perd de même un fighter, ou à défaut un fighter de sa
## troupe, jusqu'à revenir à sa capacité.
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
		deaths = _kill_one(cell, ["scientist", "fighter", "worker"]) or deaths
	for cell in _due_deaths(_overcrowding, overcrowded):
		deaths = _kill_one(cell, ["fighter", Population.ARMY]) or deaths
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
		var rates := growth_rates(current.id)
		for cell in cells_of(current.id):
			if not is_at_war(cell):
				_populations[cell].grow(rates, capacity(cell))
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
## épuisés.
func transfer(player_id: int, cell: Vector2i, from_role: String, to_role: String, amount: int = 1) -> int:
	if not can_command(player_id, cell):
		return 0
	var cell_population := population(cell)
	if to_role == Population.ARMY:
		amount = mini(amount, rules.max_army - cell_population.army)
	if to_role == Population.SETTLER:
		amount = mini(amount, rules.max_settlers - cell_population.settlers)
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


## Les colons de `from_cell` partent pour `to_cell` et y deviennent des workers, dans la limite de sa
## place libre (le reste attend) ; renvoie le nombre de colons partis.
func send_settlers(player_id: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if to_cell not in colonization_targets(player_id, from_cell):
		return 0
	var source := population(from_cell)
	var moved := mini(source.settlers, free_room(to_cell))
	if not _populations.has(to_cell):
		_populations[to_cell] = Population.new(player_id)
	source.settlers -= moved
	_populations[to_cell].counts["worker"] += moved
	_reveal_around(player_id, to_cell)
	changed.emit()
	return moved


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


## Places qu'offre `to_cell` à la troupe du joueur. Chez lui en paix, c'est la place libre de la case
## (règle d'or : c'est là que se préparent les armées). Sur une case en guerre (renforts pour la
## défendre, ou pour rejoindre la bataille, même entre deux autres joueurs) ou sur une case ennemie,
## il n'y a pas de limite ; l'excédent éventuel meurt après la bataille (voir starve). Aucune place
## sur une case vide en paix : on la colonise avec des colons.
func army_room(player_id: int, to_cell: Vector2i) -> int:
	const UNLIMITED := 1 << 30
	var target_owner := owner(to_cell)
	if is_at_war(to_cell) or target_owner not in [NO_PLAYER, player_id]:
		return UNLIMITED
	return 0 if target_owner == NO_PLAYER else free_room(to_cell)


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


## La troupe de `from_cell` part pour `to_cell`, dans la limite de la place offerte (le reste attend) :
## chez le joueur, elle y redevient des fighters (renforts compris, si la case est assiégée) ; ailleurs,
## elle y livre bataille. Renvoie le nombre de fighters partis.
func send_army(player_id: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if to_cell not in army_targets(player_id, from_cell):
		return 0
	var source := population(from_cell)
	var moved := mini(source.army, army_room(player_id, to_cell))
	source.army -= moved
	if owner(to_cell) == player_id:
		population(to_cell).counts["fighter"] += moved
	else:
		if not _battles.has(to_cell):
			_battles[to_cell] = Battle.new()
		_battles[to_cell].add(player_id, moved)
	changed.emit()
	return moved


## Pertes du cycle dans chaque bataille, en mêlée générale : chaque camp (le défenseur, propriétaire de
## la case, avec toute sa population, et chaque attaquant avec son armée) fait un échange avec chacun
## des autres, les pertes étant simultanées. Dans un échange avec le défenseur, celui-ci perd un fighter
## de sa garnison, qui coûte rules.army_per_garrison fighters à l'attaquant ; à défaut un fighter de son
## armée, ou rules.workers_per_fighter workers, ou rules.scientists_per_fighter scientists, qui en
## coûtent un. Entre deux attaquants, chacun perd un fighter. Un camp sans combattant quitte la
## bataille (la case d'un défenseur tombé se libère). Quand il ne reste qu'un camp, la bataille prend
## fin : le défenseur garde sa case, ou le dernier attaquant la prend, ses survivants y formant la
## garnison. Si tous tombent, la case reste libre.
func _fight_battles() -> void:
	for cell in _battles.keys():
		var current: Battle = _battles[cell]
		var defenders := population(cell)
		var attackers := current.fighters.keys()
		# Pertes de chaque attaquant : un fighter par autre attaquant, plus le prix de son échange avec le défenseur.
		var losses := {}
		for attacker in attackers:
			losses[attacker] = attackers.size() - 1
			if defenders != null:
				losses[attacker] += _defender_loses(defenders)
		if defenders != null and defenders.is_defenseless():
			_populations.erase(cell)
			defenders = null
		for attacker in attackers:
			current.fighters[attacker] -= mini(losses[attacker], current.fighters[attacker])
			if current.fighters[attacker] <= 0:
				current.fighters.erase(attacker)
		var survivors := current.fighters.keys()
		if survivors.is_empty():
			_battles.erase(cell)
		elif defenders == null and survivors.size() == 1:
			var winner_id: int = survivors[0]
			_populations[cell] = Population.new(winner_id, {"fighter": float(current.fighters[winner_id])})
			_reveal_around(winner_id, cell)
			_battles.erase(cell)


## Pertes du défenseur dans un échange : un fighter de sa garnison, ou à défaut un fighter de son armée,
## ou rules.workers_per_fighter workers, ou rules.scientists_per_fighter scientists. Renvoie ce que
## l'échange coûte à l'attaquant : rules.army_per_garrison fighters contre la garnison, qui défend mieux,
## un sinon, et aucun si le défenseur n'a déjà plus personne.
func _defender_loses(defenders: Population) -> int:
	if defenders.is_defenseless():
		return 0
	if defenders.whole("fighter") >= 1:
		defenders.lose("fighter", 1)
		return rules.army_per_garrison
	if defenders.army >= 1:
		defenders.army -= 1
	elif defenders.whole("worker") >= 1:
		defenders.lose("worker", rules.workers_per_fighter)
	else:
		defenders.lose("scientist", rules.scientists_per_fighter)
	return 1
