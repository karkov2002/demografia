class_name BattleView
extends RefCounted
## Dessin d'une case en guerre, pour qu'on la repère d'un coup d'œil : contour rouge qui pulse, petites
## explosions en fond, épées qui s'entrechoquent sur un halo lumineux qui pulse, et les belligérants.

## Pulsation du contour et du halo (par seconde), et cadence des épées (images par seconde).
const PULSE_RATE := 1.2
const CLASH_FPS := 6.0
## Explosions simultanées sur une case, durée (s) d'un cycle d'explosion et part de ce cycle où elle
## est visible (le reste est une pause avant la suivante, ailleurs sur la case).
const EXPLOSIONS := 3
const EXPLOSION_PERIOD := 1.1
const EXPLOSION_VISIBLE := 0.7
const OUTLINE_COLOR := Color(1.0, 0.22, 0.18)
const HALO_COLOR := Color(1.0, 0.78, 0.3)


## Animation de la bataille sur la case `cell` dessinée en `center` avec le rayon `radius`, à l'instant
## `time` (s) : contour, explosions, halo et épées centrés au-dessus de `swords_center`.
static func draw(canvas: CanvasItem, cell: Vector2i, center: Vector2, radius: float, swords_center: Vector2,
		swords_size: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * TAU * PULSE_RATE)
	# Contour rouge qui pulse, en retrait du bord.
	var outline := HexUtils.hex_points(center, radius * 0.94)
	canvas.draw_polyline(HexUtils.closed(outline), Color(OUTLINE_COLOR, 0.5 + 0.5 * pulse), radius * 0.07, true)
	# Explosions en fond, chacune à un endroit tiré au hasard à chaque cycle.
	for i in EXPLOSIONS:
		var t := time / EXPLOSION_PERIOD + float(i) / EXPLOSIONS + float(absi(hash(cell)) % 97) / 97.0
		var burst := floori(t)
		var phase := t - burst
		if phase > EXPLOSION_VISIBLE:
			continue
		var burst_frame := mini(Icons.EXPLOSION.size() - 1, int(phase / EXPLOSION_VISIBLE * Icons.EXPLOSION.size()))
		var spot := absi(hash(Vector3i(cell.x, cell.y, burst * EXPLOSIONS + i)))
		var angle := deg_to_rad(spot % 360)
		var distance := float(floori(spot / 360.0) % 100) / 100.0 * radius * 0.55
		var burst_size := Vector2.ONE * radius * 0.55
		var spot_center := center + Vector2.from_angle(angle) * distance
		canvas.draw_texture_rect(Icons.EXPLOSION[burst_frame], Rect2(spot_center - burst_size / 2.0, burst_size), false)
	# Halo lumineux qui pulse sous les épées : disques superposés, plus clairs au centre.
	var halo := swords_size * (0.6 + 0.1 * pulse)
	for k in 6:
		canvas.draw_circle(swords_center, halo * (1.0 - k / 6.0), Color(HALO_COLOR, 0.1 + 0.08 * pulse))
	# Épées qui s'entrechoquent, qui pulsent elles aussi légèrement.
	var frame := int(time * CLASH_FPS) % Icons.CLASH.size()
	var size := Vector2.ONE * swords_size * (1.0 + 0.08 * pulse)
	canvas.draw_texture_rect(Icons.CLASH[frame], Rect2(swords_center - size / 2.0, size), false)


## Belligérants de la bataille sur `cell`, pour PopulationText.draw_icon_row, chacun à la couleur de
## son joueur : [défenseur, attaquants]. Le défenseur montre à qui est engagé dans la bataille sa
## garnison (tour), sa troupe (épée) et ses civils, workers et scientists, qui défendent aussi (buste) ;
## aux autres, sa seule population totale (brouillard de guerre) ; rien s'il est tombé. Chaque
## attaquant montre ses fighters engagés (épée).
static func belligerents(world: World, viewer_id: int, cell: Vector2i) -> Array:
	var battle := world.battle(cell)
	var defender := []
	var defenders := world.population(cell)
	if defenders != null:
		var color: Color = CellBackground.PLAYER_COLORS[defenders.owner]
		if defenders.owner == viewer_id or battle.fighters.has(viewer_id):
			defender.append([Icons.GARRISON, NumberFormat.compact(defenders.whole("fighter")), color])
			if defenders.army > 0:
				defender.append([Icons.SWORD, NumberFormat.compact(defenders.army), color])
			var civilians := defenders.whole("worker") + defenders.whole("scientist")
			if civilians > 0:
				defender.append([Icons.POPULATION_TINT, NumberFormat.compact(civilians), color, color])
		else:
			var total := defenders.whole_total()
			defender.append([Icons.settlement(total / world.capacity(cell)), NumberFormat.compact(total), color, color])
	var attackers := []
	for attacker in battle.fighters:
		attackers.append([Icons.SWORD, NumberFormat.compact(battle.fighters[attacker]),
				CellBackground.PLAYER_COLORS[attacker]])
	return [defender, attackers]
