extends RefCounted
## Sammelzonen für die Zufallsprismen („LUMO Sternenkompass“) – je Runde 5 bis 8 Zonen,
## nach Streckenlänge skaliert und nur dort, wo die Fahrt ruhig und sicher ist.
##
## Grundlage sind die echten Streckenkoordinaten (Distanz entlang der Strecke, Querlage
## zur Mitte) und die Passagenverträge:
##  - Sperrbereiche mit Anlauf: Rennstart, Ziellinie, Checkpoint-Grenzen (Länge/8),
##    Rampen (kickers), Looping, Sprung-/Lückenstücke, Tunnel, Abtauch-Stücke (dives),
##    offene Kanten (edges), Slalom-Tore (gates), Turbofelder (pads), Hindernisse,
##    alle LUMO-Passagen (Eisbrücke, Lianenaffe, Lavapuls, Tore, Kurven, Aussicht),
##    die Spannungsstellen (kart_track_thrills.gd: Spalt-Schanze, Kuppe, Steilkurve,
##    Turbo-Bahn) und die Fahrspaß-Höhepunkte (kart_track_highlights.gd) samt Anlauf;
##  - enge Kuppen (Höhenprofil), scharfe Kurven (Richtungswechsel), zu schmale Fahrbahn;
##  - Sichtweite aus der Fahrerkamera (gerade Sichtlinie über der Fahrbahn).
## Je Zone liegen 2 oder 3 Prismen quer zur Fahrbahn – nach der echten Breite; schmale
## Zonen wechseln zwischen links+Mitte und Mitte+rechts.
## Rein statisch und deterministisch: gleiche Strecke = gleiche Zonen.

const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
## Plan der Fahrspaß-Höhepunkte (kart_track_highlights.gd META) – nur gelesen, damit dieser
## Planer nicht den ganzen Höhepunkte-Baukasten lädt.
const HIGHLIGHT_META: String = "highlight_plan"
## Anlauf vor einer Spalt-Schanze: dort reiht sich das Feld auf die mutige oder sichere Linie.
const LEAP_LEAD_M: float = 60.0
## Anlauf vor den übrigen Spannungsstellen/Höhepunkten (Leuchttor, Spurwahl vor der Kante).
const ELEMENT_LEAD_M: float = 30.0

const MIN_ZONES: int = 5
const MAX_ZONES: int = 8
## Etwa eine Zone je 270 m: bei ~28 m/s Reisetempo rund alle 9–10 s ein Prisma.
const METRES_PER_ZONE: float = 270.0
## Prismen-Querabstand (wie die bisherige Reihe) und Abstand zur Planke.
const PRISM_SPACING: float = 3.2
const WALL_CLEARANCE: float = 1.25
## Mindest-Halbbreite für drei Prismen nebeneinander.
const THREE_WIDE_HALF: float = 2.9
## Mindest-Halbbreite überhaupt (zwei Prismen in 3,2 m Abstand + Planke).
const MIN_HALF: float = 1.6 + WALL_CLEARANCE
const SIGHT_MIN_M: float = 45.0
const SIGHT_PROBE_M: Array[float] = [90.0, 75.0, 60.0, 45.0]
## Gesamter Richtungswechsel von 35 m vor bis 15 m nach der Zone.
const MAX_TURN_DEG: float = 38.0
## Kuppe: so viele Meter liegt die Zone über der Sehne zwischen ±18 m.
const CREST_LIMIT_M: float = 0.55
const CANDIDATE_STEP: float = 2.0
## Jede Zone rastet höchstens so weit (Anteil des Idealabstands) von ihrer Ideallage ein;
## zwei Zonen liegen mindestens MIN_GAP_FRACTION des Idealabstands auseinander.
const SNAP_FRACTION: float = 0.5
const MIN_GAP_FRACTION: float = 0.5


static func target_count(length: float) -> int:
	return clampi(roundi(length / METRES_PER_ZONE), MIN_ZONES, MAX_ZONES)


