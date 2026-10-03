class_name AIController
extends RefCounted
## Joueur IA : observe le monde et agit en émettant des commandes, exactement comme un humain. Il ne
## voit que ce que voit un humain (brouillard de guerre : population totale seulement chez l'ennemi).
## À chaque cycle, par ordre de priorité : secourir ses cases assiégées, attaquer une voisine faible,
## faire passer en ville ses villages pleins bien entourés, ajuster garnison et scientists de chaque
## case, envoyer des colons, puis cliquer sur Boost. Son
## caractère (AIProfile) règle chacune de ces étapes.

var player_id: int
var profile: AIProfile

var _world: World
var _rng: RandomNumberGenerator
## Rafale de clics sur Boost en cours, ou pause, et secondes restantes avant de basculer.
var _bursting: bool = true
var _phase_left: float = 0.0
## Cases déjà engagées ce cycle (secours, attaque), que les étapes suivantes laissent tranquilles.
var _busy: Dictionary[Vector2i, bool] = {}
## Cases ennemies voisines en vue : depuis combien de secondes, et à qui elles appartiennent (le compteur
## repart de zéro si la case change de propriétaire).
var _watched_seconds: Dictionary[Vector2i, float] = {}
var _watched_owner: Dictionary[Vector2i, int] = {}
## Armée minimale pour vaincre une garnison ({ (garnison, bonus de défense × 100): fighters }).
var _army_needed: Dictionary[Vector2i, int] = {}
## Secondes à attendre avant la prochaine action sur la carte (voir profile.action_delay).
var _action_wait: float = 0.0


func _init(world: World, ai_player_id: int, rng: RandomNumberGenerator, ai_profile: AIProfile) -> void:
	_world = world
	player_id = ai_player_id
	_rng = rng
	profile = ai_profile
	_phase_left = _phase_duration()


## Commandes à jouer après chaque cycle.
func play_cycle() -> Array[Command]:
	var commands: Array[Command] = []
	_busy.clear()
	_action_wait = maxf(0.0, _action_wait - _world.rules.cycle_duration)
	_relieve_sieges(commands)
	_attack(commands)
	_found_cities(commands)
	for cell in _peaceful_cells():
		_staff(cell, commands)
	_colonize(commands)
	_boost(commands)
	return commands


# --- Lecture du monde (ce qu'en voit un humain) ------------------------------------------------

## Cases de l'IA auxquelles elle peut donner des ordres (hors guerre) et pas encore engagées ce cycle.
func _peaceful_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _world.cells_of(player_id):
		if _world.can_command(player_id, cell) and not _busy.has(cell):
			cells.append(cell)
	return cells


## Population totale visible de la case ennemie `cell`, ou 0 si elle n'est pas ennemie ou pas visible.
func _enemy_population(cell: Vector2i) -> int:
	var cell_owner := _world.owner(cell)
	if cell_owner in [World.NO_PLAYER, player_id] or not _world.is_visible(player_id, cell):
		return 0
	return _world.population(cell).whole_total()


## Plus grosse population ennemie voisine de `cell` : la menace à laquelle sa garnison doit faire face.
func _threat(cell: Vector2i) -> int:
	var threat := 0
	for neighbor in _world.neighbors(cell):
		threat = maxi(threat, _enemy_population(neighbor))
	return threat


## Scientists et fighters que peut nourrir et payer chaque worker de `cell` (le moins favorable des
## deux), selon son terrain. Dans une ville, seul l'or compte : ses workers ne produisent pas de food, et
## ses voisines la nourrissent quel que soit le rôle de ses habitants.
func _support_per_worker(cell: Vector2i) -> float:
	var rules := _world.rules
	var by_food := INF if _world.is_city(cell) \
			else (_world.food_per_worker(cell) - rules.food_per_individual) / rules.food_per_individual
	var cost := -minf(rules.gold_per_role["scientist"], rules.gold_per_role["fighter"])
	var by_gold := _world.worker_gold(cell) / cost if cost > 0.0 else INF
	return minf(by_food, by_gold)


## Fighters que la case peut enrôler dans sa troupe : troupe déjà prête, garnison, et la part des workers
## que l'IA accepte d'engager.
func _available_army(cell: Vector2i) -> int:
	var cell_population := _world.population(cell)
	var workers := maxi(0, floori(cell_population.whole("worker") * profile.army_commit) - profile.keep_workers)
	return cell_population.army + cell_population.whole("fighter") + workers


