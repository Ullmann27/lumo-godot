extends RefCounted
## Baut die Abenteuer-Dramaturgie aus kart_adventure_drama.gd in eine LumoRaceWorld:
## Akt-Tore/-Schilder, Höhepunkt-Licht, leuchtende Randlinien, Kurven-Chevrons an engen
## Kurven, Themen-Deko, faire Hindernisse (world.action_obstacles) und benannte
## Marker3D-Platzhalter für die Gefahren-/Sprung-Bauteile von Lumo · Design.
## Ändert weder Straßen-, Loop- noch Rampengeometrie und keine Fahrphysik-Konstanten.
const DRAMA = preload("res://scripts/games/kart_adventure_drama.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
## Trefferradius der bestehenden Hindernis-Abfrage in kart_island._track_events (0.9 m).
const HIT_RADIUS := 0.9
const SIGN_LEAD := 26.0
const CURVE_THRESHOLD := 0.26
const CLEARANCE := 16.0

const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const HIGHLIGHTS = preload("res://scripts/games/kart_track_highlights.gd")


static func build(world) -> void:
	var track_id: String = str(world.track_id)
	var length: float = float(world.length)
	if length <= 0.0:
		return
	var profile: Dictionary = DRAMA.profile(track_id)
	var root := Node3D.new()
	root.name = "AbenteuerDramaturgie"
	world.add_child(root)
	var markers := Node3D.new()
	markers.name = "AbenteuerBauteilPlatzhalter"
	root.add_child(markers)
	var report := {
		"track": track_id, "obstacles": 0, "markers": [], "skipped": [], "curves": 0, "acts": 0
	}
	report.curves = _curve_chevrons(world, length)
	if profile.is_empty():
		world.set_meta("adventure_drama", report)
		return
	var glow: Color = profile.get("glow", Color("63dce9"))
	var blocked: Array = ACTION._blocked_ranges(world, length)
	var taken: Array = _action_taken(world, length)
	for fraction in DRAMA.turbo_fractions(track_id):
		taken.append(Vector2(float(fraction) * length - 2.0, float(fraction) * length + 8.0))
	for act in profile.get("acts", []):
		_act_sign(world, float(act[0]) * length, str(act[1]), glow)
		report.acts += 1
	var climax: Array = profile.get("climax", [])
	if climax.size() == 2:
		_climax(
			world,
			float(climax[0]) * length,
			float(climax[1]) * length,
			glow,
			str(profile.get("title", ""))
		)
	_theme_decor(world, str(profile.get("decor", "")), length, glow)
	var allow_obstacles: bool = not bool(profile.get("no_obstacles", false))
	var index := 0
	for beat in profile.get("beats", []):
		var kind: String = str(beat[1])
		var side: float = float(beat[2])
		# Von kart_track_highlights.gd als echtes Element gebaut: kein Platzhalter-Schild mehr.
		if kind == "bauteil" and HIGHLIGHTS.realises(track_id, str(beat[3])):
			report.skipped.append({"beat": index, "kind": kind, "realised": str(beat[3])})
			index += 1
			continue
		var span := 28.0 if kind == "slalom" else 14.0
		# A beat next to a LUMO passage moves behind it: the passage is the moment there.
		var wish: float = PASSAGES.after_zone(world, float(beat[0]) * length, 70.0)
		var start: float = ACTION._free_start(wish, span, length, blocked, taken)
		if (
			start < 0.0
			or absf(start - wish) > 60.0
			or ADVENTURE_TUNNEL_CONTAINS(world, start, span)
			or PASSAGES.near_zone(world, start, 40.0)
		):
			report.skipped.append({"beat": index, "kind": kind, "wish_m": snappedf(wish, 0.1)})
			index += 1
			continue
		taken.append(Vector2(start, start + span))
		match kind:
			"rocks":
				if allow_obstacles:
					report.obstacles += _rocks(world, start, side)
			"slalom":
				if allow_obstacles:
					report.obstacles += _slalom(world, start, str(profile.get("decor", "")))
			"lianen":
				if allow_obstacles:
					report.obstacles += _lianen(world, start)
			"bauteil":
				var id: String = str(beat[3])
				report.markers.append(_marker(world, markers, id, start, side, index))
		index += 1
	world.set_meta("adventure_drama", report)


static func ADVENTURE_TUNNEL_CONTAINS(world, start: float, span: float) -> bool:
	return TUNNELS.contains(world, start + span * 0.5, span * 0.5 + 6.0)


static func _action_taken(world, length: float) -> Array:
	var taken: Array = []
	var action: Dictionary = world.action
	for pad in action.get("pads", []):
		taken.append(Vector2(float(pad.start), float(pad.end)))
	for gate in action.get("gates", []):
		taken.append(Vector2(float(gate.distance) - 6.0, float(gate.distance) + 6.0))
	for kicker in action.get("kickers", []):
		var a: float = float(kicker.get("start", kicker.get("take_off", 0.0))) - 10.0
		taken.append(Vector2(a, a + 60.0))
	for key in ["dives", "edges"]:
		for zone in action.get(key, []):
			taken.append(
				Vector2(
					float(zone.get("start", 0.0)),
					float(zone.get("end", zone.get("start", 0.0) + 30.0))
				)
			)
	return taken


# ------------------------------------------------------------------ Lesbarkeit


static func _curve_chevrons(world, length: float) -> int:
	## Gelbe Chevron-Tafeln außen an jeder engen Kurve (Richtungswechsel > 0.26 rad auf 30 m).
	var placed := 0
	var d := 40.0
	while d < length - 40.0:
		var a: Vector3 = world.forward(d)
		var b: Vector3 = world.forward(d + 30.0)
		var turn := atan2(a.cross(b).y, a.dot(b))
		if absf(turn) > CURVE_THRESHOLD and not TUNNELS.contains(world, d + 15.0, 20.0):
			var outer := -1.0 if turn > 0.0 else 1.0
			for board in range(4):
				var bd := d + 4.0 + board * 6.5
				var basis: Basis = world.frame(bd)
				var at: Vector3 = world.position_at(bd, outer * 7.0) + basis.y * 1.5
				world._prop("box", at, Vector3(1.5, 1.2, 0.12), Color("ffd449"), basis, true)
				for stripe in [-0.28, 0.28]:
					world._prop(
						"box",
						at + basis.x * stripe + basis.z * 0.08,
						Vector3(0.62, 0.16, 0.05),
						Color("1b2835"),
						basis.rotated(basis.z, (1.0 if outer > 0.0 else -1.0) * 0.72)
					)
				world._prop(
					"box", at - basis.y * 1.05, Vector3(0.14, 1.0, 0.14), Color("2b3446"), basis
				)
			placed += 1
			d += 46.0
		else:
			d += 10.0
	return placed


static func _edge_glow(world, from: float, to: float, color: Color) -> void:
	var d := from
	while d < to:
		var basis: Basis = world.frame(d + 2.0)
		for side in [-1.0, 1.0]:
			world._prop(
				"box",
				world.position_at(d + 2.0, side * 5.25) + basis.y * 0.05,
				Vector3(0.16, 0.05, 3.2),
				color,
				basis,
				true
			)
		d += 4.0


static func _act_sign(world, distance: float, text: String, glow: Color) -> void:
	if TUNNELS.contains(world, distance, 10.0):
		return
	# A LUMO passage keeps its gap and plaza clear: the act sign stands before it.
	var passage: Dictionary = PASSAGES.zone_at(world, distance)
	if not passage.is_empty():
		distance = float(passage.zone_start) - 40.0
	var basis: Basis = world.frame(distance)
	var side := 1.0
	var foot: Vector3 = world.position_at(distance, side * 7.4)
	world._prop("box", foot + basis.y * 1.6, Vector3(0.22, 3.2, 0.22), Color("1d2a40"), basis)
	world._prop("box", foot + basis.y * 3.5, Vector3(4.4, 1.1, 0.16), Color("0f1d36"), basis)
	world._prop("box", foot + basis.y * 2.92, Vector3(4.5, 0.08, 0.2), glow, basis, true)
	world._sign(foot + basis.y * 3.5 + basis.z * 0.1, basis, text, 0.012)


static func _climax(world, from: float, to: float, glow: Color, title: String) -> void:
	world._arch(from, "HÖHEPUNKT · " + title.to_upper(), glow)
	_edge_glow(world, from, to, glow)
	var d := from + 6.0
	var side := -1.0
	while d < to:
		if not TUNNELS.contains(world, d, 4.0):
			var basis: Basis = world.frame(d)
			var foot: Vector3 = world.position_at(d, side * 7.2)
			world._prop(
				"cylinder", foot + basis.y * 1.7, Vector3(0.12, 3.4, 0.12), Color("223049"), basis
			)
			world._prop(
				"ball",
				foot + basis.y * 3.55,
				Vector3(0.34, 0.34, 0.34),
				glow.lightened(0.25),
				basis,
				true
			)
		side = -side
		d += 9.0


# ------------------------------------------------------------------ Hindernisse (fair)


static func _obstacle(world, at: Vector3) -> void:
	world.action_obstacles.append(at)


static func _rocks(world, start: float, side: float) -> int:
	## Felsbrocken-Gruppe auf EINER Seite; die andere Hälfte (>= 4 m) bleibt frei.
	var lane := (side if side != 0.0 else 1.0) * 2.9
	var count := 0
	for i in range(2):
		var d := start + 3.0 + i * 7.0
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, lane + (0.4 if i == 1 else 0.0) * signf(lane))
		world._prop(
			"rock",
			at + basis.y * 0.55,
			Vector3(1.8, 1.25, 1.6),
			Color("6b5a4c"),
			basis.rotated(basis.y, i * 1.3)
		)
		world._prop(
			"box", at + basis.y * 0.02, Vector3(2.2, 0.03, 0.18), Color("ffd449"), basis, true
		)
		_obstacle(world, at)
		count += 1
	_warning(world, start - SIGN_LEAD, signf(lane), "FELSEN!")
	return count