## Alle Sperrbereiche als {start, end, kind}; start/end in Metern (start < end, kann
## über die Rundengrenze reichen – Prüfung über _inside).
## `occupied`: Distanzen bereits platzierter Rennelemente (Könner-Ringe, Turbo-Ringe,
## Turbofelder) – eine Zone hält davon Abstand.
static func hazards(world, occupied: Array = []) -> Array[Dictionary]:
	var length: float = float(world.length)
	var result: Array[Dictionary] = []
	result.append({"start": -45.0, "end": 75.0, "kind": "start_finish"})
	for k in range(1, 8):
		var line: float = float(k) * length / 8.0
		result.append({"start": line - 10.0, "end": line + 10.0, "kind": "checkpoint"})
	var action: Dictionary = world.action if world.action is Dictionary else {}
	for kicker in action.get("kickers", []):
		var landing: float = float(kicker.get("landing_road_end", float(kicker.take_off) + 35.0))
		result.append({"start": float(kicker.start) - 50.0, "end": landing + 10.0, "kind": "ramp"})
	for pad in action.get("pads", []):
		result.append(
			{"start": float(pad.start) - 15.0, "end": float(pad.end) + 10.0, "kind": "pad"}
		)
	var gates: Array = action.get("gates", [])
	if not gates.is_empty():
		var first: float = INF
		var last: float = -INF
		for gate in gates:
			first = minf(first, float(gate.distance))
			last = maxf(last, float(gate.distance))
		result.append({"start": first - 25.0, "end": last + 15.0, "kind": "slalom"})
	for dive in action.get("dives", []):
		result.append(
			{"start": float(dive.start) - 20.0, "end": float(dive.end) + 12.0, "kind": "dive"}
		)
	for edge in action.get("edges", []):
		result.append(
			{"start": float(edge.start) - 45.0, "end": float(edge.end) + 15.0, "kind": "open_edge"}
		)
	if not world.loop_layout.is_empty():
		var loop_at: float = float(world.loop_layout.start)
		result.append({"start": loop_at - 60.0, "end": loop_at + 95.0, "kind": "loop"})
	if not world.jump.is_empty() and world.jump.has("ramp_start"):
		(
			result
			. append(
				{
					"start": float(world.jump.ramp_start) - 50.0,
					"end":
					float(world.jump.get("gap_end", float(world.jump.ramp_start) + 40.0)) + 25.0,
					"kind": "jump",
				}
			)
		)
	var tunnel: Dictionary = world.get_meta("adventure_tunnel_plan", {})
	if not tunnel.is_empty() and tunnel.has("start"):
		result.append(
			{"start": float(tunnel.start) - 15.0, "end": float(tunnel.end) + 15.0, "kind": "tunnel"}
		)
	for entry in PASSAGES.of(world):
		var interactive: bool = (
			str(entry.kind) in PASSAGES.INTERACTIVE or str(entry.kind) == "bridge"
		)
		(
			result
			. append(
				{
					"start": float(entry.zone_start) - (50.0 if interactive else 15.0),
					"end": float(entry.zone_end) + (15.0 if interactive else 10.0),
					"kind": "passage_" + str(entry.kind),
				}
			)
		)
	# Spannungsstellen: Spalt-Schanze = Sturzstelle ("leap"), sonst "thrill_<art>".
	for thrill in THRILLS.of(world):
		var leap: bool = str(thrill.kind) == "leap"
		(
			result
			. append(
				{
					"start": float(thrill.start) - (LEAP_LEAD_M if leap else ELEMENT_LEAD_M),
					"end": float(thrill.end) + 12.0,
					"kind": "leap" if leap else "thrill_" + str(thrill.kind),
				}
			)
		)
	# Fahrspaß-Höhepunkte (Schanze, Höhepunkt, Risiko-Kante, Turbo-Bahn, Furt) samt Leuchttor.
	var highlights: Array = (
		world.get_meta(HIGHLIGHT_META, []) if world.has_meta(HIGHLIGHT_META) else []
	)
	for entry in highlights:
		(
			result
			. append(
				{
					"start": float(entry.start) - ELEMENT_LEAD_M,
					"end": float(entry.end) + 12.0,
					"kind": "highlight_" + str(entry.kind),
				}
			)
		)
	for obstacle in world.action_obstacles:
		var sampled: Dictionary = world.sample_road(obstacle)
		var at: float = float(sampled.get("distance", -1.0))
		if at >= 0.0:
			result.append({"start": at - 18.0, "end": at + 18.0, "kind": "obstacle"})
	for at in occupied:
		result.append({"start": float(at) - 18.0, "end": float(at) + 14.0, "kind": "occupied"})
	return result


