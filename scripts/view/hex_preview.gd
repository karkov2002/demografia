class_name HexPreview
extends Control
## Affiche en grand une case du monde, avec sa population, ses échanges de food et, pour une case du
## joueur, les commandes qui s'y appliquent.

## Émis au clic sur un bouton « + » ou « - », ou sur les boutons Settler et Army : le joueur veut faire
## passer `amount` individus d'un rôle à l'autre. Tant que le bouton reste enfoncé, un individu de plus
## part après rules.hold_delay, puis hold_delay/2, hold_delay/3… jusqu'à rules.max_hold_rate par seconde.
signal transfer_requested(from_role: String, to_role: String, amount: int)
## Émis à chaque clic sur le bouton Boost.
signal boost_requested
## Émis au clic sur le bouton « Progress to city » d'un village plein.
signal city_requested
## Émis au clic sur le bouton « Downgrade to village » d'une ville.
signal downgrade_requested
## Émis à chaque clic sur un autre bouton du zoom (« + », « - », Settler, Army, raccourcis) : pour le
## bruit du clic.
signal button_clicked

## Rôles qu'on peut renforcer (« + ») ou réduire (« - ») en échangeant avec WORKFORCE_ROLE.
const ASSIGNABLE_ROLES := ["scientist", "fighter"]
## Rôle dans lequel on pioche au « + » et auquel on rend au « - ».
const WORKFORCE_ROLE := "worker"
## Hauteur (px) réservée au-dessus de l'hexagone pour la ligne or et food.
const HEADER_HEIGHT := 32.0
## Gros boutons d'action empilés sous l'hexagone : hauteur (px) de chacun et espace entre eux.
const ACTION_BUTTON_HEIGHT := 40.0
const ACTION_BUTTON_GAP := 6.0
## Boutons d'action, de haut en bas.
## Settler : clic gauche = workers mis de côté comme colons, clic droit = colons repris.
## Army : clic gauche = un fighter de la garnison rejoint l'armée, ou à défaut un worker devient
## fighter et la rejoint ; clic droit = un fighter quitte l'armée et redevient worker.
## Boost : chaque clic ajoute des workers à la case.
## Downgrade to village : sur une ville seulement (sa place reste vide ailleurs), la fait redevenir
## village, après confirmation (voir downgrade_requested).
const SETTLER_ACTION := "settler"
const ARMY_ACTION := "army"
const BOOST_ACTION := "boost"
const DOWNGRADE_ACTION := "downgrade"
const ACTIONS := [SETTLER_ACTION, ARMY_ACTION, BOOST_ACTION, DOWNGRADE_ACTION]
const ACTION_COLORS := {
	SETTLER_ACTION: Color(0.72, 0.52, 0.3),
	ARMY_ACTION: Color(0.82, 0.26, 0.22),
	BOOST_ACTION: Color(0.95, 0.6, 0.15),
	DOWNGRADE_ACTION: Color(0.45, 0.4, 0.55),
}
## Raccourcis « tout d'un coup » : toute l'armée rejoint la garnison (bouton à droite d'Army), toute la
## garnison rejoint l'armée (bouton à droite des « - » et « + » de la garnison, dans la limite de
## rules.max_army).
const ALL_TO_GARRISON := "all_to_garrison"
const ALL_TO_ARMY := "all_to_army"
## Bouton « Progress to city », à la place des scientists dans un village plein : couleur et libellé (clé
## de texte, voir Locale).
const CITY_ACTION := "city"
const CITY_COLOR := Color(0.62, 0.42, 0.85)
const CITY_TEXT := "ZOOM_PROGRESS_CITY"
## Couleur de la ligne qui rappelle la capacité d'un village pas encore plein.
const VILLAGE_HINT_COLOR := Color(0.85, 0.85, 0.85)
## Durée (s) de l'éclat d'un bouton d'action après un clic.
const FLASH_TIME := 0.15
## Couleur du revenu en or de la case.
const GOLD_TEXT_COLOR := Color(1.0, 0.8, 0.3)
## Flèches d'échange de food : couleurs des imports et des exports, marge (px) autour de leur contenu
## et écart (px) avec le bord de l'hexagone.
const FOOD_IMPORT_COLOR := Color(0.45, 0.95, 0.35)
const FOOD_EXPORT_COLOR := Color(1.0, 0.55, 0.35)
const FOOD_ARROW_PADDING := 5.0
const FOOD_ARROW_GAP := 3.0
## Taille fixe du texte des flèches, pour qu'il reste lisible même quand l'hexagone est petit.
const FOOD_ARROW_FONT_SIZE := 14
## Couleur du solde de food de la case.
const FOOD_TEXT_COLOR := Color(1.0, 0.55, 0.5)
## Taille de l'hexagone par rapport à la place disponible : la marge accueille les échanges de food.
const HEX_SCALE := 0.64
## Alertes affichées dans l'hexagone : famine, bataille.
const STARVATION_TEXT := "ZOOM_STARVATION"
const STARVATION_COLOR := Color(1.0, 0.35, 0.3)