static func _slalom(world, start: float, decor: String) -> int:
	var color := Color("ff8a39")
	var shape := "rock"
	match decor:
		"winter":
			color = Color("cfeeff")
			shape = "crystal"
		"galaxy":
			color = Color("8d7bd8")
		"desert":
			color = Color("c9955a")
		"volcano":
			color = Color("3c2e2c")
	var count := 0
	for i in range(3):
		var d := start + 4.0 + i * 10.0
		var lane := 2.6 if i % 2 == 0 else -2.6
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, lane)
		world._prop(
			shape, at + basis.y * 0.6, Vector3(1.6, 1.3, 1.6), color, basis, decor == "winter"
		)
		_obstacle(world, at)
		count += 1
	_warning(world, start - SIGN_LEAD, 1.0, "SLALOM!")
	return count


static func _lianen(world, start: float) -> int:
	## Lianen-Vorhang: Bündel links und rechts (Treffer), Mitte frei; Ranken hoch über der Spur.
	var d := start + 6.0
	var basis: Basis = world.frame(d)
	var centre: Vector3 = world.position_at(d)
	for side in [-1.0, 1.0]:
		world._prop(
			"cylinder",
			centre + basis.x * side * 6.6 + basis.y * 3.4,
			Vector3(0.5, 6.8, 0.5),
			Color("5a3e26"),
			basis
		)
	world._prop("box", centre + basis.y * 6.6, Vector3(13.6, 0.35, 0.35), Color("4a3420"), basis)
	var count := 0
	for i in range(9):
		var x := -4.0 + i * 1.0
		var hang := 1.4 if absf(x) < 2.2 else 4.6
		var at: Vector3 = centre + basis.x * x
		world._prop(
			"cylinder",
			at + basis.y * (6.6 - hang * 0.5),
			Vector3(0.07, hang, 0.07),
			Color("3f8f3a"),
			basis
		)
		world._prop(
			"ball",
			at + basis.y * (6.6 - hang),
			Vector3(0.22, 0.22, 0.22),
			Color("7cf2a6"),
			basis,
			true
		)
	for lane in [-3.6, 3.6]:
		var at: Vector3 = world.position_at(d, lane)
		world._prop(
			"cylinder", at + basis.y * 1.1, Vector3(0.55, 2.2, 0.55), Color("2f6f2c"), basis
		)
		_obstacle(world, at)
		count += 1
	_warning(world, start - SIGN_LEAD, 1.0, "LIANEN!")
	return count