static func _inside(d: float, area: Dictionary, length: float) -> bool:
	var start: float = float(area.start)
	var end: float = float(area.end)
	for shift in [-length, 0.0, length]:
		if d >= start + shift and d <= end + shift:
			return true
	return false


static func blocked_by(world, d: float, areas: Array[Dictionary]) -> String:
	var length: float = float(world.length)
	for area in areas:
		if _inside(d, area, length):
			return str(area.kind)
	return ""


## Kleinste Halbbreite (Mitte bis Planke) im Zonenbereich ±10 m.
static func usable_half(world, d: float) -> float:
	var half: float = INF
	for offset in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		half = minf(half, float(world.wall_lateral_at(fposmod(d + offset, float(world.length)))))
		var deck: float = PASSAGES.deck_half(world, d + offset)
		if deck > 0.0:
			half = minf(half, deck)
	return half - WALL_CLEARANCE


static func turn_degrees(world, d: float) -> float:
	var length: float = float(world.length)
	var total: float = 0.0
	var previous: Vector3 = world.forward(fposmod(d - 35.0, length))
	for step in range(1, 6):
		var ahead: Vector3 = world.forward(fposmod(d - 35.0 + float(step) * 10.0, length))
		total += rad_to_deg(previous.angle_to(ahead))
		previous = ahead
	return total


static func crest_height(world, d: float) -> float:
	var length: float = float(world.length)
	var here: float = world.position_at(fposmod(d, length), 0.0).y
	var before: float = world.position_at(fposmod(d - 18.0, length), 0.0).y
	var after: float = world.position_at(fposmod(d + 18.0, length), 0.0).y
	return here - (before + after) * 0.5


## Längste geprüfte Sichtweite: gerade Linie aus Augenhöhe der Fahrerkamera (2,4 m über
## der Fahrbahn, mittig) zum Prisma; Fahrbahnmitte bleibt nahe der Linie (keine Wand
## dazwischen) und die Fahrbahn liegt nirgends über der Linie (keine Kuppe dazwischen).
static func sight_distance(world, d: float, lateral: float = 0.0) -> float:
	var length: float = float(world.length)
	var target: Vector3 = world.position_at(fposmod(d, length), lateral) + Vector3.UP * 1.05
	for probe in SIGHT_PROBE_M:
		var eye: Vector3 = world.position_at(fposmod(d - probe, length), 0.0) + Vector3.UP * 2.4
		var clear: bool = true
		for k in range(1, 10):
			var t: float = float(k) / 10.0
			var on_line: Vector3 = eye.lerp(target, t)
			var road: Vector3 = world.position_at(fposmod(d - probe * (1.0 - t), length), 0.0)
			var half: float = float(world.wall_lateral_at(fposmod(d - probe * (1.0 - t), length)))
			var flat := Vector2(on_line.x - road.x, on_line.z - road.z)
			if flat.length() > half + 1.5 or road.y > on_line.y - 0.3:
				clear = false
				break
		if clear:
			return probe
	return 0.0


## Grund, warum an dieser Distanz keine Zone liegen darf ("" = frei).
static func reject_reason(world, d: float, areas: Array[Dictionary]) -> String:
	var blocked: String = blocked_by(world, d, areas)
	if not blocked.is_empty():
		return blocked
	if usable_half(world, d) < MIN_HALF:
		return "narrow"
	if turn_degrees(world, d) > MAX_TURN_DEG:
		return "sharp_turn"
	if absf(crest_height(world, d)) > CREST_LIMIT_M:
		return "crest"
	if sight_distance(world, d) < SIGHT_MIN_M:
		return "sight"
	return ""