@export var border_color: Color = Color(0.55, 0.55, 0.55)
@export var text_color: Color = Color.WHITE
@export var hint_color: Color = Color(0.35, 0.27, 0.15)
@export var border_width: float = 4.0
@export var margin: float = 24.0

## Joueur dont on montre la vue (brouillard de guerre) et qu'on fait agir.
var viewer_id: int = 0
## Monde affiché ; le zoom se redessine à chacun de ses changements.
var world: World:
	set(value):
		world = value
		world.changed.connect(queue_redraw)
		queue_redraw()
## Case affichée (indices à partir de 0), ou HexMap.NO_CELL.
var cell: Vector2i = HexMap.NO_CELL:
	set(value):
		cell = value
		_held_transfer = []
		queue_redraw()
## Part écoulée du cycle en cours (0 à 1), pour faire avancer les barres de progression en continu.
var cycle_fraction: float = 0.0:
	set(value):
		cycle_fraction = value
		queue_redraw()

var _button_rects: Dictionary = {}  # rôle → { signe → zone du bouton + ou - }, au dernier dessin
var _action_rects: Dictionary = {}  # action → zone de son gros bouton, au dernier dessin
var _shortcut_rects: Dictionary = {}  # raccourci (ALL_TO_GARRISON, ALL_TO_ARMY) → zone, au dernier dessin
var _boost_pops: Array = []  # [instant (s), texte] de chaque « +N » qui s'envole du bouton Boost
var _flash: Dictionary = {}  # action → éclat de son bouton, de 1 juste après un clic à 0
var _held_transfer: Array = []  # [rôle source, rôle cible] tant qu'un bouton est maintenu, sinon vide
var _hold_time: float = 0.0  # temps écoulé depuis la dernière répétition du bouton maintenu
var _hold_repeats: int = 0  # répétitions déjà faites depuis le clic
var _hold_interval: float = 0.0  # délai avant la prochaine répétition


