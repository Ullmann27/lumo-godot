extends RefCounted
## LUMO-Höhepunkte je Strecke (Fahrspaß-Audit 19.11.2026, kart_track_fun_survey).
## Füllt die längsten Abschnitte ohne markante Stelle mit echten, befahrbaren Elementen aus
## den vorhandenen Bausteinen des Action-Parcours (kart_action_course.gd):
##
##   schanze    volle Breite, Schanze 12 m / 1,6 m wie die Sonnenhafen-Zusatzschanzen
##              (Schwerkraft 30, Hub-Bonus 2,0, Deckel 6,0): ≈ 0,5–0,6 s Flug, Landungsturbo.
##   hoehepunkt sicherer Höhepunkt: Schanze 14 m / 1,8 m, Schwerkraft 22, Bonus 3,0, Deckel 8,0
##              → bei 50 m/s ≈ 0,9 s Flug, Scheitel ≈ 1,5 m über der Lippe; Landebahn 95 m
##              durchgehend Straße, geprüft geradeaus (kein Spalt, kein Tunnel, keine Decke).
##   risiko     Risiko-Entscheidung: außen in einer Kurve fehlt 34 m lang die Leitplanke
##              (offene Kante, Lumo-Wolke rettet), genau dort liegen zwei Turbo-Felder.
##              Wer mutig außen fährt, holt Turbo; wer innen bleibt, fährt sicher ohne.
##              Kante und Rettungspunkt liegen im selben Checkpoint-Abschnitt (Länge/8),
##              nie vor 350 m (Gerätefund 19.11.).
##   turbobahn  Finale: drei mittige Turbo-Felder im Abstand von 22 m unter Leuchtbögen.
##   furt       Wasserfurt: vorhandene Tauchstrecke (Tempo × 0,9, Wasserwände).
##
## Alles wird in world.action eingetragen (nach kart_action_course.plan, kart_passages und
## kart_track_thrills.extend_action). Spieler, Rivalen (kart_rival_flight), Rücksetzer,
## Lasso-Posten und Dramaturgie-Hindernisse lesen dieselben Daten und weichen ihnen aus; die
## Sammelzonen (kart_item_zones.hazards) und die Treffer-Fairness kennen zusätzlich den ganzen
## Plan (META „highlight_plan“) samt Leuchttor als Sperrbereich.
## Die Planung läuft nach den Spannungsstellen (kart_track_thrills.gd) und sucht nur noch
## freie Abschnitte; sie ergänzt dort, was jener Baukasten nicht hat (Risiko-Kante).
## Ein Bauteil-Platzhalter der Dramaturgie (Schild „SPRUNG!“ / „ABKÜRZUNG ➜“ ohne Funktion),
## den ein Element hier verwirklicht, entfällt dort (realises()).