## Action militaire : forme une troupe de `amount` fighters dans `from_cell` (garnison d'abord, puis
## workers) et l'envoie vers `to_cell`. La suivante devra attendre profile.action_delay (± son aléa),
## comme un humain qui ne peut mener qu'une action à la fois.
func _send_army(from_cell: Vector2i, to_cell: Vector2i, amount: int, commands: Array[Command]) -> void:
	var missing := amount - _world.population(from_cell).army
	if missing > 0:
		commands.append(TransferCommand.new(player_id, from_cell, "worker", Population.ARMY, missing))
	commands.append(SendArmyCommand.new(player_id, from_cell, to_cell))
	_busy[from_cell] = true
	_action_wait = profile.action_delay * _jitter(profile.action_delay_jitter)


# --- Guerre --------------------------------------------------------------------------------------

## Secours d'une case assiégée, s'il est temps d'agir : elle reçoit de la voisine qui peut en fournir le
## plus des renforts qui rejoignent sa garnison, jusqu'à ce qu'elle égale à elle seule la force des
## attaquants (rapport des forces : ce sont alors eux qui perdent le plus). Une seule action à la fois :
## les autres voisines et les autres cases assiégées attendront les actions suivantes.
func _relieve_sieges(commands: Array[Command]) -> void:
	if _action_wait > 0.0:
		return
	var rules := _world.rules
	for cell in _world.cells_of(player_id):
		if not _world.is_at_war(cell):
			continue
		var attack := _world.attacker_strength(_world.battle(cell).total_fighters())
		var per_fighter := rules.garrison_strength * _world.garrison_bonus(cell)
		# Les renforts déjà en route comptent.
		var needed := ceili(attack / per_fighter) + 1 - _world.population(cell).whole("fighter") \
				- _world.incoming(player_id, cell, true)
		if needed <= 0:
			continue
		var best := World.NO_CELL
		for neighbor in _world.neighbors(cell):
			if _world.can_command(player_id, neighbor) and not _busy.has(neighbor) and _available_army(neighbor) > 0 \
					and (best == World.NO_CELL or _available_army(neighbor) > _available_army(best)):
				best = neighbor
		if best != World.NO_CELL:
			_send_army(best, cell, mini(needed, _available_army(best)), commands)
			return


## Attaque les cases ennemies voisines, des moins chères aux plus chères, quand une case voisine peut
## réunir une armée assez forte. Faute de connaître leur composition, l'IA suppose le pire : toute la
## population en garnison (terrain compris). Elle attaque avec la plus petite armée qui l'emporterait
## sur ce pire cas, multipliée par profile.attack_margin. Une seule attaque à la fois, et seulement s'il
## est temps d'agir (voir profile.action_delay).
func _attack(commands: Array[Command]) -> void:
	_watch_enemies()
	if profile.attack_margin <= 0.0 or _action_wait > 0.0:
		return
	var costs: Dictionary[Vector2i, int] = {}
	for cell in _peaceful_cells():
		for neighbor in _world.neighbors(cell):
			var enemies := _enemy_population(neighbor)
			# Une attaque déjà en route vers la case suffit.
			if enemies > 0 and not _world.is_at_war(neighbor) and _world.incoming(player_id, neighbor, true) == 0 \
					and _watched_seconds.get(neighbor, 0.0) >= profile.attack_delay:
				var needed := _army_to_win(enemies, neighbor)
				if needed > 0:
					costs[neighbor] = ceili(needed * profile.attack_margin)
	var targets := costs.keys()
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return costs[a] < costs[b])
	for target in targets:
		var best := World.NO_CELL
		for neighbor in _world.neighbors(target):
			if _world.can_command(player_id, neighbor) and not _busy.has(neighbor) \
					and _available_army(neighbor) >= costs[target] \
					and (best == World.NO_CELL or _available_army(neighbor) > _available_army(best)):
				best = neighbor
		if best != World.NO_CELL:
			_send_army(best, target, costs[target], commands)
			return


## Plus petite armée qui l'emporterait sur une garnison de `garrison` fighters dans `cell` (voir
## World.assault_survivors), ou 0 si même rules.max_army n'y suffirait pas. Mémorisée par effectif et
## bonus de défense.
func _army_to_win(garrison: int, cell: Vector2i) -> int:
	var key := Vector2i(garrison, roundi(_world.garrison_bonus(cell) * 100.0))
	if not _army_needed.has(key):
		var high := _world.rules.max_army
		if _world.assault_survivors(high, garrison, cell) <= 0:
			_army_needed[key] = 0
		else:
			var low := 0  # perd toujours ; high gagne toujours
			while high - low > 1:
				var middle := floori((low + high) / 2.0)
				if _world.assault_survivors(middle, garrison, cell) > 0:
					high = middle
				else:
					low = middle
			_army_needed[key] = high
	return _army_needed[key]