func _ready() -> void:
	# Tuiles en pixel art : pas de lissage à l'agrandissement.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size / 2.0
	_button_rects = {}
	_action_rects = {}
	_shortcut_rects = {}
	if world == null or cell == HexMap.NO_CELL:
		_draw_centered_text(Locale.text("ZOOM_HINT"), center, 18, hint_color)
		return

	var available := size - Vector2(margin, margin) * 2.0
	# Place réservée au-dessus de l'hexagone (or et food) et en dessous (boutons d'action), le tout
	# centré verticalement ; l'hexagone est ensuite réduit pour laisser, tout autour, la place aux
	# échanges de food posés sur ses bords.
	var actions_height := ACTIONS.size() * (ACTION_BUTTON_HEIGHT + ACTION_BUTTON_GAP) + ACTION_BUTTON_GAP
	var full_radius := maxf(0.0, minf(available.x / sqrt(3.0), (available.y - HEADER_HEIGHT - actions_height) / 2.0))
	var block_height := HEADER_HEIGHT + full_radius * 2.0 + actions_height
	center.y = (size.y - block_height) / 2.0 + HEADER_HEIGHT + full_radius
	var radius := full_radius * HEX_SCALE
	# Sans agglomération : les rôles et les commandes du zoom restent lisibles.
	CellBackground.draw(self, world, viewer_id, cell, center, radius, false)
	var owner := world.owner(cell)
	var outline_color := border_color
	if owner != World.NO_PLAYER and world.is_visible(viewer_id, cell):
		outline_color = CellBackground.PLAYER_COLORS[owner]
	draw_polyline(HexUtils.closed(HexUtils.hex_points(center, radius)), outline_color, border_width, true)
	var population := world.population(cell)
	if not world.is_visible(viewer_id, cell):
		return
	var font := get_theme_default_font()
	var font_size := maxi(12, int(radius * 0.12))
	# Une case en guerre dont le défenseur est tombé n'a plus de population, mais la bataille continue.
	# Sur une case du joueur, les alertes montent en haut de l'hexagone pour laisser place aux rôles.
	_draw_alerts(center - Vector2(0.0, radius * (0.75 if owner == viewer_id else 0.5)), font_size)
	if population == null:
		return
	if owner != viewer_id:
		var battle := world.battle(cell)
		if battle != null and battle.fighters.has(viewer_id):
			# Case assiégée par le joueur : la bataille révèle le détail de ses défenseurs.
			PopulationText.draw(self, font, population, center, font_size, text_color)
		else:
			# Case ennemie en vue : sa population totale seulement, sans détail ni commandes.
			var total := population.whole_total()
			PopulationText.draw_icon_row(self, font, [[Icons.settlement(world, cell),
					NumberFormat.compact(total), text_color, CellBackground.PLAYER_COLORS[owner]]], center, font_size, 1.7)
		return
	_draw_header(center - Vector2(0.0, full_radius + HEADER_HEIGHT / 2.0), maxi(12, int(radius * 0.13)))
	_draw_actions(population, center.y + full_radius + ACTION_BUTTON_GAP, full_radius)
	_draw_food_flows(center, radius)
	_draw_roles(population, center, radius, font, font_size)


