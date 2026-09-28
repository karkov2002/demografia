class_name AIController
extends RefCounted
## Joueur IA : observe le monde et agit en émettant des commandes, exactement comme un humain. Il ne
## voit que ce que voit un humain (brouillard de guerre : population totale seulement chez l'ennemi).
## À chaque cycle, par ordre de priorité : secourir ses cases assiégées, attaquer une voisine faible,
## ajuster garnison et scientists de chaque case, envoyer des colons, puis cliquer sur Boost. Son
## caractère (AIProfile) règle chacune de ces étapes.

## Part du budget d'une case (ce que ses workers peuvent nourrir et payer) que l'IA s'autorise à
## consacrer aux scientists et fighters, pour garder une marge d'or et de food.
const BUDGET_SHARE := 0.9
## Workers qu'une case garde toujours, pour continuer à grandir.
const KEEP_WORKERS := 2

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


func _init(world: World, ai_player_id: int, rng: RandomNumberGenerator, ai_profile: AIProfile) -> void:
	_world = world
	player_id = ai_player_id
	_rng = rng
	profile = ai_profile
	_phase_left = _phase_duration()


## Case de départ tirée au hasard parmi celles où le départ est permis (jamais sur l'eau).
func choose_start() -> Command:
	var candidates: Array[Vector2i] = []
	for row in _world.rows:
		for column in _world.columns:
			var cell := Vector2i(column, row)
			if _world.can_start_at(player_id, cell):
				candidates.append(cell)
	if candidates.is_empty():
		return null
	return StartCommand.new(player_id, candidates[_rng.randi_range(0, candidates.size() - 1)])


## Commandes à jouer après chaque cycle.
func play_cycle() -> Array[Command]:
	var commands: Array[Command] = []
	_busy.clear()
	_relieve_sieges(commands)
	_attack(commands)
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


## Scientists et fighters que peut nourrir et payer chaque worker (le moins favorable des deux).
func _support_per_worker() -> float:
	var rules := _world.rules
	var by_food := (rules.food_per_worker - rules.food_per_individual) / rules.food_per_individual
	var cost := -minf(rules.gold_per_role["scientist"], rules.gold_per_role["fighter"])
	var by_gold: float = rules.gold_per_role["worker"] / cost if cost > 0.0 else INF
	return minf(by_food, by_gold)


## Fighters que la case peut enrôler dans sa troupe : troupe déjà prête, garnison, et la part des workers
## que l'IA accepte d'engager.
func _available_army(cell: Vector2i) -> int:
	var cell_population := _world.population(cell)
	var workers := maxi(0, floori(cell_population.whole("worker") * profile.army_commit) - KEEP_WORKERS)
	return cell_population.army + cell_population.whole("fighter") + workers


## Forme une troupe de `amount` fighters dans `from_cell` (garnison d'abord, puis workers) et l'envoie
## vers `to_cell`.
func _send_army(from_cell: Vector2i, to_cell: Vector2i, amount: int, commands: Array[Command]) -> void:
	var missing := amount - _world.population(from_cell).army
	if missing > 0:
		commands.append(TransferCommand.new(player_id, from_cell, "worker", Population.ARMY, missing))
	commands.append(SendArmyCommand.new(player_id, from_cell, to_cell))
	_busy[from_cell] = true


# --- Guerre --------------------------------------------------------------------------------------

## Chaque case assiégée reçoit en renfort de ses voisines de quoi tenir : ses fighters y rejoignent la
## garnison, jusqu'à ce qu'elle égale à elle seule la force des attaquants (rapport des forces : ce
## sont alors eux qui perdent le plus).
func _relieve_sieges(commands: Array[Command]) -> void:
	var rules := _world.rules
	for cell in _world.cells_of(player_id):
		if not _world.is_at_war(cell):
			continue
		var attack := _world.attacker_strength(_world.battle(cell).total_fighters())
		var per_fighter := rules.garrison_strength * _world.defense_bonus(cell)
		var needed := ceili(attack / per_fighter) + 1 - _world.population(cell).whole("fighter")
		for neighbor in _world.neighbors(cell):
			if needed <= 0:
				break
			if not _world.can_command(player_id, neighbor) or _busy.has(neighbor):
				continue
			var sent := mini(needed, _available_army(neighbor))
			if sent > 0:
				_send_army(neighbor, cell, sent, commands)
				needed -= sent