static func _warning(world, distance: float, side: float, text: String) -> void:
	if distance < 10.0 or TUNNELS.contains(world, distance, 6.0):
		return
	var basis: Basis = world.frame(distance)
	var foot: Vector3 = world.position_at(distance, (side if side != 0.0 else 1.0) * 7.1)
	world._prop("box", foot + basis.y * 1.0, Vector3(0.14, 2.0, 0.14), Color("2b3446"), basis)
	world._prop(
		"cone", foot + basis.y * 2.45, Vector3(0.95, 1.1, 0.12), Color("ffcc33"), basis, true
	)
	world._sign(foot + basis.y * 2.4 + basis.z * 0.12, basis, text, 0.011)


# ------------------------------------------------------------------ Bauteil-Platzhalter


static func _marker(
	world, parent: Node3D, id: String, start: float, side: float, index: int
) -> Dictionary:
	var marker := Marker3D.new()
	marker.name = "Bauteil_%s_%02d" % [id, index]
	var lateral := side * 2.5
	marker.transform = Transform3D(world.frame(start), world.position_at(start, lateral))
	marker.set_meta("bauteil", id)
	marker.set_meta("beschreibung", DRAMA.BAUTEILE.get(id, id))
	marker.set_meta("distance_m", start)
	marker.set_meta("lateral_m", lateral)
	marker.set_meta("laenge_m", 14.0)
	marker.set_meta("lieferant", "Lumo · Design (lumo-2040/kart-*)")
	parent.add_child(marker)
	var label := {
		"gefahr_lavaspalt": "LAVA!",
		"gefahr_wasserfurt": "WASSER!",
		"gefahr_pendel": "PENDEL!",
		"gefahr_rollfelsen": "STEINSCHLAG!",
		"gefahr_eisrutsche": "GLATTEIS!",
		"gefahr_meteor": "METEORE!",
		"gefahr_sandwirbel": "SANDSTURM!",
		"gefahr_geysir": "GEYSIR!",
		"sprung_rampe": "SPRUNG!",
		"abkuerzung_risiko": "ABKÜRZUNG ➜",
	}
	_warning(
		world, start - SIGN_LEAD, side if side != 0.0 else -1.0, str(label.get(id, "ACHTUNG!"))
	)
	return {
		"name": marker.name, "bauteil": id, "distance_m": snappedf(start, 0.1), "lateral_m": lateral
	}