## Rôles d'une case du joueur, en colonne centrée sur `center` : les workers seuls en haut, puis les
## scientists et la garnison, chacun avec son icône et, juste en dessous, ses gros boutons « - » et « + »
## (échange avec les workers) ; la garnison a en plus, à droite, le raccourci ALL_TO_ARMY. Les rôles qui
## grandissent ont leur barre de progression. Tous les boutons sont grisés sur une case en guerre, qui
## est figée. Un village n'a pas de scientists : à leur place, sa population et sa capacité, puis, une
## fois plein, le gros bouton « Progress to city ».
func _draw_roles(population: Population, center: Vector2, radius: float, font: Font, font_size: int) -> void:
	const ROLE_ICONS := {"scientist": Icons.SCIENTIST, "fighter": Icons.GARRISON}
	var commandable := world.can_command(viewer_id, cell)
	var progress := world.progress(cell, cycle_fraction)
	var line_height := font.get_height(font_size)
	var button_size := Vector2.ONE * line_height * 1.4
	var gap := line_height * 0.5
	var roles: Array[String] = [WORKFORCE_ROLE]
	roles.append_array(ASSIGNABLE_ROLES)
	var block_height := roles.size() * line_height + ASSIGNABLE_ROLES.size() * (button_size.y + gap * 0.5) \
			+ (roles.size() - 1) * gap
	var y := center.y - block_height / 2.0 + line_height / 2.0
	for role in roles:
		if role == "scientist" and not world.is_city(cell):
			_draw_village_slot(population, Rect2(center.x - radius * 0.7, y - line_height / 2.0, radius * 1.4,
					line_height + gap * 0.5 + button_size.y), font, font_size)
			y += line_height + gap * 0.5 + button_size.y + gap
			continue
		_draw_role_line(population, role, ROLE_ICONS.get(role), progress.get(role, -1.0), Vector2(center.x, y),
				font, font_size)
		y += line_height / 2.0
		if role in ASSIGNABLE_ROLES:
			var enabled := {"-": commandable and population.can_transfer(role),
					"+": commandable and population.can_transfer(WORKFORCE_ROLE)}
			# Deux boutons (« - », « + »), plus le raccourci ALL_TO_ARMY pour la garnison, centrés.
			var count := 3 if role == "fighter" else 2
			var left := center.x - (count * button_size.x + (count - 1) * gap) / 2.0
			_button_rects[role] = {}
			for button_sign in ["-", "+"]:
				var rect := Rect2(Vector2(left, y + gap * 0.5), button_size)
				var color: Color = PopulationText.ROLE_COLORS[role] if enabled[button_sign] else PopulationText.DISABLED_COLOR
				PopulationText.draw_button(self, font, rect, button_sign, color, text_color)
				_button_rects[role][button_sign] = rect
				left += button_size.x + gap
			if role == "fighter":
				var rect := Rect2(Vector2(left, y + gap * 0.5), button_size)
				var can_enlist := commandable and population.can_transfer("fighter") \
						and population.army < world.rules.max_army
				var color: Color = ACTION_COLORS[ARMY_ACTION] if can_enlist else PopulationText.DISABLED_COLOR
				PopulationText.draw_button(self, font, rect, "", color.lerp(Color.WHITE, _flash.get(ALL_TO_ARMY, 0.0) * 0.6),
						text_color)
				_draw_icon_in(Icons.SWORD, rect, can_enlist)
				_shortcut_rects[ALL_TO_ARMY] = rect
			y += gap * 0.5 + button_size.y
		y += gap + line_height / 2.0


## Place des scientists dans un village, `slot` : le gros bouton « Progress to city » s'il est plein et
## peut passer en ville, sinon sa population sur sa capacité.
func _draw_village_slot(population: Population, slot: Rect2, font: Font, font_size: int) -> void:
	var tint: Color = CellBackground.PLAYER_COLORS[viewer_id]
	if world.can_found_city(viewer_id, cell):
		_action_rects[CITY_ACTION] = slot
		_draw_action_box(slot, CITY_COLOR, CITY_ACTION)
		PopulationText.draw_icon_row(self, font, [[Icons.settlement_icon(1), Locale.text(CITY_TEXT), Color.WHITE, tint]],
				slot.get_center(), font_size)
		return
	var text := Locale.text("ZOOM_VILLAGE", {"count": NumberFormat.compact(floori(population.residents() + 1e-6)),
			"capacity": NumberFormat.compact(floori(world.capacity(cell)))})
	PopulationText.draw_icon_row(self, font, [[Icons.settlement_icon(0), text, VILLAGE_HINT_COLOR, tint]],
			slot.get_center(), font_size)


## Ligne centrée sur `center` : icône du rôle (s'il en a une), libellé dans sa couleur, effectif, puis
## barre de progression si `progress` est positif ou nul.
func _draw_role_line(population: Population, role: String, icon: Texture2D, progress: float, center: Vector2,
		font: Font, font_size: int) -> void:
	var color: Color = PopulationText.ROLE_COLORS[role]
	var label := PopulationText.label(role) + ": "
	var value := NumberFormat.compact(population.whole(role))
	var icon_size := font.get_height(font_size) * 1.2
	var spacing := font_size * 0.4
	var bar_size := Vector2(font_size * 3.5, font_size * 0.5)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := label_width + value_width
	if icon != null:
		width += icon_size + spacing
	if progress >= 0.0:
		width += spacing + bar_size.x
	var x := center.x - width / 2.0
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2(x, center.y - icon_size / 2.0), Vector2.ONE * icon_size), false)
		x += icon_size + spacing
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var outline := maxi(2, int(font_size / 3.0))
	PopulationText.draw_outlined(self, font, label, Vector2(x, baseline), font_size, color, outline)
	x += label_width
	PopulationText.draw_outlined(self, font, value, Vector2(x, baseline), font_size, text_color, outline)
	x += value_width
	if progress >= 0.0:
		var bar := Rect2(Vector2(x + spacing, center.y - bar_size.y / 2.0), bar_size)
		draw_rect(bar, PopulationText.BAR_BACKGROUND)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), color)