## Attaque les cases ennemies voisines, des moins chères aux plus chères, quand une case voisine peut
## réunir une armée assez forte. Faute de connaître leur composition, l'IA suppose le pire : toute la
## population en garnison (terrain compris). Elle attaque avec la plus petite armée qui l'emporterait
## sur ce pire cas, multipliée par profile.attack_margin.
func _attack(commands: Array[Command]) -> void:
	_watch_enemies()
	if profile.attack_margin <= 0.0:
		return
	var costs: Dictionary[Vector2i, int] = {}
	for cell in _peaceful_cells():
		for neighbor in _world.neighbors(cell):
			var enemies := _enemy_population(neighbor)
			if enemies > 0 and not _world.is_at_war(neighbor) \
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


## Plus petite armée qui l'emporterait sur une garnison de `garrison` fighters dans `cell` (voir
## World.assault_survivors), ou 0 si même rules.max_army n'y suffirait pas. Mémorisée par effectif et
## bonus de défense.
func _army_to_win(garrison: int, cell: Vector2i) -> int:
	var key := Vector2i(garrison, roundi(_world.defense_bonus(cell) * 100.0))
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
## peuvent nourrir et payer. La science est servie d'abord (sa part est fixée par le profil), la
## garnison prend le reste du budget.
func _staff(cell: Vector2i, commands: Array[Command]) -> void:
	var cell_population := _world.population(cell)
	var fighters := cell_population.whole("fighter")
	var scientists := cell_population.whole("scientist")
	var people := cell_population.whole("worker") + fighters + scientists
	# Avec f fighters et s scientists : f + s ≤ k × (people - f - s), soit f + s ≤ k × people / (1 + k).
	var support := _support_per_worker() * BUDGET_SHARE
	var budget := floori(people * support / (1.0 + support))
	var wanted_scientists := mini(floori(people * profile.science_ratio), budget)
	var wanted_fighters := mini(ceili(_threat(cell) * profile.garrison_ratio), budget - wanted_scientists)
	_adjust(cell, "fighter", fighters, wanted_fighters, commands)
	_adjust(cell, "scientist", scientists, wanted_scientists, commands)


## Convertit des workers en `role` (ou l'inverse) pour passer de `current` à `wanted` individus.
func _adjust(cell: Vector2i, role: String, current: int, wanted: int, commands: Array[Command]) -> void:
	if wanted > current:
		commands.append(TransferCommand.new(player_id, cell, "worker", role, wanted - current))
	elif wanted < current:
		commands.append(TransferCommand.new(player_id, cell, role, "worker", current - wanted))


# --- Expansion -----------------------------------------------------------------------------------

## Une case assez peuplée envoie une vague de colons vers la meilleure case libre voisine.
func _colonize(commands: Array[Command]) -> void:
	var claimed: Dictionary[Vector2i, bool] = {}
	for cell in _peaceful_cells():
		var cell_population := _world.population(cell)
		if cell_population.total() < profile.settle_fill_ratio * _world.capacity(cell):
			continue
		var target := _best_free_neighbor(cell, claimed)
		if target == World.NO_CELL:
			continue
		var wave := mini(profile.settlers_per_wave, cell_population.whole("worker") - KEEP_WORKERS)
		var missing := wave - cell_population.settlers
		if missing > 0:
			commands.append(TransferCommand.new(player_id, cell, "worker", Population.SETTLER, missing))
		if cell_population.settlers + maxi(0, missing) > 0:
			commands.append(SendSettlersCommand.new(player_id, cell, target))
			claimed[target] = true


## Case libre voisine de `cell` la plus intéressante à coloniser : prairie plutôt que montagne, et qui
## ouvre le plus de terres libres. NO_CELL s'il n'y en a pas.
func _best_free_neighbor(cell: Vector2i, claimed: Dictionary[Vector2i, bool]) -> Vector2i:
	var best := World.NO_CELL
	var best_score := -INF
	for neighbor in _world.neighbors(cell):
		if claimed.has(neighbor) or _world.owner(neighbor) != World.NO_PLAYER or _world.capacity(neighbor) <= 0.0 \
				or _world.is_at_war(neighbor):
			continue
		var score := _world.capacity(neighbor) / Terrain.CAPACITY[Terrain.Type.PRAIRIE] + _rng.randf() * 0.05
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
	var clicks_wanted := profile.boost_clicks_per_second * cycle * _rng.randf_range(0.7, 1.3)
	var clicks := floori(clicks_wanted) + (1 if _rng.randf() < fmod(clicks_wanted, 1.0) else 0)
	var added: Dictionary[Vector2i, int] = {}
	for click in clicks:
		var best := World.NO_CELL
		var best_fill := INF
		for cell in _world.cells_of(player_id):
			if not _world.can_command(player_id, cell) or _world.free_room(cell) <= added.get(cell, 0):
				continue
			var fill: float = (_world.population(cell).total() + added.get(cell, 0)) / _world.capacity(cell)
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
	return mean * _rng.randf_range(0.5, 1.5)