static func laterals_for(world, d: float, zone_index: int) -> Array[float]:
	var half: float = usable_half(world, d)
	var reach: float = minf(PRISM_SPACING, half)
	if half >= THREE_WIDE_HALF:
		return [-reach, 0.0, reach]
	# Schmal: zwei Prismen, abwechselnd links+Mitte und Mitte+rechts.
	var side: float = -1.0 if zone_index % 2 == 0 else 1.0
	return [0.0, side * reach] if side > 0.0 else [side * reach, 0.0]


## Die Zonen einer Runde: [{distance, laterals, sight, half, turn}], nach Distanz sortiert.
static func plan(world, occupied: Array = []) -> Array[Dictionary]:
	var length: float = float(world.length)
	var zones: Array[Dictionary] = []
	if length <= 0.0:
		return zones
	var areas: Array[Dictionary] = hazards(world, occupied)
	var free: Array[float] = []
	var d: float = 0.0
	while d < length:
		if reject_reason(world, d, areas).is_empty():
			free.append(d)
		d += CANDIDATE_STEP
	if free.is_empty():
		return zones
	# Erst die Wunschzahl, dann weniger. Gelingt keine Zahl genau, gilt die größte gefundene
	# Verteilung (vorher die der letzten, kleinsten Zahl – auf dicht bebauten Strecken wie dem
	# Zauberwald fielen so mögliche fünf Zonen auf vier zurück).
	var picks: Array[float] = []
	for count in range(target_count(length), MIN_ZONES - 2, -1):
		var trial: Array[float] = _best_spread(free, count, length)
		if trial.size() > picks.size() or (trial.size() == count and trial.size() == picks.size()):
			picks = trial
		if picks.size() >= count:
			break
	for i in range(picks.size()):
		var at: float = picks[i]
		(
			zones
			. append(
				{
					"distance": at,
					"laterals": laterals_for(world, at, i),
					"sight": sight_distance(world, at),
					"half": usable_half(world, at),
					"turn": turn_degrees(world, at),
				}
			)
		)
	return zones


## Gleichmäßige Verteilung: ideale Abstände length/count, jede Zone rastet auf die nächste
## freie Stelle innerhalb ±SNAP_FRACTION ein; Mindestabstand MIN_GAP_FRACTION (auch über die
## Rundengrenze).
static func _best_spread(free: Array[float], count: int, length: float) -> Array[float]:
	var spacing: float = length / float(count)
	var best: Array[float] = []
	var best_error: float = INF
	for phase_step in range(24):
		var phase: float = spacing * float(phase_step) / 24.0
		var picks: Array[float] = []
		var error: float = 0.0
		for k in range(count):
			var ideal: float = phase + spacing * float(k)
			var snap: float = -1.0
			var snap_error: float = spacing * SNAP_FRACTION
			for candidate in free:
				var miss: float = absf(candidate - ideal)
				if miss <= snap_error:
					snap_error = miss
					snap = candidate
			if snap < 0.0:
				continue
			if not picks.is_empty() and snap - picks.back() < spacing * MIN_GAP_FRACTION:
				continue
			picks.append(snap)
			error += snap_error
		if picks.size() >= 2 and picks[0] + length - picks.back() < spacing * MIN_GAP_FRACTION:
			picks.pop_back()
		if picks.size() > best.size() or (picks.size() == best.size() and error < best_error):
			best = picks
			best_error = error
	return best


## Rivalen mit leerem Item-Feld steuern das nächste Prisma voraus an (gleiche Regel wie
## für die Könner-Ringe). INF = kein Prisma in Reichweite.
static func rival_lane(
	distances: Array[float],
	laterals: Array[float],
	at: float,
	lane: float,
	speed: float,
	length: float
) -> float:
	var reach: float = maxf(26.0, absf(speed) * 1.35)
	var best: float = INF
	var best_lane: float = INF
	for i in range(distances.size()):
		var ahead: float = fposmod(distances[i] - at, length)
		if ahead <= 1.0 or ahead >= reach:
			continue
		var score: float = ahead + absf(laterals[i] - lane) * 6.0
		if score < best:
			best = score
			best_lane = laterals[i]
	return best_lane