func _process(delta: float) -> void:
	for action in _flash:
		_flash[action] = maxf(0.0, _flash[action] - delta / FLASH_TIME)
	if _held_transfer.is_empty():
		return
	# Bouton maintenu : un individu toutes les rules.hold_delay/n secondes (n = rang de la répétition),
	# plafonné à rules.max_hold_rate par seconde. À haute vitesse, plusieurs répétitions tombent dans la même image :
	# elles partent en un seul envoi.
	_hold_time += delta
	var amount := 0
	while _hold_time >= _hold_interval:
		_hold_time -= _hold_interval
		amount += 1
		_hold_repeats += 1
		_hold_interval = maxf(world.rules.hold_delay / (_hold_repeats + 1), 1.0 / world.rules.max_hold_rate)
	if amount > 0:
		transfer_requested.emit(_held_transfer[0], _held_transfer[1], amount)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		_held_transfer = []
		return
	if not world.can_command(viewer_id, cell):
		return
	for action in _action_rects:
		if _action_rects[action].has_point(event.position):
			_press_action(action, event.button_index)
			accept_event()
			return
	for shortcut in _shortcut_rects:
		if _shortcut_rects[shortcut].has_point(event.position) and event.button_index == MOUSE_BUTTON_LEFT:
			_press_shortcut(shortcut)
			accept_event()
			return
	for role in _button_rects:
		for button_sign in _button_rects[role]:
			if _button_rects[role][button_sign].has_point(event.position) and event.button_index == MOUSE_BUTTON_LEFT:
				_start_transfer([WORKFORCE_ROLE, role] if button_sign == "+" else [role, WORKFORCE_ROLE])
				button_clicked.emit()
				accept_event()
				return


## Clic `mouse_button` sur le gros bouton `action`.
func _press_action(action: String, mouse_button: int) -> void:
	const RESERVES := {SETTLER_ACTION: [WORKFORCE_ROLE, Population.SETTLER], ARMY_ACTION: [WORKFORCE_ROLE, Population.ARMY]}
	if action == BOOST_ACTION:
		if mouse_button == MOUSE_BUTTON_LEFT:
			_flash[action] = 1.0
			boost_requested.emit()
		return
	if action == DOWNGRADE_ACTION:
		if mouse_button == MOUSE_BUTTON_LEFT:
			button_clicked.emit()
			downgrade_requested.emit()
		return
	if action == CITY_ACTION:
		if mouse_button == MOUSE_BUTTON_LEFT:
			button_clicked.emit()
			city_requested.emit()
		return
	# Settler et Army : clic gauche pour remplir la réserve, clic droit pour la vider.
	var reserve: Array = RESERVES[action]
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			_start_transfer(reserve)
		MOUSE_BUTTON_RIGHT:
			_start_transfer([reserve[1], reserve[0]])
		_:
			return
	_flash[action] = 1.0
	button_clicked.emit()


## « +`amount` » qui s'envole du bouton Boost (clic réussi).
func show_boost(amount: int) -> void:
	_boost_pops.append([Time.get_ticks_msec() / 1000.0, "+%d" % amount])