const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const DRAMA = preload("res://scripts/games/kart_adventure_drama.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
const LASSO = preload("res://scripts/games/kart_roadside_lasso.gd")
const PRODUCTION_TUNNEL = preload("res://scripts/games/kart_production_tunnel_layout.gd")
const META: String = "highlight_plan"
## Gerätefund 19.11.: keine Sturz-, Warte- oder Treffer-Stelle vor diesem Punkt.
const SAFE_START_M: float = 350.0
const SEARCH_M: float = 140.0
const STEP_M: float = 4.0
const CLEARANCE: float = 16.0
const EDGE_LENGTH: float = 34.0
const RISK_LANE: float = 3.3
const TURBO_SPACING: float = 22.0
const KICKERS: Dictionary = {
	"schanze":
	{
		"length": 12.0,
		"height": 1.6,
		"flight_gravity": 30.0,
		"lift_bonus": 2.0,
		"max_lift": 6.0,
		"landing": 70.0
	},
	"hoehepunkt":
	{
		"length": 14.0,
		"height": 1.8,
		"flight_gravity": 22.0,
		"lift_bonus": 3.0,
		"max_lift": 8.0,
		"landing": 95.0
	},
}

## Je Strecke: Wunschlage in Metern (negativ = vor dem Ziel). Die Planung rückt jedes
## Element auf den nächsten freien, passenden Abschnitt (± SEARCH_M).
const SPECS: Dictionary = {
	# Funkel-Labor (Spannungsstellen aus kart_track_thrills.gd): dazu die Funken-Kante als
	# Risiko-Wahl in einer echten Kurve – außen offene Kante mit zwei Turbo-Feldern, innen
	# sicher. Vorher gab es hier keine offene Kante.
	"learning_lab":
	[
		{"kind": "risiko", "id": "funkenkante", "at": 1420.0, "name": "Funken-Kante"},
	],
}

## Nur für Vorher/Nachher-Messungen (kart_track_fun_survey --highlights-off).
static var enabled: bool = true


static func has(track_id: String) -> bool:
	return enabled and SPECS.has(track_id)


static func specs_for(track_id: String) -> Array:
	return SPECS.get(track_id, []) if enabled else []


## True, wenn ein Element dieser Strecke den genannten Dramaturgie-Platzhalter verwirklicht.
static func realises(track_id: String, bauteil: String) -> bool:
	for spec in specs_for(track_id):
		if str(spec.get("replaces", "")) == bauteil:
			return true
	return false


static func of(world) -> Array:
	return world.get_meta(META, []) if world.has_meta(META) else []


static func extend_action(world) -> void:
	var specs: Array = specs_for(str(world.track_id))
	var placed: Array = []
	if specs.is_empty() or world.action.is_empty():
		world.set_meta(META, placed)
		return
	var length: float = float(world.length)
	var blocked: Array = _blocked(world, length)
	for spec in specs:
		var wish: float = float(spec.at)
		if wish < 0.0:
			wish += length
		var entry: Dictionary = _place(world, spec, wish, length, blocked)
		if entry.is_empty():
			push_warning("[KartHighlights] %s: kein Platz für %s" % [world.track_id, spec.id])
			continue
		_apply(world, entry)
		blocked.append(Vector2(float(entry.start) - CLEARANCE, float(entry.end) + CLEARANCE))
		placed.append(entry)
	world.set_meta(META, placed)


## Alles, was schon auf der Strecke liegt, plus Start/Ziel, Tunnel, Looping, Lasso-Posten.
static func _blocked(world, length: float) -> Array:
	var blocked: Array = ACTION._blocked_ranges(world, length)
	blocked.append(Vector2(0.0, 60.0))
	var action: Dictionary = world.action
	for pad in action.get("pads", []):
		blocked.append(Vector2(float(pad.start) - 10.0, float(pad.end) + 10.0))
	for gate in action.get("gates", []):
		blocked.append(Vector2(float(gate.distance) - 14.0, float(gate.distance) + 10.0))
	for kicker in action.get("kickers", []):
		blocked.append(Vector2(float(kicker.start) - 30.0, float(kicker.take_off) + 70.0))
	for key in ["dives", "edges"]:
		for zone in action.get(key, []):
			blocked.append(Vector2(float(zone.start) - 30.0, float(zone.end) + 30.0))
	var loop: Dictionary = world.loop_layout
	if not loop.is_empty():
		blocked.append(Vector2(float(loop.start) - 200.0, float(loop.start) + 120.0))
	var tunnel: Dictionary = world.get_meta("adventure_tunnel_plan", {})
	if not tunnel.is_empty():
		blocked.append(Vector2(float(tunnel.start) - 110.0, float(tunnel.end) + 40.0))
	for entry in PASSAGES.of(world):
		blocked.append(Vector2(float(entry.zone_start) - 40.0, float(entry.zone_end) + 20.0))
	# Der Produktionstunnel wird erst nach diesem Plan gesetzt (Wunschlage PREFERRED): sein
	# Bereich bleibt frei, damit er nicht wandert und keine Schanze unter eine Decke führt.
	var tunnel_wish: float = float(PRODUCTION_TUNNEL.PREFERRED.get(str(world.track_id), -1.0))
	if tunnel_wish > 0.0:
		var middle: float = tunnel_wish * length
		blocked.append(Vector2(middle - 140.0, middle + 70.0))
	for fraction in DRAMA.turbo_fractions(str(world.track_id)):
		var d: float = float(fraction) * length
		blocked.append(Vector2(d - 20.0, d + 20.0))
	# Resonanzringe (Dramaturgie) und Turbo-Ringe (kart_island BOOST_RING_LAYOUT 0,27 / 0,61)
	# hängen in Fahrhöhe: nie auf einer Rampe oder Landebahn.
	var rings: Array = [0.27, 0.61]
	for entry in DRAMA.item_layout(str(world.track_id)):
		rings.append(float(entry[0]))
	for fraction in rings:
		var at: float = PASSAGES.clear_distance(world, float(fraction) * length)
		blocked.append(Vector2(at - 15.0, at + 15.0))
	# Lasso-Posten werden nach der Strecke geplant und meiden Schanzen: ihre heutige Lage
	# bleibt frei, damit sie nicht wandern.
	for crew in LASSO.plan(world):
		blocked.append(Vector2(float(crew.distance) - 100.0, float(crew.distance) + 100.0))
	return blocked


static func _free(span: Vector2, blocked: Array) -> bool:
	for zone in blocked:
		var area: Vector2 = zone
		if span.x < area.y and span.y > area.x:
			return false
	return true


static func _turn(world, a: float, b: float) -> float:
	var fa: Vector3 = world.forward(a)
	var fb: Vector3 = world.forward(b)
	return atan2(fa.cross(fb).y, fa.dot(fb))


static func _straight(world, a: float, b: float) -> bool:
	var base: Vector3 = world.forward(a)
	var d: float = a + 10.0
	while d <= b:
		if base.dot(world.forward(d)) < 0.90:
			return false
		d += 10.0
	return true


## Keine Decke über der Flugbahn (Tunnel, Brücken, gestapelte Kreuzungen) bis 6 m Höhe.
static func _open_sky(world, a: float, b: float) -> bool:
	if TUNNELS.contains(world, (a + b) * 0.5, (b - a) * 0.5 + 10.0):
		return false
	var samples: PackedVector3Array = world._road_samples
	var distances: PackedFloat32Array = world._road_distances
	var length: float = float(world.length)
	var d: float = a
	while d <= b:
		var here: Vector3 = world.position_at(d)
		for i in range(samples.size()):
			var along: float = absf(float(distances[i]) - fposmod(d, length))
			if minf(along, length - along) < 40.0:
				continue
			var other: Vector3 = samples[i]
			var rise: float = other.y - here.y
			if (
				rise > 0.5
				and rise < 9.0
				and Vector2(other.x - here.x, other.z - here.z).length() < 9.0
			):
				return false
		d += 8.0
	return true


static func _section_ok(length: float, a: float, b: float) -> bool:
	var section: float = length / 8.0
	var first: int = int(floorf((a - 15.0) / section))
	return first == int(floorf((b + 20.0) / section)) and a >= SAFE_START_M


static func _span(kind: String, start: float) -> Vector2:
	match kind:
		"schanze", "hoehepunkt":
			return Vector2(
				start, start + float(KICKERS[kind].length) + float(KICKERS[kind].landing)
			)
		"risiko":
			return Vector2(start, start + EDGE_LENGTH)
		"turbobahn":
			return Vector2(start, start + TURBO_SPACING * 2.0 + ACTION.PAD_LENGTH)
		"furt":
			return Vector2(start, start + 44.0)
	return Vector2(start, start + 10.0)


static func _suits(world, kind: String, span: Vector2, length: float) -> bool:
	if span.x < 60.0 or span.y > length - 45.0:
		return false
	match kind:
		"schanze", "hoehepunkt":
			return _straight(world, span.x, span.y) and _open_sky(world, span.x, span.y)
		"risiko":
			# Nur in einer echten Kurve: außen trägt der Schwung hinaus.
			return absf(_turn(world, span.x, span.y)) > 0.22 and _section_ok(length, span.x, span.y)
		"furt":
			return span.x >= SAFE_START_M and _straight(world, span.x, span.y)
	return true


static func _place(
	world, spec: Dictionary, wish: float, length: float, blocked: Array
) -> Dictionary:
	var kind: String = str(spec.kind)
	var steps: int = int(SEARCH_M / STEP_M)
	for step in range(steps * 2 + 1):
		var offset: float = (
			floorf(float(step + 1) / 2.0) * STEP_M * (1.0 if step % 2 == 0 else -1.0)
		)
		var start: float = wish + offset
		var span: Vector2 = _span(kind, start)
		if not _free(span, blocked) or not _suits(world, kind, span, length):
			continue
		var entry: Dictionary = spec.duplicate(true)
		entry["start"] = start
		entry["end"] = span.y
		if kind == "risiko":
			# _turn > 0: Linkskurve (Vorwärtsvektor dreht gegen den Uhrzeigersinn); außen
			# liegt dann rechts (+Querlage, world.frame().x).
			var bend: float = _turn(world, span.x, span.y)
			entry["side"] = 1.0 if bend > 0.0 else -1.0
		return entry
	return {}


static func _apply(world, entry: Dictionary) -> void:
	var action: Dictionary = world.action
	var start: float = float(entry.start)
	match str(entry.kind):
		"schanze", "hoehepunkt":
			var shape: Dictionary = KICKERS[str(entry.kind)]
			(
				action
				. kickers
				. append(
					{
						"start": start,
						"take_off": start + float(shape.length),
						"length": float(shape.length),
						"height": float(shape.height),
						"angle": atan2(float(shape.height), float(shape.length)),
						"flight_gravity": float(shape.flight_gravity),
						"lift_bonus": float(shape.lift_bonus),
						"max_lift": float(shape.max_lift),
						"action_expansion": true,
						"landing_road_end": float(entry.end),
						"highlight": str(entry.id),
					}
				)
			)
		"risiko":
			var side: float = float(entry.side)
			action.edges.append(
				{
					"start": start,
					"end": start + EDGE_LENGTH,
					"side": side,
					"highlight": str(entry.id)
				}
			)
			for along in [5.0, 21.0]:
				(
					action
					. pads
					. append(
						{
							"start": start + along,
							"end": start + along + ACTION.PAD_LENGTH,
							"lateral": side * RISK_LANE,
							"highlight": str(entry.id),
						}
					)
				)
		"turbobahn":
			for index in range(3):
				var pad_start: float = start + float(index) * TURBO_SPACING
				(
					action
					. pads
					. append(
						{
							"start": pad_start,
							"end": pad_start + ACTION.PAD_LENGTH,
							"lateral": 0.0,
							"highlight": str(entry.id),
						}
					)
				)
		"furt":
			action.dives.append(
				{"start": start, "end": float(entry.end), "highlight": str(entry.id)}
			)


# ------------------------------------------------------------------ Darstellung


## Name der Stelle auf einem Leuchttor vor dem Element; bei der Risiko-Linie zeigen zwei
## Tafeln die Wahl („MUTIG: TURBO“ außen, „SICHER“ innen).
static func build(world) -> void:
	var accent: Color = world.definition.accent
	for entry in of(world):
		var kind: String = str(entry.kind)
		var at: float = float(entry.start) - (14.0 if kind != "turbobahn" else 8.0)
		var basis: Basis = world.frame(at)
		var centre: Vector3 = world.position_at(at)
		var top: float = 6.2
		var half: float = float(world.road_width_at(at)) * 0.5
		for side in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(at, side * (half + 1.2))
			world._prop(
				"box", foot + basis.y * top * 0.5, Vector3(0.32, top, 0.32), Color("1d2a3f"), basis
			)
			world._prop(
				"box", foot + basis.y * (top - 0.2), Vector3(0.5, 0.4, 0.5), accent, basis, true
			)
		world._prop(
			"box",
			centre + basis.y * top,
			Vector3(half * 2.0 + 2.8, 0.5, 0.36),
			Color("1d2a3f"),
			basis
		)
		world._prop(
			"box",
			centre + basis.y * (top - 0.3),
			Vector3(half * 2.0 + 2.4, 0.08, 0.38),
			accent,
			basis,
			true
		)
		world._sign(
			centre + basis.y * top + basis.z * 0.2, basis, str(entry.name).to_upper(), 0.016
		)
		if kind == "risiko":
			var side: float = float(entry.side)
			var sign_at: float = float(entry.start) - 34.0
			var sign_basis: Basis = world.frame(sign_at)
			var brave: Vector3 = world.position_at(sign_at, side * (half + 1.6))
			var safe: Vector3 = world.position_at(sign_at, -side * (half + 1.6))
			for item in [
				[brave, "MUTIG: TURBO", Color("ff7a2e")], [safe, "SICHER", Color("62e38a")]
			]:
				var foot: Vector3 = item[0]
				world._prop(
					"box",
					foot + sign_basis.y * 1.1,
					Vector3(0.16, 2.2, 0.16),
					Color("2b3446"),
					sign_basis
				)
				world._prop(
					"box",
					foot + sign_basis.y * 2.5,
					Vector3(2.4, 0.8, 0.08),
					item[2],
					sign_basis,
					true
				)
				world._sign(
					foot + sign_basis.y * 2.5 + sign_basis.z * 0.1, sign_basis, str(item[1]), 0.010
				)
		if kind == "turbobahn":
			for index in range(3):
				var arch_at: float = float(entry.start) + float(index) * TURBO_SPACING + 3.0
				var arch_basis: Basis = world.frame(arch_at)
				var arch_centre: Vector3 = world.position_at(arch_at)
				for side in [-1.0, 1.0]:
					var foot: Vector3 = world.position_at(arch_at, side * (half + 1.0))
					world._prop(
						"box",
						foot + arch_basis.y * 2.4,
						Vector3(0.22, 4.8, 0.22),
						accent,
						arch_basis,
						true
					)
				world._prop(
					"box",
					arch_centre + arch_basis.y * 4.8,
					Vector3(half * 2.0 + 2.0, 0.22, 0.22),
					accent,
					arch_basis,
					true
				)