## Temps de réaction : compte depuis combien de secondes chaque case ennemie voisine est en vue. Une case
## qui change de propriétaire repart de zéro ; une case qui n'est plus en vue est oubliée.
func _watch_enemies() -> void:
	var in_view: Dictionary[Vector2i, bool] = {}
	for cell in _world.cells_of(player_id):
		for neighbor in _world.neighbors(cell):
			if _enemy_population(neighbor) > 0:
				in_view[neighbor] = true
	for cell in _watched_seconds.keys():
		if not in_view.has(cell):
			_watched_seconds.erase(cell)
			_watched_owner.erase(cell)
	for cell in in_view:
		if _watched_owner.get(cell, World.NO_PLAYER) != _world.owner(cell):
			_watched_seconds[cell] = 0.0
			_watched_owner[cell] = _world.owner(cell)
		else:
			_watched_seconds[cell] += _world.rules.cycle_duration


# --- Garnison et science -------------------------------------------------------------------------

## Ajuste garnison et scientists de `cell` à ce que vise le profil, dans la limite de ce que ses workers
## peuvent nourrir et payer. La science est servie d'abord (sa part est fixée par le profil ; seulement
## dans une ville), la garnison prend le reste du budget.
func _staff(cell: Vector2i, commands: Array[Command]) -> void:
	var cell_population := _world.population(cell)
	var fighters := cell_population.whole("fighter")
	var scientists := cell_population.whole("scientist")
	var people := cell_population.whole("worker") + fighters + scientists
	var city := _world.is_city(cell)
	# Avec f fighters et s scientists : f + s ≤ k × (people - f - s), soit f + s ≤ k × people / (1 + k).
	var support := _support_per_worker(cell) * profile.budget_share
	var budget := floori(people * support / (1.0 + support))
	var wanted_scientists := mini(floori(people * profile.science_ratio), budget) if city else 0
	var wanted_fighters := mini(ceili(_threat(cell) * profile.garrison_ratio), budget - wanted_scientists)
	_adjust(cell, "fighter", fighters, wanted_fighters, commands)
	_adjust(cell, "scientist", scientists, wanted_scientists, commands)


## Fait passer en ville chaque village plein dont les voisines pourraient nourrir la ville qu'il
## deviendrait, avec la marge profile.city_food_margin : sans cela, elle redeviendrait aussitôt village
## par la famine. Comme la garnison et la science, c'est un simple bouton du zoom : pas une action sur
## la carte.
func _found_cities(commands: Array[Command]) -> void:
	var rules := _world.rules
	for cell in _peaceful_cells():
		if not _world.can_found_city(player_id, cell):
			continue
		var cell_population := _world.population(cell)
		var need := cell_population.residents() * rules.city_food_per_individual + cell_population.army * rules.army_food
		if _food_supply(cell, need) >= need * profile.city_food_margin:
			commands.append(FoundCityCommand.new(player_id, cell))


## Food que les voisines de `cell` lui enverraient si elle manquait de `need` food par cycle : chacune
## partage son surplus entre ses voisines dans le besoin, en proportion de leur manque (voir
## World.food_exports).
func _food_supply(cell: Vector2i, need: float) -> float:
	var supply := 0.0
	for neighbor in _world.neighbors(cell):
		if not _world.can_command(player_id, neighbor):
			continue
		var surplus := _world.food_balance(neighbor)
		if surplus <= 0.0:
			continue
		var other_needs := 0.0
		for around in _world.neighbors(neighbor):
			if around != cell and _world.can_command(player_id, around):
				other_needs += maxf(0.0, -_world.food_balance(around))
		supply += need * minf(1.0, surplus / (need + other_needs))
	return supply


## Convertit des workers en `role` (ou l'inverse) pour passer de `current` à `wanted` individus.
func _adjust(cell: Vector2i, role: String, current: int, wanted: int, commands: Array[Command]) -> void:
	if wanted > current:
		commands.append(TransferCommand.new(player_id, cell, "worker", role, wanted - current))
	elif wanted < current:
		commands.append(TransferCommand.new(player_id, cell, role, "worker", current - wanted))