## « +N » qui s'envolent du bouton Boost `rect` en grossissant, puis s'effacent en fondu.
func _draw_boost_pops(rect: Rect2) -> void:
	const DURATION := 0.7
	var now := Time.get_ticks_msec() / 1000.0
	_boost_pops = _boost_pops.filter(func(pop: Array) -> bool: return now - pop[0] < DURATION)
	var font := get_theme_default_font()
	for pop in _boost_pops:
		var t: float = (now - pop[0]) / DURATION
		# Chaque « +N » part d'un point différent du bouton, selon l'instant du clic.
		var drift := (fmod(pop[0] * 7.3, 1.0) - 0.5) * rect.size.x * 0.5
		var center := Vector2(rect.get_center().x + drift, rect.position.y - rect.size.y * 1.3 * t)
		var font_size := int(ACTION_BUTTON_HEIGHT * (0.5 + 0.3 * t))
		var alpha := 1.0 - t * t
		var text: String = pop[1]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.2, 0.1, 0.0, alpha))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.3, alpha))


## Clic sur un raccourci : toute l'armée passe en garnison, ou toute la garnison dans l'armée.
func _press_shortcut(shortcut: String) -> void:
	var population := world.population(cell)
	if shortcut == ALL_TO_GARRISON:
		transfer_requested.emit(Population.ARMY, "fighter", population.army)
	else:
		transfer_requested.emit("fighter", Population.ARMY, population.whole("fighter"))
	_flash[shortcut] = 1.0
	button_clicked.emit()


## Icône `icon` centrée dans le bouton `rect`, estompée si le bouton est inactif.
func _draw_icon_in(icon: Texture2D, rect: Rect2, enabled: bool) -> void:
	var icon_size := Vector2.ONE * rect.size.y * 0.7
	draw_texture_rect(icon, Rect2(rect.get_center() - icon_size / 2.0, icon_size), false,
			Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.4))


## Premier envoi d'un transfert, qui se répète tant que le bouton reste enfoncé.
func _start_transfer(transfer: Array) -> void:
	_held_transfer = transfer
	_hold_time = 0.0
	_hold_repeats = 0
	_hold_interval = world.rules.hold_delay
	transfer_requested.emit(transfer[0], transfer[1], 1)


## Ligne centrée sur `center` : l'or de la case (tendance et solde par cycle, plus la pièce en baisse en
## cas de reconversion faute d'or), puis sa food par cycle : production nette, échanges avec les
## voisines et solde des deux, dont la tendance est donnée par la pomme qui les précède.
func _draw_header(center: Vector2, font_size: int) -> void:
	var income := world.cell_income(cell)
	var items := [[Icons.gold_trend(income), NumberFormat.signed(income), GOLD_TEXT_COLOR]]
	if cell in world.bankrupt_cells:
		items.append([Icons.GOLD_DOWN, "", GOLD_TEXT_COLOR])
	var produced := world.food_balance(cell)
	var trade := world.food_trade(cell)
	items.append_array([
		[Icons.food_trend(produced + trade), "", FOOD_TEXT_COLOR],
		[Icons.FOOD_PRODUCE, NumberFormat.signed(produced), FOOD_TEXT_COLOR],
		[Icons.FOOD_TRADE, NumberFormat.signed(trade), FOOD_TEXT_COLOR],
		[Icons.FOOD_NET, NumberFormat.signed(produced + trade), FOOD_TEXT_COLOR],
	])
	PopulationText.draw_icon_row(self, get_theme_default_font(), items, center, font_size)


## Alertes de la case centrées sur `center` : bataille en cours (le défenseur, les épées qui
## s'entrechoquent, puis les attaquants, chacun à sa couleur ; voir BattleView.belligerents) et famine.
func _draw_alerts(center: Vector2, font_size: int) -> void:
	var items := []
	if world.is_at_war(cell):
		var rows := BattleView.belligerents(world, viewer_id, cell)
		var clash: Texture2D = Icons.CLASH[int(Time.get_ticks_msec() / 1000.0 * BattleView.CLASH_FPS) % Icons.CLASH.size()]
		items.append_array(rows[0])
		items.append([clash, "", Color.WHITE])
		items.append_array(rows[1])
	if world.owner(cell) == viewer_id and world.is_starving(cell):
		items.append([Icons.STARVATION, Locale.text(STARVATION_TEXT), STARVATION_COLOR])
	if not items.is_empty():
		PopulationText.draw_icon_row(self, get_theme_default_font(), items, center, font_size)