# ------------------------------------------------------------------ Themen-Deko


static func _theme_decor(world, decor: String, length: float, glow: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(world.track_id)) & 0x7fffffff
	var count := 56 if not world.low_detail else 24
	for i in range(count):
		var d := (float(i) + rng.randf()) * length / float(count)
		if TUNNELS.contains(world, d, 8.0) or PASSAGES.keeps_clear(world, d, 12.0):
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lateral := side * rng.randf_range(10.0, 22.0)
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, lateral)
		var s := rng.randf_range(0.8, 1.6)
		match decor:
			"volcano":
				world._prop(
					"rock",
					at + basis.y * 0.8 * s,
					Vector3(2.4, 1.8, 2.2) * s,
					Color("2a2225"),
					basis.rotated(basis.y, rng.randf() * TAU)
				)
				if i % 3 == 0:
					world._prop(
						"box",
						at + basis.y * 0.05,
						Vector3(3.2, 0.06, 0.5) * s,
						Color("ff6a1f"),
						basis.rotated(basis.y, rng.randf() * TAU),
						true
					)
			"winter":
				# Kulissen-Paket: verschneiter Nadelbaum (Blender-Modell) statt Kegel.
				world.plant_scenery(
					"winterbaum",
					at,
					0.55 * s,
					float(i) * 1.3,
					Color(0.5, 0.5, 0.53),
					fposmod(float(i) * 0.29, 1.0)
				)
				if i % 4 == 0:
					world._prop(
						"crystal",
						at + basis.x * 2.0 + basis.y * 0.9,
						Vector3(0.6, 1.8, 0.6) * s,
						Color("9fe8ff"),
						basis,
						true
					)
			"galaxy":
				var up := at + basis.y * rng.randf_range(6.0, 16.0)
				world._prop(
					"rock",
					up,
					Vector3(1.4, 1.1, 1.3) * s,
					Color("5b5574"),
					basis.rotated(basis.y, rng.randf() * TAU)
				)
				if i % 4 == 0:
					world._prop(
						"ball",
						up + basis.y * 3.0,
						Vector3(0.4, 0.4, 0.4),
						glow.lightened(0.3),
						basis,
						true
					)
			"desert":
				if i % 3 == 0:
					world._prop(
						"cylinder",
						at + basis.y * 1.4 * s,
						Vector3(0.35, 2.8, 0.35) * s,
						Color("4d8f4a"),
						basis
					)
					world._prop(
						"cylinder",
						at + basis.x * 0.5 + basis.y * 1.8 * s,
						Vector3(0.2, 1.0, 0.2) * s,
						Color("4d8f4a"),
						basis.rotated(basis.z, 0.9)
					)
				else:
					world._prop(
						"rock",
						at + basis.y * 0.6 * s,
						Vector3(2.6, 1.3, 2.0) * s,
						Color("b77b45"),
						basis.rotated(basis.y, rng.randf() * TAU)
					)
			"jungle":
				# Kulissen-Paket: Dschungelbaum und Busch (Blender-Modelle) statt Kugelkronen.
				world.plant_scenery(
					"dschungelbaum",
					at,
					0.47 * s,
					float(i) * 2.1,
					Color(0.48, 0.52, 0.47),
					fposmod(float(i) * 0.31, 1.0)
				)
				if i % 3 == 0:
					world.plant_scenery(
						"busch_bluehend",
						at + basis.x * 1.4,
						0.8,
						float(i),
						Color(0.5, 0.52, 0.48),
						0.4
					)
					world._prop(
						"ball",
						at + basis.x * 1.4 + basis.y * 1.0,
						Vector3(0.16, 0.16, 0.16),
						Color("ff7ad9"),
						basis,
						true
					)
			"harbor":
				if i % 4 == 0:
					world._prop(
						"cylinder",
						at + basis.y * 1.6,
						Vector3(0.1, 3.2, 0.1),
						Color("223049"),
						basis
					)
					world._prop(
						"ball",
						at + basis.y * 3.3,
						Vector3(0.26, 0.26, 0.26),
						Color("ffe1a0"),
						basis,
						true
					)
