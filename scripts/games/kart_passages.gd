extends RefCounted
## LUMO-Passagen: kurze Präzisionsstellen und angekündigte bewegte Hindernisse, die ein
## Kind später beschreiben kann („die Strecke, wo ich vor der Brücke kurz gebremst habe“).
##
## Alle Distanzen sind Meter auf der FERTIG geglätteten Fahrbahn (world.curve), gemessen mit
## scripts/tests/kart_passage_survey.gd. Die Passage ist die Fahrautorität für Breite,
## Kollision, Absturz, Rücksetzpunkt und KI-Linie; die sichtbare Straße folgt denselben Werten.
##
## Rechnung (Entwurfswerte, Container-Messung kart_passage_survey 18.11.2026):
##   breitestes Kart (turbo/blitz/phantom/stella, sichtbare Hülle) ........ 2,19 m
##   Präzisionslinie mindestens 1,6 × 2,19 m ............................. 3,50 m
##   Brückendeck Entwurf ................................................. 3,60 m (1,64 ×)
##   Absturz erst, wenn die Kartmitte DECK_FALL_MARGIN über der Kante ist.
##   Langsamstes Kart (boru_rally) Beschleunigung ......................... 35,2 m/s²
## Bewegte Hindernisse: Offenzeit ≥ Reaktionszeit 1,0 s + Fahrzeit des langsamsten Karts aus
## dem Stand von der Wartelinie bis hinter das Band (gemessen im Regressionstest).

const WIDEST_KART_M: float = 2.19
const PRECISION_FACTOR: float = 1.6
const MIN_DECK_M: float = WIDEST_KART_M * PRECISION_FACTOR
const DECK_FALL_MARGIN: float = 0.20
const RIVAL_DECK_MARGIN: float = 0.60
const RIVAL_BRIDGE_SPEED: float = 20.0
const RIVAL_BRAKE: float = 26.0
const RIVAL_LINE_LEAD: float = 80.0
## First warning sign before a passage zone; the spoken/written hint follows the pace
## (at least ANNOUNCE_SECONDS before the zone, never later than 70 m).
const SIGN_LEAD_M: float = 170.0
const ANNOUNCE_SECONDS: float = 4.0
const SWING_CLEAR_MARGIN: float = 0.6
const KART_HALF_LENGTH: float = 1.24
const SPEC_DATA = preload("res://scripts/games/kart_passage_specs.gd")
const META: String = "passage_plan"
## Auto-Gas creep after a full stop on a bridge plaza: 8 m/s ≈ 29 km/h, 24 m deck ≈ 3 s.
const CREEP_SPEED: float = 8.0
## Passage kinds that have a waiting zone or a narrow deck (hold-still brake, no shove).
const INTERACTIVE: Array[String] = ["bridge", "swing", "gate"]


static func specs_for(track_id: String) -> Array:
	return SPEC_DATA.SPECS.get(track_id, [])


static func has(track_id: String) -> bool:
	return SPEC_DATA.SPECS.has(track_id)


## Revisions-Kennung für Bestzeit-Geister: alte Geister fuhren über eine andere Straße.
static func ghost_suffix(track_id: String) -> String:
	return "_p1" if has(track_id) else ""


## Plant die Passagen einer Welt. Wird vor dem Action-Kurs aufgerufen, damit Turbo-Felder,
## Slalom und Felsen die Passage meiden (kart_action_course._blocked_ranges).
static func plan(world) -> Array:
	var result: Array = []
	for spec in specs_for(str(world.track_id)):
		var entry: Dictionary = spec.duplicate(true)
		if str(entry.kind) == "bridge":
			entry["deck_width"] = maxf(float(entry.deck_width), MIN_DECK_M)
			entry["zone_start"] = float(entry.plaza_start)
			entry["zone_end"] = float(entry.deck_end) + 6.0
		elif str(entry.kind) in ["flow", "view"]:
			pass
		elif str(entry.kind) == "gate":
			entry["zone_start"] = float(entry.wait_start)
			entry["zone_end"] = float(entry.plane) + float(entry.band) + 4.0
			entry["cycle"] = float(entry.open) + float(entry.warn) + _blocking_seconds(entry)
		else:
			entry["zone_start"] = float(entry.wait_start)
			entry["zone_end"] = float(entry.plane) + float(entry.band) + 4.0
			entry["cycle"] = float(entry.open) + float(entry.warn) + float(entry.swing)
		result.append(entry)
	world.set_meta(META, result)
	return result