## Gros boutons d'action empilés à partir de `top` : Settler et Army (avec leur réserve), Boost, puis
## Downgrade to village sur une ville ;
## Army est suivi, à sa droite, du raccourci ALL_TO_GARRISON. Un bouton s'éclaire un instant à chaque
## clic, et se grise quand il n'a aucun effet possible (tous quand la case est en guerre, car elle est
## figée).
func _draw_actions(population: Population, top: float, full_radius: float) -> void:
	var commandable := world.can_command(viewer_id, cell)
	var can_add_settler := population.can_transfer(WORKFORCE_ROLE) and population.settlers < world.rules.max_settlers
	# La troupe se forme d'abord avec les fighters de la case, puis avec des workers.
	var can_add_army := (population.can_transfer("fighter") or population.can_transfer(WORKFORCE_ROLE)) \
			and population.army < world.rules.max_army
	var labels := {
		SETTLER_ACTION: [Icons.SETTLER, Locale.text("ZOOM_SETTLER", {"count": NumberFormat.compact(population.settlers)}),
				commandable and (can_add_settler or population.settlers > 0)],
		ARMY_ACTION: [Icons.SWORD, Locale.text("ZOOM_ARMY", {"count": NumberFormat.compact(population.army)}),
				commandable and (can_add_army or population.army > 0)],
		BOOST_ACTION: [Icons.BOOST, Locale.text("ZOOM_BOOST"), commandable and world.free_room(cell) > 0],
		DOWNGRADE_ACTION: [Icons.settlement_icon(0), Locale.text("ZOOM_DOWNGRADE"),
				world.can_downgrade_city(viewer_id, cell)],
	}
	var button_size := Vector2(minf(full_radius * 1.6, size.x - margin * 2.0), ACTION_BUTTON_HEIGHT)
	var font := get_theme_default_font()
	for action in ACTIONS:
		# Pas de bouton Downgrade sur un village : sa place reste vide, pour que les autres ne bougent pas.
		if action == DOWNGRADE_ACTION and not world.is_city(cell):
			continue
		var rect := Rect2(Vector2(size.x / 2.0 - button_size.x / 2.0, top), button_size)
		if action == ARMY_ACTION:
			# Le raccourci carré prend sa place à droite, sur la largeur de la ligne.
			rect.size.x -= ACTION_BUTTON_HEIGHT + ACTION_BUTTON_GAP
			var shortcut := Rect2(Vector2(rect.end.x + ACTION_BUTTON_GAP, top), Vector2.ONE * ACTION_BUTTON_HEIGHT)
			var enabled := commandable and population.army > 0
			_draw_action_box(shortcut, PopulationText.ROLE_COLORS["fighter"] if enabled else PopulationText.DISABLED_COLOR,
					ALL_TO_GARRISON)
			_draw_icon_in(Icons.GARRISON, shortcut, enabled)
			_shortcut_rects[ALL_TO_GARRISON] = shortcut
		_action_rects[action] = rect
		_draw_action_box(rect, ACTION_COLORS[action] if labels[action][2] else PopulationText.DISABLED_COLOR, action)
		# L'icône du village, en niveaux de gris, prend la couleur du joueur.
		var tint: Color = CellBackground.PLAYER_COLORS[viewer_id] if action == DOWNGRADE_ACTION else Color.WHITE
		PopulationText.draw_icon_row(self, font, [[labels[action][0], labels[action][1], Color.WHITE, tint]],
				rect.get_center(), int(ACTION_BUTTON_HEIGHT * 0.42))
		if action == BOOST_ACTION:
			_draw_boost_pops(rect)
		top += ACTION_BUTTON_HEIGHT + ACTION_BUTTON_GAP