# --- Expansion -----------------------------------------------------------------------------------

## Colonisation, s'il est temps d'agir (c'est une action sur la carte, comme une attaque : voir
## profile.action_delay) : la case la plus remplie parmi celles qui le sont assez envoie une vague de
## colons vers sa meilleure case libre voisine. Une seule vague à la fois.
func _colonize(commands: Array[Command]) -> void:
	if _action_wait > 0.0:
		return
	var best := World.NO_CELL
	var best_target := World.NO_CELL
	var best_fill := 0.0
	for cell in _peaceful_cells():
		var fill := _world.population(cell).residents() / _world.terrain_capacity(cell)
		if fill < profile.settle_fill_ratio or fill <= best_fill:
			continue
		var target := _best_free_neighbor(cell, {})
		if target != World.NO_CELL:
			best = cell
			best_target = target
			best_fill = fill
	if best == World.NO_CELL:
		return
	var cell_population := _world.population(best)
	var wave := mini(profile.settlers_per_wave, cell_population.whole("worker") - profile.keep_workers)
	var missing := wave - cell_population.settlers
	if missing > 0:
		commands.append(TransferCommand.new(player_id, best, "worker", Population.SETTLER, missing))
	if cell_population.settlers + maxi(0, missing) > 0:
		commands.append(SendSettlersCommand.new(player_id, best, best_target))
		_action_wait = profile.action_delay * _jitter(profile.action_delay_jitter)


## Case libre voisine de `cell` la plus intéressante à coloniser : grande capacité et bonne production de
## food (la plaine avant la forêt, la colline, le marais et la montagne), et qui ouvre le plus de terres
## libres. NO_CELL s'il n'y en a pas.
func _best_free_neighbor(cell: Vector2i, claimed: Dictionary[Vector2i, bool]) -> Vector2i:
	var best := World.NO_CELL
	var best_score := -INF
	for neighbor in _world.neighbors(cell):
		if claimed.has(neighbor) or _world.owner(neighbor) != World.NO_PLAYER or _world.capacity(neighbor) <= 0.0 \
				or _world.is_at_war(neighbor) or _world.incoming(player_id, neighbor, false) > 0:
			continue
		var rules := _world.rules
		var score := _world.terrain_capacity(neighbor) / rules.capacity[Terrain.Type.PRAIRIE] \
				+ _world.food_per_worker(neighbor) / rules.food_per_worker[Terrain.Type.PRAIRIE] + _rng.randf() * 0.05
		for around in _world.neighbors(neighbor):
			if _world.owner(around) == World.NO_PLAYER and _world.capacity(around) > 0.0:
				score += 0.1
		if score > best_score:
			best = neighbor
			best_score = score
	return best


# --- Boost ---------------------------------------------------------------------------------------

## Clique sur Boost comme un humain : en rafales, entrecoupées de pauses. Chaque clic va à la case la
## moins remplie.
func _boost(commands: Array[Command]) -> void:
	var cycle := _world.rules.cycle_duration
	_phase_left -= cycle
	if _phase_left <= 0.0:
		_bursting = not _bursting
		_phase_left = _phase_duration()
	if not _bursting:
		return
	var clicks_wanted := profile.boost_clicks_per_second * cycle * _jitter(profile.boost_click_jitter)
	var clicks := floori(clicks_wanted) + (1 if _rng.randf() < fmod(clicks_wanted, 1.0) else 0)
	var added: Dictionary[Vector2i, int] = {}
	for click in clicks:
		var best := World.NO_CELL
		var best_fill := INF
		for cell in _world.cells_of(player_id):
			if not _world.can_command(player_id, cell) or _world.free_room(cell) <= added.get(cell, 0):
				continue
			var fill: float = (_world.population(cell).residents() + added.get(cell, 0)) / _world.capacity(cell)
			if fill < best_fill:
				best = cell
				best_fill = fill
		if best == World.NO_CELL:
			return
		added[best] = added.get(best, 0) + _world.rules.boost_workers
		commands.append(BoostCommand.new(player_id, best))


## Durée tirée au hasard de la prochaine rafale ou pause.
func _phase_duration() -> float:
	var mean := profile.boost_burst_seconds if _bursting else profile.boost_pause_seconds
	return mean * _jitter(profile.boost_phase_jitter)


## Facteur tiré au hasard entre 1 - `amount` et 1 + `amount`.
func _jitter(amount: float) -> float:
	return _rng.randf_range(1.0 - amount, 1.0 + amount)