static func of(world) -> Array:
	return world.get_meta(META, []) if world.has_meta(META) else []


## Bereiche, in die kein anderes Streckenelement gesetzt werden darf.
static func blocked_ranges(world) -> Array:
	var blocked: Array = []
	for entry in of(world):
		# A flowing curve may share road with existing turbo fields and dive tunnels.
		if not bool(entry.get("reserve", true)):
			continue
		blocked.append(Vector2(float(entry.zone_start) - 30.0, float(entry.zone_end) + 6.0))
	return blocked


## Reward after a bridge: one centred turbo field in the wide snow curve behind it.
## Added after kart_action_course.plan, so the race uses the ordinary pad rules.
static func extend_action(world) -> void:
	if world.action.is_empty() or not world.action.has("pads"):
		return
	for entry in of(world):
		if str(entry.kind) == "bridge" and entry.has("exit_end"):
			var start: float = float(entry.deck_end) + 14.0
			world.action.pads.append(
				{"start": start, "end": start + 6.0, "lateral": 0.0, "passage": str(entry.id)}
			)


# ------------------------------------------------------------------ Geometrie


## Statische Deck-Halbbreite (ohne Welt), damit kart_jungle_course seine Fahrbahn,
## Kollisionsdecks und Planken mit denselben Zahlen baut. -1 außerhalb eines Decks.
static func static_deck_half(track_id: String, distance: float) -> float:
	for spec in specs_for(track_id):
		if str(spec.kind) != "bridge":
			continue
		if distance >= float(spec.deck_start) and distance <= float(spec.deck_end):
			return maxf(float(spec.deck_width), MIN_DECK_M) * 0.5
	return -1.0


static func bridge_at(world, distance: float) -> Dictionary:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if (
			str(entry.kind) == "bridge"
			and d >= float(entry.deck_start)
			and d <= float(entry.deck_end)
		):
			return entry
	return {}


static func deck_half(world, distance: float) -> float:
	var entry: Dictionary = bridge_at(world, distance)
	return float(entry.deck_width) * 0.5 if not entry.is_empty() else -1.0


## Neben dem Deck gibt es keinen Boden: kein Geländer, wer zu weit hinausfährt, fällt.
static func void_at(world, distance: float) -> bool:
	return not bridge_at(world, distance).is_empty()


static func fall_lateral(world, distance: float) -> float:
	var half: float = deck_half(world, distance)
	return half + DECK_FALL_MARGIN if half > 0.0 else INF


## Wand-/Leitlinie für Rivalen: Kartmitte bleibt RIVAL_DECK_MARGIN innerhalb der Kante.
static func rival_wall(world, distance: float) -> float:
	var half: float = deck_half(world, distance)
	return half - RIVAL_DECK_MARGIN if half > 0.0 else INF