## Fond arrondi d'un gros bouton dans la couleur `base`, éclairci par l'éclat du bouton `flash_key`.
func _draw_action_box(rect: Rect2, base: Color, flash_key: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = base.lerp(Color.WHITE, _flash.get(flash_key, 0.0) * 0.6)
	style.border_color = base.darkened(0.45)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	draw_style_box(style, rect)


## Échanges de food avec chaque voisine : une grosse flèche hors de l'hexagone, contre le bord qui fait
## face à la voisine. Sortante (elle part du bord) pour un export, entrante (sa pointe touche le bord)
## pour un import ; son corps porte une pomme et la quantité nette par cycle.
func _draw_food_flows(center: Vector2, radius: float) -> void:
	var exports := world.food_exports(cell)
	var imports := world.food_imports(cell)
	# Distance du centre au milieu d'un bord.
	var edge_distance := radius * sqrt(3.0) / 2.0
	for neighbor in world.neighbors(cell):
		var net: float = imports.get(neighbor, 0.0) - exports.get(neighbor, 0.0)
		if is_zero_approx(net):
			continue
		var direction := HexUtils.neighbor_direction(cell, neighbor)
		var text := NumberFormat.signed(net)
		_draw_food_arrow(center + direction * edge_distance, direction, net > 0.0, text, FOOD_ARROW_FONT_SIZE)


## Grosse flèche dans l'axe `direction`, collée au point `edge` du bord : pointe vers l'extérieur
## (sortante) ou, si `incoming`, pointe sur le bord (entrante). Son corps, dimensionné pour son
## contenu, porte la pomme au-dessus de `text`, toujours à l'horizontale.
func _draw_food_arrow(edge: Vector2, direction: Vector2, incoming: bool, text: String, font_size: int) -> void:
	var font := get_theme_default_font()
	var icon_size := font.get_height(font_size)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var content := Vector2(maxf(icon_size, text_size.x), icon_size + text_size.y) + Vector2.ONE * FOOD_ARROW_PADDING
	# Encombrement du contenu dans l'axe de la flèche (longueur du corps) et en travers (largeur).
	var body_length := absf(direction.x) * content.x + absf(direction.y) * content.y
	var body_width := absf(direction.y) * content.x + absf(direction.x) * content.y
	var head_length := body_width * 0.4
	var head_width := body_width * 1.3
	# Coordonnées le long de la flèche, depuis le bord : corps puis pointe, ou pointe puis corps.
	var start := FOOD_ARROW_GAP
	var body_start := start + (head_length if incoming else 0.0)
	var body_end := body_start + body_length
	var local: Array[Vector2] = []
	if incoming:
		local = [Vector2(start, 0), Vector2(body_start, -head_width / 2), Vector2(body_start, -body_width / 2),
				Vector2(body_end, -body_width / 2), Vector2(body_end, body_width / 2),
				Vector2(body_start, body_width / 2), Vector2(body_start, head_width / 2)]
	else:
		local = [Vector2(body_start, -body_width / 2), Vector2(body_end, -body_width / 2),
				Vector2(body_end, -head_width / 2), Vector2(body_end + head_length, 0),
				Vector2(body_end, head_width / 2), Vector2(body_end, body_width / 2), Vector2(body_start, body_width / 2)]
	var side := direction.orthogonal()
	var points := PackedVector2Array()
	for point in local:
		points.append(edge + direction * point.x + side * point.y)
	draw_colored_polygon(points, FOOD_IMPORT_COLOR if incoming else FOOD_EXPORT_COLOR)
	points.append(points[0])
	draw_polyline(points, PopulationText.OUTLINE_COLOR, 2.0, true)
	var body_center := edge + direction * (body_start + body_end) / 2.0
	var icon_center := body_center - Vector2(0.0, text_size.y / 2.0)
	draw_texture_rect(Icons.FOOD, Rect2(icon_center - Vector2.ONE * icon_size / 2.0, Vector2.ONE * icon_size), false)
	PopulationText.draw_outlined_centered(self, font, text, body_center + Vector2(0.0, icon_size / 2.0), font_size,
			Color.WHITE)


func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	HexUtils.draw_centered_text(self, get_theme_default_font(), text, center, font_size, color)