## True near a bridge gap: roadside decoration must not stand in the void.
static func keeps_clear(world, distance: float, margin: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if (
			str(entry.kind) == "bridge"
			and d > float(entry.deck_start) - margin
			and d < float(entry.deck_end) + margin
		):
			return true
	return false


## Fraction-placed race elements (turbo fields, item rings, boxes) that would land on a
## plaza, a deck or in a waiting zone move to just behind the passage.
static func clear_distance(world, distance: float, margin: float = 12.0) -> float:
	var length: float = float(world.length)
	var d: float = fposmod(distance, length)
	for entry in of(world):
		if str(entry.kind) not in INTERACTIVE:
			continue
		if d > float(entry.zone_start) - margin - 20.0 and d < float(entry.zone_end) + margin:
			return float(entry.zone_end) + margin + 4.0
	return distance


## A distance near a passage zone moves to just behind the zone (else unchanged).
static func after_zone(world, distance: float, margin: float) -> float:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if d > float(entry.zone_start) - margin and d < float(entry.zone_end) + margin:
			return float(entry.zone_end) + margin + 5.0
	return distance


## Any passage (also S-curve and view) within margin metres of this distance.
static func near_zone(world, distance: float, margin: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if d > float(entry.zone_start) - margin and d < float(entry.zone_end) + margin:
			return true
	return false


## Points inside the sightline from the view zone to its landmark stay free of trees.
static func in_view_corridor(world, at: Vector3) -> bool:
	for entry in of(world):
		if str(entry.kind) != "view":
			continue
		var from: Vector3 = world.position_at(float(entry.zone_start) - 20.0, 0.0)
		var to: Vector3 = world.position_at(float(entry.landmark), float(entry.lateral))
		var a := Vector2(from.x, from.z)
		var b := Vector2(to.x, to.z)
		var p := Vector2(at.x, at.z)
		var t: float = clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0)
		var reach: float = lerpf(6.0, 16.0, t)
		if p.distance_to(a.lerp(b, t)) < reach:
			return true
	return false


## Die Passage, deren Warte-/Vorplatz-Zone diese Distanz enthält, oder {}.
static func zone_at(world, distance: float) -> Dictionary:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) not in INTERACTIVE:
			continue
		if d >= float(entry.zone_start) and d <= float(entry.zone_end):
			return entry
	return {}


## Rücksetzpunkt für einen Sturz oder einen Rücksetzer in der Gefahr: ruhig auf dem Vorplatz
## bzw. vor der Wartelinie. -1 außerhalb (dann gilt die normale Regel).
static func respawn_for(world, distance: float) -> float:
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) not in INTERACTIVE:
			continue
		var danger_start: float = (
			float(entry.deck_start) - 1.0 if str(entry.kind) == "bridge" else float(entry.wait_line)
		)
		if d >= danger_start and d <= float(entry.zone_end):
			return float(entry.respawn)
	return -1.0


# ------------------------------------------------------------------ Bewegtes Hindernis


## Zustand des Schwunghindernisses zur Rennzeit t. "open" → "warn" (Ruf, Ast wippt,
## Wartelinie orange) → "swing" (Kiri schwingt quer über die Straße, Linie rot).
static func swing_state(entry: Dictionary, t: float) -> Dictionary:
	var blocking: float = _blocking_seconds(entry)
	var cycle: float = float(entry.open) + float(entry.warn) + blocking
	var local: float = fposmod(t + float(entry.offset), cycle)
	var lap: int = floori((t + float(entry.offset)) / cycle)
	var phase := "open"
	var progress: float = local / float(entry.open)
	var until_swing: float = float(entry.open) + float(entry.warn) - local
	if local >= float(entry.open) + float(entry.warn):
		phase = "swing"
		progress = (local - float(entry.open) - float(entry.warn)) / blocking
		until_swing = 0.0
	elif local >= float(entry.open):
		phase = "warn"
		progress = (local - float(entry.open)) / float(entry.warn)
	var until_open: float = cycle - local if phase == "swing" else 0.0
	return {
		"phase": phase,
		"progress": progress,
		"until_swing": until_swing,
		"until_open": until_open,
		"direction": 1.0 if lap % 2 == 0 else -1.0,
	}


static func _blocking_seconds(entry: Dictionary) -> float:
	return float(entry.get("swing", entry.get("closed", 2.0)))


## Querband, das ein Tor/Lavapuls/Roboter im Zustand "swing" sperrt. Eine Weiche
## ("alternate") wechselt jede Runde die Seite; die andere Spur bleibt immer offen.
static func gate_band(entry: Dictionary, state: Dictionary) -> Vector2:
	var band := Vector2(float(entry.lat_min), float(entry.lat_max))
	if bool(entry.get("alternate", false)) and float(state.direction) < 0.0:
		band = Vector2(-band.y, -band.x)
	return band


## The always open lane of a gate passage for this state (centre of the free road part).
static func free_lane(world, entry: Dictionary, state: Dictionary) -> float:
	var half: float = world.road_width_at(float(entry.plane)) * 0.5 - 1.2
	var band: Vector2 = gate_band(entry, state)
	var left_room: float = band.x - (-half)
	var right_room: float = half - band.y
	return (-half + band.x) * 0.5 if left_room >= right_room else (band.y + half) * 0.5


static func gate_hits(world, entry: Dictionary, distance: float, lateral: float, t: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	if absf(d - float(entry.plane)) > float(entry.band) + KART_HALF_LENGTH:
		return false
	var state: Dictionary = swing_state(entry, t)
	if str(state.phase) != "swing":
		return false
	var band: Vector2 = gate_band(entry, state)
	if str(entry.get("object", "")) == "robot":
		# The transport robot only blocks where it actually is on its crossing.
		var width: float = band.y - band.x
		var x: float = lerpf(-width * 0.5 - 1.8, width * 0.5 + 1.8, float(state.progress))
		var robot_lateral: float = (band.x + band.y) * 0.5 + x * float(state.direction)
		return absf(lateral - robot_lateral) < 1.8
	return lateral > band.x - 0.9 and lateral < band.y + 0.9


## Any moving blocker (Kiri or a gate) touching the kart at this place and time.
static func blocker_hits(
	world, entry: Dictionary, distance: float, lateral: float, t: float
) -> bool:
	if str(entry.kind) == "swing":
		return swing_hits(world, entry, distance, lateral, t)
	if str(entry.kind) == "gate":
		return gate_hits(world, entry, distance, lateral, t)
	return false


## Lage des Affen relativ zur Straße bei der Schwungebene: x = quer, y = über der Fahrbahn.
static func swing_offset(entry: Dictionary, state: Dictionary) -> Vector2:
	var reach: float = float(entry.reach)
	var pivot: float = float(entry.pivot_height)
	var length: float = pivot - 1.7
	var max_angle: float = asin(clampf(reach / length, 0.0, 0.95))
	var direction: float = float(state.direction)
	match str(state.phase):
		"swing":
			var u: float = clampf(float(state.progress), 0.0, 1.0)
			var eased: float = 0.5 - 0.5 * cos(u * PI)
			var angle: float = lerpf(-max_angle, max_angle, eased) * direction
			return Vector2(length * sin(angle), pivot - length * cos(angle))
		"warn":
			# Kiri wippt auf dem Ast, bevor er losschwingt (Bewegung kündigt an).
			var bob: float = 0.35 * absf(sin(float(state.progress) * TAU * 2.0))
			return Vector2(-direction * (reach + 0.6), pivot - length * cos(max_angle) + 0.4 + bob)
	return Vector2(-direction * (reach + 0.6), pivot - length * cos(max_angle) + 0.4)


## Trifft Kiri ein Kart bei (distance, lateral)? Nur wenn er tief über genau dieser Spur ist.
static func swing_hits(world, entry: Dictionary, distance: float, lateral: float, t: float) -> bool:
	var d: float = fposmod(distance, float(world.length))
	if absf(d - float(entry.plane)) > float(entry.band) + KART_HALF_LENGTH:
		return false
	var state: Dictionary = swing_state(entry, t)
	if str(state.phase) != "swing":
		return false
	var at: Vector2 = swing_offset(entry, state)
	return at.y < 2.8 and absf(at.x - lateral) < 1.6


## Zeit, die ein Kart mit Tempo v braucht, um von d bis hinter das Band zu kommen.
static func clear_time(entry: Dictionary, distance: float, speed: float, accel: float) -> float:
	var span: float = maxf(
		0.0, float(entry.plane) + float(entry.band) + KART_HALF_LENGTH - distance
	)
	var v: float = maxf(0.0, speed)
	return (sqrt(v * v + 2.0 * accel * span) - v) / maxf(accel, 0.1)


# ------------------------------------------------------------------ KI


## Leitlinie und Tempo-Obergrenze für einen Rivalen. lane = INF lässt die eigene Linie.
## Traffic: Vector3(vorne m, quer m, Tempo) wie in kart_rival_racecraft; player_key ist der
## Index des Spielereintrags (Rivalen lassen dem Kind an der Engstelle den Vortritt).
static func rival_control(
	world, distance: float, speed: float, t: float, traffic: PackedVector3Array, player_entry: int
) -> Dictionary:
	var result := {"lane": INF, "speed": INF, "waiting": false, "smooth": false}
	var d: float = fposmod(distance, float(world.length))
	for entry in of(world):
		if str(entry.kind) in ["flow", "view"]:
			continue
		if str(entry.kind) == "bridge":
			var ahead: float = float(entry.deck_start) - d
			if d > float(entry.deck_end) and d < float(entry.deck_end) + 30.0:
				result.smooth = true  # Pull away from the deck, no jump back to cruise.
				continue
			if ahead > RIVAL_LINE_LEAD or d > float(entry.deck_end):
				continue
			result.lane = 0.0
			var cap: float = RIVAL_BRIDGE_SPEED
			if ahead > 0.0:
				cap = sqrt(
					(
						RIVAL_BRIDGE_SPEED * RIVAL_BRIDGE_SPEED
						+ 2.0 * RIVAL_BRAKE * maxf(0.0, ahead - 8.0)
					)
				)
			# Single file: whoever is already in front, or the child beside us, goes first.
			if true:
				for index in range(traffic.size()):
					var other: Vector3 = traffic[index]
					var first: float = -1.6 if index == player_entry else 0.3
					if other.x > first and other.x < 18.0:
						# Keep a full kart length plus margin to the kart in front (5 m nose to nose).
						var follow: float = (
							maxf(0.0, other.z) + sqrt(2.0 * 8.0 * maxf(0.0, other.x - 5.0))
						)
						if other.x < 5.0:
							follow = maxf(0.0, other.z) * clampf((other.x - 3.6) / 1.4, 0.0, 1.0)
						cap = minf(cap, follow)
			result.speed = cap
		elif str(entry.kind) == "gate":
			var gate_line: float = float(entry.wait_line) - d
			if gate_line > 80.0 or d > float(entry.plane) + float(entry.band):
				continue
			var gate_state: Dictionary = swing_state(entry, t)
			var gate_need: float = clear_time(entry, d, speed, 30.0) + SWING_CLEAR_MARGIN
			var band: Vector2 = gate_band(entry, gate_state)
			var inner_ok: bool = (
				str(gate_state.phase) != "swing" and float(gate_state.until_swing) > gate_need
			)
			if gate_line < 0.0:
				result.smooth = true
				continue
			# Short inner line when it stays open long enough, else the open outer lane.
			result.lane = (
				(band.x + band.y) * 0.5 if inner_ok else free_lane(world, entry, gate_state)
			)
		else:
			var to_line: float = float(entry.wait_line) - d
			if to_line > 70.0 or d > float(entry.plane) + float(entry.band):
				continue
			if to_line < 0.0:
				result.smooth = true  # Committed past the waiting line: pull away smoothly.
				continue
			var state: Dictionary = swing_state(entry, t)
			var need: float = clear_time(entry, d, speed, 30.0) + SWING_CLEAR_MARGIN
			if str(state.phase) != "swing" and float(state.until_swing) > need:
				continue
			result.waiting = true
			result.speed = sqrt(2.0 * RIVAL_BRAKE * maxf(0.0, to_line - 0.6))
	return result
