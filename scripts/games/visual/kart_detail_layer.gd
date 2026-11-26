extends RefCounted
## Detail-Schicht der Lumo-Kart-Strecken: die vielen Kleinigkeiten, die eine
## Welt glaubwürdig machen – Verwitterung und Gebrauchsspuren (Decal-Karten),
## Kleinteile am Streckenrand (Blender-Kit), Leben (Publikum, Streckenposten,
## Vögel, Drohnen, Luftschiff), Licht-Details und die Start/Ziel-Bühne.
##
## Wird von kart_world.gd nach dem Weltaufbau aufgerufen (eine Zeile, deferred)
## und liest nur die öffentliche Strecken-API: position_at, frame, forward,
## length, road_width_at, _near_road, _ground_height, in_gap, ramp_height …
## Kein Kollisionskörper, keine Änderung an Fahrbahn, Checkpoints oder Items.
##
## Alles wird pro Streckenabschnitt in wenige zusammengeführte Meshes gebacken
## (ein Draw-Call je Abschnitt und Material). Profile:
##   low    = Start/Ziel-Bühne + wenige Spuren (ein Abschnitt, <= 6 Draw-Calls)
##   medium = gut gefüllt
##   high   = volle Detaildichte, Kleinteile werfen Schatten

const KIT = preload("res://scripts/games/visual/kart_detail_kit.gd")
const THEMES = preload("res://scripts/games/visual/kart_detail_themes.gd")
## Pfützen melden ihre Lage an die Fahreffekte (Wasserspritzer unter den Reifen).
const FX_GROUND = preload("res://scripts/games/kart_fx/kart_fx_ground.gd")
const ROOT_NAME: String = "KartDetailLayer"
const META: String = "kart_detail_layer"
const CHUNK_M: Dictionary = {"low": 100000.0, "medium": 170.0, "high": 130.0}
const DENSITY: Dictionary = {"low": 0.0, "medium": 0.62, "high": 1.0}
## Sicherheitsrand zwischen Fahrbahnkante und stehendem Kleinteil.
const CLEARANCE_M: float = 1.4
const DECAL_LIFT_M: float = 0.05
const PROP_SCALE: float = 1.25

var world
var track_id: String
var profile: String
var theme: Dictionary
var rng := RandomNumberGenerator.new()
var root: Node3D
var batches: Dictionary = {}  # "chunk:material" -> KIT.Batch
var stats: Dictionary = {"wear": 0, "props": 0, "life": 0, "light": 0, "stage": 0, "facade": 0}
var placed: Array[Dictionary] = []  # für den Test: stehende Teile mit Abstand zur Fahrbahn
var _occupied: Array[Vector3] = []
## Fremde Kulisse (Bäume/Leuchten des Kulissen-Moduls) in 8-m-Zellen: Vector4(x, y, z, Radius).
var _obstacles: Dictionary = {}
const OBSTACLE_CELL: float = 8.0


## Merkt den Aufbau für das Ende des Frames vor (nach allen Zweigen von build()).
## Ein Kindknoten der Welt trägt den verzögerten Aufruf: wird die Welt vorher
## freigegeben oder neu gebaut, verschwindet er mit ihr – ohne Fehlermeldung.
static func schedule(target: Node3D) -> void:
	var pending := Scheduler.new()
	pending.name = "KartDetailPending"
	target.add_child(pending)
	pending.call_deferred("run")


class Scheduler:
	extends Node

	func run() -> void:
		var target := get_parent() as Node3D
		queue_free()
		if target == null or target.is_queued_for_deletion():
			return
		target.remove_child(self)
		var layer: GDScript = load("res://scripts/games/visual/kart_detail_layer.gd")
		layer.apply(target, str(target.get("track_id")), layer.profile_for(target))


## Einstieg: baut (oder ersetzt) die Detail-Schicht einer fertig gebauten Strecke.
static func apply(target: Node3D, wanted_track: String, wanted_profile: String) -> void:
	if not is_instance_valid(target) or target.get("curve") == null:
		return
	if target.get("_only_geometry"):
		return
	# Für Vorher/Nachher-Aufnahmen und Messungen abschaltbar.
	if OS.get_environment("LUMO_KART_DETAILS") == "off":
		return
	var builder = new()
	builder._run(target, wanted_track, wanted_profile)


## Profil der laufenden Strecke: Leicht-Modus schlägt die App-Stufe.
static func profile_for(target: Node3D) -> String:
	if target.has_meta("kart_detail_profile"):
		return str(target.get_meta("kart_detail_profile"))
	if target.get("low_detail"):
		return "low"
	return LumoQuality.tier()


func _run(target: Node3D, wanted_track: String, wanted_profile: String) -> void:
	world = target
	# Die Welt kann zwischen Aufruf und Ausführung neu gebaut worden sein.
	track_id = str(world.track_id) if str(world.track_id) != "" else wanted_track
	profile = wanted_profile if wanted_profile in ["low", "medium", "high"] else "medium"
	theme = THEMES.theme(track_id)
	rng.seed = hash(track_id + ":details")
	var old: Node = world.get_node_or_null(ROOT_NAME)
	if old != null:
		world.remove_child(old)
		old.queue_free()
	FX_GROUND.clear_wet_spots(world)
	root = Node3D.new()
	root.name = ROOT_NAME
	world.add_child(root)
	var started: int = Time.get_ticks_usec()
	_collect_scenery()
	_stage()
	if profile == "low":
		_low_wear()
	else:
		_road_wear()
		_edge_drifts()
		_facades()
		_roadside()
		_railside()
		_life()
		_lights()
	_commit()
	var info: Dictionary = {
		"track": track_id, "profile": profile, "stats": stats.duplicate(),
		"placed": placed, "build_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"meshes": root.get_child_count(),
	}
	world.set_meta(META, info)
	root.set_meta(META, info)
	print("[KartDetail] %s %s %s %.0f ms" % [track_id, profile, JSON.stringify(stats), info.build_ms])


# ---------------------------------------------------------------- Grundlagen

## Bäume und Leuchten der Kulisse vormerken, damit kein Kleinteil darin steckt.
func _collect_scenery() -> void:
	var plants = world.get("scenery_plants")
	if plants is Dictionary:
		for species in plants:
			for t: Transform3D in plants[species].get("transforms", []):
				_add_obstacle(t.origin, clampf(t.basis.x.length() * 1.1, 0.8, 3.2))
	var scenery: Node = world.get_node_or_null("KartScenery")
	if scenery != null:
		for node in scenery.get_children():
			if node is MultiMeshInstance3D and str(node.name).begins_with("Lamps_") and str(node.name).ends_with("lod0"):
				var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
				for i in range(mm.instance_count):
					_add_obstacle((node as Node3D).position + mm.get_instance_transform(i).origin, 0.9)
	if world.has_meta("scenery_lamp_heads"):
		for head: Vector3 in world.get_meta("scenery_lamp_heads"):
			_add_obstacle(head, 1.0)


func _add_obstacle(at: Vector3, radius: float) -> void:
	var key := Vector2i(floori(at.x / OBSTACLE_CELL), floori(at.z / OBSTACLE_CELL))
	if not _obstacles.has(key):
		_obstacles[key] = []
	_obstacles[key].append(Vector4(at.x, at.y, at.z, radius))


func _hits_scenery(at: Vector3, footprint: float) -> bool:
	var cx: int = floori(at.x / OBSTACLE_CELL)
	var cz: int = floori(at.z / OBSTACLE_CELL)
	for x in range(cx - 1, cx + 2):
		for z in range(cz - 1, cz + 2):
			for o: Vector4 in _obstacles.get(Vector2i(x, z), []):
				if absf(o.y - at.y) < 8.0 and Vector2(o.x - at.x, o.z - at.z).length() < o.w + footprint + 0.3:
					return true
	return false


func _length() -> float:
	return float(world.length)


func _half_width(d: float) -> float:
	return float(world.road_width_at(d)) * 0.5


func _chunk(d: float) -> int:
	return int(floor(fposmod(d, _length()) / float(CHUNK_M[profile])))


func _batch(d: float, material: String) -> KIT.Batch:
	var key: String = "%d:%s" % [_chunk(d), material]
	if not batches.has(key):
		batches[key] = KIT.Batch.new()
	return batches[key]


## Abschnitte, an denen nichts Stehendes hindarf (Tunnel, Sprünge, Loopings, Aktionen).
func _blocked(d: float, padding: float = 10.0) -> bool:
	d = fposmod(d, _length())
	if world.ADVENTURE_TUNNELS.contains(world, d, padding):
		return true
	if world.in_gap(d) or world.in_gap(d + padding) or world.in_gap(d - padding):
		return true
	if world.PASSAGES.keeps_clear(world, d, padding):
		return true
	if world.ramp_height(d) > 0.0:
		return true
	if not world.jump.is_empty() and world.jump.has("ramp_start") and world.jump.has("gap_end"):
		if d >= float(world.jump.ramp_start) - padding * 2.0 and d <= float(world.jump.gap_end) + padding * 2.0:
			return true
	if not world.loop_layout.is_empty():
		var start: float = float(world.loop_layout.start)
		if d >= start - 25.0 and d <= start + 90.0:
			return true
	if not world.action.is_empty():
		for key in ["pads", "kickers", "dives", "edges"]:
			for item: Dictionary in world.action.get(key, []):
				var a: float = float(item.get("start", item.get("distance", 0.0)))
				var b: float = float(item.get("end", item.get("take_off", a)))
				if d >= a - padding * 2.0 and d <= b + padding * 2.0:
					return true
		for gate: Dictionary in world.action.get("gates", []):
			if absf(d - float(gate.distance)) <= padding * 1.5:
				return true
	return false


## Bodenhöhe neben der Fahrbahn oder NAN, wenn dort nichts Tragendes ist.
func _ground(at: Vector3, road_y: float) -> float:
	match str(theme.get("ground", "terrain")):
		"terrain":
			var h: float = float(world._ground_height(at.x, at.z))
			# Gelände muss die Fahrbahn begleiten (keine Brücken, kein Wasser).
			if h < road_y - 2.6 or h > road_y + 1.2 or h < float(theme.get("min_ground", -3.0)):
				return NAN
			return h
		"road":
			return road_y - 0.06
		"plane":
			return float(theme.get("plane_y", -2.0))
	return NAN


## Horizontale Basis, deren +Z zur Fahrbahn zeigt (Vorderseite der Kleinteile).
func _facing_road(d: float, side: float) -> Basis:
	var right: Vector3 = world.frame(d).x
	right.y = 0.0
	right = right.normalized()
	var z: Vector3 = -right * side
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


## Stellplatz am Rand: prüft Fahrbahnabstand (auch zu anderen Streckenteilen),
## Untergrund und Überlappung. Liefert {} wenn ungeeignet.
func _site(d: float, side: float, lateral: float, footprint: float, check_block: bool = true) -> Dictionary:
	d = fposmod(d, _length())
	if check_block and _blocked(d):
		return {}
	var half: float = _half_width(d)
	var lat: float = maxf(lateral, half + CLEARANCE_M + footprint)
	var at: Vector3 = world.position_at(d, side * lat)
	var road_y: float = world.position_at(d).y
	if world._near_road(at, half + CLEARANCE_M + footprint - 0.05):
		return {}
	var h: float = _ground(at, road_y)
	if is_nan(h):
		return {}
	at.y = h
	for other in _occupied:
		if other.distance_squared_to(at) < pow(footprint + 0.9, 2.0):
			return {}
	if _hits_scenery(at, footprint):
		stats["scenery_skips"] = int(stats.get("scenery_skips", 0)) + 1
		return {}
	_occupied.append(at)
	var site := {"at": at, "d": d, "side": side, "lateral": lat, "basis": _facing_road(d, side), "road_y": road_y}
	if str(theme.get("ground", "terrain")) == "road" and road_y - float(theme.get("plane_y", -2.0)) > 0.8:
		_pad(site, footprint)
	return site


## Auskragende Plattform ("Balkon") an der Fahrbahnkante für Strecken ohne
## Gelände daneben: so steht jedes Kleinteil sichtbar auf etwas.
func _pad(site: Dictionary, footprint: float) -> void:
	var d: float = site.d
	var side: float = site.side
	var half: float = _half_width(d)
	var inner: float = half + 0.7
	var outer: float = float(site.lateral) + footprint + 0.7
	var depth: float = footprint * 2.0 + 1.6
	var basis: Basis = site.basis
	var colour: Color = theme.get("pad_color", Color("c3c8cc"))
	var top: float = float(site.at.y)
	var mid_lat: float = (inner + outer) * 0.5
	var centre: Vector3 = world.position_at(d, side * mid_lat)
	centre.y = top - 0.14
	var along: Vector3 = basis.x
	var across: Vector3 = -basis.z
	_slab(centre, along * depth, across * (outer - inner), 0.28, colour, d)
	# Kantenleiste und Geländer außen.
	var edge: Vector3 = centre + across * (outer - inner) * 0.5
	var trim: Color = theme.get("pad_trim", Color("f6c636"))
	_beam_box(edge - along * depth * 0.5 + Vector3.UP * 0.16, edge + along * depth * 0.5 + Vector3.UP * 0.16, 0.06, trim, d, "props")
	_beam_box(edge - along * depth * 0.5 + Vector3.UP * 1.0, edge + along * depth * 0.5 + Vector3.UP * 1.0, 0.05, Color("9aa3ab"), d, "props")
	for k in [-0.5, 0.5]:
		var post: Vector3 = edge + along * depth * k * 0.96
		_beam_box(post, post + Vector3.UP * 1.0, 0.05, Color("9aa3ab"), d, "props")
	# Schräge Stütze zum Fahrbahnfundament.
	var foot: Vector3 = world.position_at(d, side * (half + 0.6)) - Vector3.UP * 1.6
	_beam_box(edge - Vector3.UP * 0.25, foot, 0.16, colour.darkened(0.25), d, "props")


func _slab(centre: Vector3, along: Vector3, across: Vector3, thickness: float, colour: Color, d: float) -> void:
	var basis := Basis(along, Vector3.UP * thickness, across)
	var lin: Color = colour.srgb_to_linear()
	_batch(d, "props").add_arrays(KIT.box_arrays(), Transform3D(basis, centre), Color(lin.r, lin.g, lin.b, 1.0))


func _put(kind: String, xform: Transform3D, d: float, category: String, tint: Color = Color.WHITE, record: bool = true) -> void:
	var arrays: Array = KIT.part(kind)
	if arrays.is_empty():
		return
	var phase: float = fposmod(xform.origin.x * 0.137 + xform.origin.z * 0.071, 1.0)
	var batch: KIT.Batch = _batch(d, "props")
	batch.add_arrays(arrays, xform, tint, phase)
	var glow: Array = KIT.part(kind + "__glow")
	if not glow.is_empty():
		_batch(d, "glow").add_arrays(glow, xform, Color.WHITE, phase)
	stats[category] = int(stats.get(category, 0)) + 1
	if record:
		var sample: Dictionary = world.sample_road(xform.origin, d)
		placed.append({"kind": kind, "distance": d, "lateral": absf(float(sample.lateral)),
			"half_width": float(sample.width) * 0.5, "flat": false, "position": xform.origin})


func _place(kind: String, site: Dictionary, category: String, offset: Vector3 = Vector3.ZERO, yaw: float = 0.0, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	# Die Lumo-Welt ist leicht überzeichnet: Kleinteile 1,25-fach, damit sie bei Tempo wirken.
	var basis: Basis = (site.basis as Basis).rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scale * PROP_SCALE)
	var origin: Vector3 = site.at + (site.basis as Basis) * offset * PROP_SCALE
	_put(kind, Transform3D(basis, origin), site.d, category, tint)


# ---------------------------------------------------------------- Decals

## Flaches Decal auf der Fahrbahn: Mittelpunkt (d, lateral), Größe along x across.
func _road_decal(tile: String, d: float, lateral: float, along: float, across: float, color: Color, spin: float = 0.0, wet: bool = false) -> void:
	d = fposmod(d, _length())
	if world.PASSAGES.keeps_clear(world, d, along * 0.5 + 1.0):
		return  # LUMO passage: no wear decals floating over the gap or on the narrow deck.
	var basis: Basis = world.frame(d)
	var up: Vector3 = basis.y
	var centre: Vector3 = world.position_at(d, lateral) + up * DECAL_LIFT_M
	var fwd: Vector3 = (-basis.z).rotated(up, spin)
	var right: Vector3 = fwd.cross(up).normalized()
	var a: Vector3 = fwd * along * 0.5
	var b: Vector3 = right * across * 0.5
	var corners: Array = [centre - a - b, centre - a + b, centre + a + b, centre + a - b]
	var road_tint: Color = theme.get("road_tint", Color.WHITE)
	if tile in ["patch", "tar", "crack", "rubber"]:
		color = Color(color.r * road_tint.r, color.g * road_tint.g, color.b * road_tint.b, color.a)
	_batch(d, "decal").add_quad(corners, up, KIT.wear_rect(tile), color, Vector2(1.0 if wet else 0.0, 0.0))
	stats.wear += 1
	if wet:
		FX_GROUND.add_wet_spot(world, d, lateral, along, across)


func _corner_strength(d: float) -> float:
	var a: Vector3 = world.forward(d - 8.0)
	var b: Vector3 = world.forward(d + 8.0)
	var turn: float = a.cross(b).y
	return turn  # >0 Linkskurve, <0 Rechtskurve


func _low_wear() -> void:
	# LOW: nur Gummiabrieb am Start und ein paar Flicken – ein Abschnitt.
	for i in range(3):
		_road_decal("rubber", 6.0 + i * 9.0, 0.0, 9.0, _half_width(0.0) * 1.6, Color(1, 1, 1, 0.75))
	_road_decal("skid", -6.0, 1.4, 9.0, 3.2, Color(1, 1, 1, 0.8))
	for i in range(10):
		var d: float = _length() * (0.06 + i * 0.094)
		if _blocked(d, 4.0):
			continue
		_road_decal(["patch", "tar", "oil"][i % 3], d, rng.randf_range(-2.5, 2.5), 2.4, 1.6, Color(1, 1, 1, 0.8), rng.randf_range(-0.3, 0.3))


func _road_wear() -> void:
	var density: float = float(DENSITY[profile])
	var tiles: Array = theme.get("road_wear", ["patch", "oil", "tar", "crack"])
	# Gummiabrieb auf dem Startgitter + Bremsspuren vor der Ziellinie.
	for i in range(4):
		_road_decal("rubber", 6.0 + i * 9.0, 0.0, 9.0, _half_width(0.0) * 1.7, Color(1, 1, 1, 0.8))
	for k in range(3):
		_road_decal("skid", -9.0 - k * 7.0, rng.randf_range(-2.8, 2.8), 8.0, 3.0, Color(1, 1, 1, 0.75), rng.randf_range(-0.08, 0.08))
	var step: float = lerpf(26.0, 11.0, density)
	var d: float = 40.0
	while d < _length() - 20.0:
		d += step * rng.randf_range(0.7, 1.3)
		if world.ADVENTURE_TUNNELS.contains(world, d, 0.0) or world.in_gap(d) or world.ramp_height(d) > 0.0:
			continue
		var half: float = _half_width(d)
		var turn: float = _corner_strength(d)
		if absf(turn) > 0.18 and rng.randf() < 0.85:
			# Reifenspuren an der Außenseite der Kurve, schräg hineingezogen.
			var outside: float = -signf(turn)
			_road_decal("skid", d, outside * rng.randf_range(0.6, half - 1.6), rng.randf_range(7.0, 11.0), 3.0,
				Color(1, 1, 1, rng.randf_range(0.55, 0.85)), outside * rng.randf_range(0.05, 0.16))
			if rng.randf() < 0.35:
				_road_decal("rubber", d + 3.0, outside * (half - 2.0), 10.0, 2.2, Color(1, 1, 1, 0.5))
			continue
		var tile: String = tiles[rng.randi() % tiles.size()]
		match tile:
			"manhole":
				_road_decal("manhole", d, signf(rng.randf() - 0.5) * (half - 1.4), 1.0, 1.0, Color(1, 1, 1, 1), rng.randf() * TAU)
			"puddle":
				_road_decal("puddle", d, signf(rng.randf() - 0.5) * (half - 1.5), rng.randf_range(2.4, 4.0), rng.randf_range(1.6, 2.4),
					Color(1, 1, 1, 0.95), rng.randf() * TAU, true)
			"patch":
				_road_decal("patch", d, rng.randf_range(-half + 1.8, half - 1.8), rng.randf_range(2.0, 3.6), rng.randf_range(1.2, 2.2),
					Color(1, 1, 1, 0.85), rng.randf_range(-0.05, 0.05))
			"crack":
				_road_decal("crack", d, rng.randf_range(-half + 1.0, half - 1.0), 3.0, 2.0, Color(1, 1, 1, 0.75), rng.randf() * TAU)
			"oil":
				_road_decal("oil", d, rng.randf_range(-2.0, 2.0), rng.randf_range(1.3, 2.2), rng.randf_range(1.0, 1.8), Color(1, 1, 1, 0.8), rng.randf() * TAU)
			_:
				_road_decal(tile, d, rng.randf_range(-half + 1.0, half - 1.0), rng.randf_range(4.0, 7.0), 1.8,
					Color(1, 1, 1, 0.8), rng.randf_range(-0.3, 0.3))


## Laub/Sand/Schnee, das sich an der Fahrbahnkante sammelt.
func _edge_drifts() -> void:
	var tile: String = str(theme.get("edge", ""))
	if tile == "":
		return
	var color: Color = theme.get("edge_tint", Color.WHITE)
	var step: float = 18.0 if profile == "high" else 30.0
	var d: float = 12.0
	while d < _length():
		d += step * rng.randf_range(0.6, 1.4)
		if world.ADVENTURE_TUNNELS.contains(world, d, 0.0) or world.in_gap(d) or world.PASSAGES.keeps_clear(world, d, 5.0):
			continue
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var half: float = _half_width(d)
		var across: float = 1.6 if tile != "leaves" else 1.8
		var lateral: float = side * (half - across * 0.5 + 0.15)
		var length_m: float = rng.randf_range(4.0, 7.0)
		var basis: Basis = world.frame(d)
		var up: Vector3 = basis.y
		var centre: Vector3 = world.position_at(d, lateral) + up * (DECAL_LIFT_M + 0.004)
		var fwd: Vector3 = -basis.z
		var right: Vector3 = basis.x * side
		# Kachel-V läuft von innen (0) nach außen (1): dichter Rand an der Kante.
		var a: Vector3 = fwd * length_m * 0.5
		var b: Vector3 = right * across * 0.5
		var corners: Array = [centre - a - b, centre + a - b, centre + a + b, centre - a + b] if tile != "leaves" else [centre - a - b, centre - a + b, centre + a + b, centre + a - b]
		_batch(d, "decal").add_quad(corners, up, KIT.wear_rect(tile), color)
		stats.wear += 1


## Fassadenspuren: Wasserläufer, Risse, abgeplatzter Putz, Moos und Schmutz an
## den Gebäude-/Mauerkästen der Strecke, die zur Fahrbahn zeigen.
func _facades() -> void:
	var limit: int = 140 if profile == "high" else 70
	var done: int = 0
	var tiles_top: Array = theme.get("facade_top", ["streak", "crack", "grime", "plaster"])
	var tiles_bottom: Array = theme.get("facade_bottom", ["moss", "grime"])
	var skips: Dictionary = {"boxes": 0, "size": 0, "tilt": 0, "distance": 0, "dark": 0}
	for child in world.get_children():
		if done >= limit:
			break
		if not (child is MultiMeshInstance3D) or not str(child.name).begins_with("Decor_box_"):
			continue
		if str(child.name).ends_with("_light"):
			continue
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		if mm == null:
			continue
		for i in range(mm.instance_count):
			if done >= limit:
				break
			var xform: Transform3D = (child as Node3D).transform * mm.get_instance_transform(i)
			var size := Vector3(xform.basis.x.length(), xform.basis.y.length(), xform.basis.z.length())
			skips.boxes += 1
			if size.y < 2.2 or size.y > 40.0 or maxf(size.x, size.z) < 2.0:
				skips.size += 1
				continue
			if absf(xform.basis.y.normalized().dot(Vector3.UP)) < 0.9:
				skips.tilt += 1
				continue
			var nearest: Dictionary = world.sample_road(xform.origin)
			var distance: float = Vector2(xform.origin.x - nearest.position.x, xform.origin.z - nearest.position.z).length()
			if distance < float(nearest.width) * 0.5 + 1.5 or distance > 55.0:
				skips.distance += 1
				continue
			var tint: Color = mm.get_instance_color(i) if mm.use_colors else Color.WHITE
			if tint.get_luminance() < 0.12:
				skips.dark += 1
				continue
			_facade_face(xform, size, nearest, tiles_top, tiles_bottom)
			done += 1
	stats["facade_skips"] = skips


func _facade_face(xform: Transform3D, size: Vector3, nearest: Dictionary, tiles_top: Array, tiles_bottom: Array) -> void:
	var to_road: Vector3 = nearest.position - xform.origin
	to_road.y = 0.0
	# Die Kastenseite, die am stärksten zur Fahrbahn zeigt.
	var axes: Array = [xform.basis.x, -xform.basis.x, xform.basis.z, -xform.basis.z]
	var best: Vector3 = axes[0]
	var best_dot: float = -2.0
	for axis: Vector3 in axes:
		var dot: float = axis.normalized().dot(to_road.normalized())
		if dot > best_dot:
			best_dot = dot
			best = axis
	if best_dot < 0.35:
		return
	var normal: Vector3 = best.normalized()
	var face_centre: Vector3 = xform.origin + best * 0.5 + normal * 0.03
	var along: Vector3 = Vector3.UP.cross(normal).normalized()
	var width: float = size.z if absf(best.normalized().dot(xform.basis.x.normalized())) > 0.7 else size.x
	var height: float = size.y
	var bottom: Vector3 = face_centre - Vector3.UP * height * 0.5
	var d: float = float(nearest.distance)
	var batch: KIT.Batch = _batch(d, "decal_wall")
	# Schmutz-/Moosstreifen am Fuß der Wand.
	var strip_h: float = minf(1.4, height * 0.35)
	var tile_b: String = tiles_bottom[rng.randi() % tiles_bottom.size()]
	_wall_quad(batch, bottom + Vector3.UP * strip_h * 0.5, along, width * 0.96, strip_h, normal, tile_b, Color(1, 1, 1, 0.85))
	# 1–3 Spuren in der oberen Hälfte (Wasserläufer unter Fenstern, Risse, Putz).
	var count: int = 1 + int(width > 5.0) + int(profile == "high" and width > 8.0)
	for k in range(count):
		var tile: String = tiles_top[rng.randi() % tiles_top.size()]
		var w: float = minf(width * 0.4, rng.randf_range(1.4, 2.8))
		var h: float = minf(height * 0.6, w * (1.3 if tile == "streak" else 1.0))
		var x: float = rng.randf_range(-width * 0.5 + w * 0.5, width * 0.5 - w * 0.5)
		var y: float = rng.randf_range(height * 0.35, height * 0.92 - h * 0.5)
		_wall_quad(batch, bottom + along * x + Vector3.UP * y, along, w, h, normal, tile, Color(1, 1, 1, 0.8))
	stats.facade += 1


func _wall_quad(batch: KIT.Batch, centre: Vector3, along: Vector3, w: float, h: float, normal: Vector3, tile: String, color: Color) -> void:
	var a: Vector3 = along * w * 0.5
	var b: Vector3 = Vector3.UP * h * 0.5
	# Kachel-V=0 oben, V=1 unten: Ecken unten-links, unten-rechts, oben-rechts, oben-links.
	batch.add_quad([centre - a - b, centre + a - b, centre + a + b, centre - a + b], normal, KIT.wear_rect(tile), color)
	stats.wear += 1


# ---------------------------------------------------------------- Start/Ziel-Bühne

func _stage() -> void:
	var half: float = _half_width(0.0)
	# Die Startampel stellt der Startbogen jeder Strecke bereits; hier kommen
	# die Kleinigkeiten drumherum dazu.
	# Streckenname auf Bannern beidseitig der Startgeraden + Werbebanden.
	var cell: int = KIT.track_banner_cell(track_id)
	for side in [-1.0, 1.0]:
		for k in range(3 if profile != "low" else 1):
			var d: float = 14.0 + k * 22.0
			_banner_board(d, side, cell if k != 1 else int(KIT.BRAND_CELLS.lumo_kart), 6.0, "stage")
	# Zielband: schachbrettartige Wimpel über der Linie, hoch genug für alle.
	_pennant_line(world.position_at(0.0, -half - 1.2) + Vector3.UP * 6.2, world.position_at(0.0, half + 1.2) + Vector3.UP * 6.2, 0.0,
		[Color("1d1e22"), Color("f2f2ee")], 14, 0.9, "stage")
	# Tribünen mit winkendem Publikum, Kameraturm, Podest, Konfettikanonen, Boxengasse.
	var fan_kinds: Array[String] = ["fan_a", "fan_b", "fan_c", "fan_d"]
	var stands: int = 2
	for s in range(stands):
		var side: float = -1.0 if s == 0 else 1.0
		var site: Dictionary = {}
		for candidate in [-22.0, -40.0, 18.0, -60.0, 40.0, -80.0]:
			for lateral in [half + 5.5, half + 9.5]:
				if site.is_empty():
					site = _site(candidate + s * 30.0, side, lateral, 4.2, false)
		if site.is_empty():
			# Kein Platz für eine Tribüne (z. B. dichter Wald): Stehpublikum hinter einer Bande.
			for candidate in [-18.0, -32.0, 24.0, -46.0, 38.0, -60.0, 52.0]:
				if _fan_group(candidate + s * 7.0, side, s * 2, fan_kinds, "stage"):
					break
			continue
		_place("grandstand", site, "stage")
		var rows: int = 3
		var per_row: int = 6 if profile != "low" else 4
		for row in range(rows):
			for i in range(per_row):
				var x: float = -2.5 + float(i) * (5.0 / float(per_row - 1)) + rng.randf_range(-0.12, 0.12)
				var local := Vector3(x, 0.5 + row * 0.5 + 0.03 + row * 0.5, -(0.30 + row * 0.7))
				_place(fan_kinds[(i + row * 2 + s) % 4], site, "life", local, rng.randf_range(-0.2, 0.2), rng.randf_range(0.88, 1.05))
	if profile == "low":
		return
	var tower: Dictionary = _site(-12.0, -1.0, half + 5.0, 1.3, false)
	if not tower.is_empty():
		_place("camera_tower", tower, "stage")
	var podium: Dictionary = _site(-46.0, 1.0, half + 6.0, 2.4, false)
	if not podium.is_empty():
		_place("podium", podium, "stage")
		for k in range(3):
			_place(fan_kinds[k], podium, "life", Vector3(-1.3 + k * 1.3, [0.75, 1.1, 0.5][k], 0.0), 0.0, 0.95)
	for side in [-1.0, 1.0]:
		var cannon: Dictionary = _site(3.0, side, half + 1.8, 0.45, false)
		if not cannon.is_empty():
			_place("confetti_cannon", cannon, "stage", Vector3.ZERO, side * 0.25)
		var flag: Dictionary = _site(-2.0, side, half + 2.0, 0.35, false)
		if not flag.is_empty():
			_place("flag_pole", flag, "stage")
		var marshal: Dictionary = _site(26.0 if side < 0.0 else 48.0, side, half + 2.0, 0.5, false)
		if not marshal.is_empty():
			_place("marshal", marshal, "life")
	# Boxengasse: Werkzeug, Reifenregal, Kisten, Kanister.
	var pit: Array[String] = ["tire_rack", "toolbox", "crate_stack", "jerrycan", "tire_stack", "toolbox", "crate"]
	for k in range(pit.size()):
		var site: Dictionary = _site(60.0 + k * 5.5, -1.0, half + 3.2 + (k % 2) * 1.6, 0.9, false)
		if not site.is_empty():
			_place(pit[k], site, "stage", Vector3.ZERO, rng.randf_range(-0.4, 0.4))


func _beam_box(a: Vector3, b: Vector3, thickness: float, color: Color, d: float, material: String) -> void:
	var dir: Vector3 = b - a
	var z: Vector3 = dir.normalized()
	var x: Vector3 = (Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).cross(z).normalized()
	var y: Vector3 = z.cross(x)
	var basis := Basis(x * thickness, y * thickness, z * dir.length())
	var lin: Color = color.srgb_to_linear()
	_batch(d, material).add_arrays(KIT.box_arrays(), Transform3D(basis, (a + b) * 0.5), Color(lin.r, lin.g, lin.b, 1.0))


## Werbebande/Namensschild auf zwei Pfosten, schräg zur Fahrtrichtung gedreht,
## damit der Text aus der Rennkamera lesbar ist.
func _banner_board(d: float, side: float, cell: int, width: float, category: String) -> void:
	var height: float = width / 8.0
	var site: Dictionary = _site(d, side, _half_width(d) + 2.0, 0.6)
	if site.is_empty():
		return
	var basis: Basis = (site.basis as Basis).rotated(Vector3.UP, side * 0.55)
	var centre: Vector3 = site.at + Vector3.UP * (1.25 + height * 0.5)
	var right: Vector3 = basis.x
	var a: Vector3 = right * width * 0.5
	var b: Vector3 = Vector3.UP * height * 0.5
	var batch: KIT.Batch = _batch(site.d, "banner")
	batch.add_quad([centre - a - b, centre + a - b, centre + a + b, centre - a + b], basis.z, KIT.banner_rect(cell), Color.WHITE)
	for x in [-width * 0.42, width * 0.42]:
		_beam_box(site.at + right * x, site.at + right * x + Vector3.UP * (1.25 + height), 0.09, Color("39414a"), site.d, "props")
	_beam_box(centre - a - Vector3.UP * (height * 0.5 + 0.05) - basis.z * 0.04, centre + a - Vector3.UP * (height * 0.5 + 0.05) - basis.z * 0.04, 0.07, Color("39414a"), site.d, "props")
	stats[category] = int(stats.get(category, 0)) + 1
	placed.append({"kind": "banner", "distance": site.d, "lateral": site.lateral, "half_width": _half_width(site.d), "flat": false, "position": site.at})


## Wimpel-/Lichterkette zwischen zwei Punkten (leicht durchhängend).
func _pennant_line(a: Vector3, b: Vector3, d: float, colors: Array, count: int, size: float, category: String, glow: bool = false) -> void:
	var batch: KIT.Batch = _batch(d, "glow" if glow else "props")
	var sag: float = a.distance_to(b) * 0.06
	var dir: Vector3 = (b - a).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var phase: float = fposmod(a.x * 0.13, 1.0)
	for i in range(count):
		var t0: float = (float(i) + 0.1) / float(count)
		var t1: float = (float(i) + 0.9) / float(count)
		var p0: Vector3 = a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
		var p1: Vector3 = a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
		var c: Color = colors[i % colors.size()]
		var lin := Color(c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b, 1.0 if glow else 0.55)
		if glow:
			var mid: Vector3 = (p0 + p1) * 0.5 - Vector3.UP * 0.12
			var s: float = size * 0.5
			batch.add_triangle(mid + Vector3.UP * s, mid - side * s, mid + side * s, lin, Vector2(float(i % 3) / 3.0, 0))
			batch.add_triangle(mid + Vector3.UP * s, mid + side * s, mid - side * s, lin, Vector2(float(i % 3) / 3.0, 0))
			batch.add_triangle(mid - Vector3.UP * s, mid + side * s, mid - side * s, lin, Vector2(float(i % 3) / 3.0, 0))
			batch.add_triangle(mid - Vector3.UP * s, mid - side * s, mid + side * s, lin, Vector2(float(i % 3) / 3.0, 0))
		else:
			var tip: Vector3 = (p0 + p1) * 0.5 - Vector3.UP * size
			batch.add_triangle(p0, p1, tip, lin, Vector2(phase + float(i) * 0.07, 0))
			batch.add_triangle(p1, p0, tip, lin, Vector2(phase + float(i) * 0.07, 0))
	# Die Leine selbst.
	var steps: int = 8
	for k in range(steps):
		var t0: float = float(k) / steps
		var t1: float = float(k + 1) / steps
		var p0: Vector3 = a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
		var p1: Vector3 = a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
		_beam_box(p0, p1, 0.03, Color("3a3f45"), d, "props")
	stats[category] = int(stats.get(category, 0)) + 1


# ---------------------------------------------------------------- Streckenrand

func _roadside() -> void:
	var density: float = float(DENSITY[profile])
	var clusters: Array = theme.get("clusters", [])
	if clusters.is_empty():
		return
	var step: float = lerpf(60.0, 24.0, density)
	var d: float = 70.0
	var index: int = 0
	var brands: Array = theme.get("brands", ["sternenbrause"])
	while d < _length() - 40.0:
		d += step * rng.randf_range(0.75, 1.25)
		index += 1
		var side: float = -1.0 if (index + int(rng.randf() < 0.3)) % 2 == 0 else 1.0
		if index % 5 == 0:
			_banner_board(d, side, int(KIT.BRAND_CELLS.get(brands[(index / 5) % brands.size()], 13)), 5.6, "props")
			continue
		var cluster: Array = clusters[rng.randi() % clusters.size()]
		_cluster(d, side, cluster)
	# Reflektorpfosten an den Begrenzungen.
	if bool(theme.get("reflectors", true)):
		var spacing: float = 26.0 if profile == "high" else 40.0
		var r: float = 20.0
		while r < _length() - 10.0:
			r += spacing
			for side in [-1.0, 1.0]:
				var site: Dictionary = _site(r + side * 3.0, side, _half_width(r) + 1.25, 0.1)
				if not site.is_empty():
					_place("reflector_post", site, "light")


func _cluster(d: float, side: float, cluster: Array) -> void:
	var base_lat: float = _half_width(d) + 2.2 + rng.randf_range(0.0, 2.5)
	for k in range(cluster.size()):
		var entry: Array = cluster[k]
		var kind: String = entry[0]
		var along: float = float(entry[1])
		var extra: float = float(entry[2])
		var footprint: float = float(entry[3]) if entry.size() > 3 else 0.6
		var site: Dictionary = _site(d + along, side, base_lat + extra, footprint)
		if site.is_empty():
			continue
		var category: String = "life" if kind.begins_with("fan_") or kind == "marshal" else "props"
		var tint: Color = Color.WHITE
		if kind == "container":
			tint = [Color(0.18, 0.42, 0.78), Color(0.85, 0.22, 0.16), Color(0.22, 0.55, 0.3), Color(0.95, 0.66, 0.12), Color(0.9, 0.9, 0.88)][rng.randi() % 5]
		_place(kind, site, category, Vector3.ZERO, rng.randf_range(-0.35, 0.35) if kind != "container" else 0.0, 1.0, tint)
		if kind == "container":
			_container_wear(site)


## Rost und Schmutz an den Hafencontainern.
func _container_wear(site: Dictionary) -> void:
	var basis: Basis = site.basis
	var batch: KIT.Batch = _batch(site.d, "decal_wall")
	var normal: Vector3 = basis.z
	for k in range(2):
		var centre: Vector3 = site.at + normal * 1.24 + basis.x * rng.randf_range(-2.0, 2.0) + Vector3.UP * rng.randf_range(0.9, 1.7)
		_wall_quad(batch, centre, basis.x, 1.8, 1.8, normal, "rust" if k == 0 else "streak", Color(1, 1, 1, 0.9))


## Direkt hinter der Leitplanke, wo die Rennkamera wirklich hinschaut:
## Reifenstapel an Kurvenaußenseiten, Fahnen und Wimpel auf den Geraden.
func _railside() -> void:
	var density: float = float(DENSITY[profile])
	var kinds: Array = theme.get("railside", ["tire_stack", "flag_pole"])
	var d: float = 50.0
	var flag_gap: float = lerpf(90.0, 45.0, density)
	var last_flag: float = -999.0
	while d < _length() - 30.0:
		d += lerpf(16.0, 8.0, density)
		var turn: float = _corner_strength(d)
		if absf(turn) > 0.16:
			var outside: float = -signf(turn)
			var site: Dictionary = _site(d, outside, _half_width(d) + 1.4, 0.55)
			if site.is_empty():
				continue
			var kind: String = kinds[0]
			_place(kind, site, "props", Vector3.ZERO, rng.randf_range(-0.5, 0.5))
			if kind == "tire_stack":
				_place(kind, site, "props", Vector3(1.0, 0, 0.0), rng.randf_range(-0.5, 0.5))
				if rng.randf() < 0.5:
					_place(kind, site, "props", Vector3(0.5, 1.0, 0.0), rng.randf_range(-0.5, 0.5), 0.95)
		elif d - last_flag > flag_gap:
			var side: float = -1.0 if int(d / flag_gap) % 2 == 0 else 1.0
			var site: Dictionary = _site(d, side, _half_width(d) + 1.6, 0.4)
			if site.is_empty():
				continue
			last_flag = d
			_place(kinds[1] if kinds.size() > 1 else "flag_pole", site, "props", Vector3.ZERO, side * 0.4)


# ---------------------------------------------------------------- Leben

func _life() -> void:
	var fans: Array[String] = ["fan_a", "fan_b", "fan_c", "fan_d"]
	# Publikumsgruppen an markanten Stellen (Kurven-Scheitel).
	var groups: int = 6 if profile == "medium" else 12
	var found: int = 0
	# Erst Kurvenscheitel, dann – falls die Strecke dort keinen Platz hat –
	# auch Geraden, damit jede Strecke ihr Publikum bekommt.
	for pass_index in range(3):
		var d: float = 120.0 + pass_index * 41.0 - (pass_index / 2) * 70.0
		while d < _length() - 80.0 and found < groups:
			d += 23.0
			d += float(pass_index) * 3.0
			if pass_index == 0 and absf(_corner_strength(d)) < 0.22:
				continue
			if _fan_group(d, -signf(_corner_strength(d)) if absf(_corner_strength(d)) > 0.05 else (1.0 if int(d) % 2 == 0 else -1.0), found, fans):
				found += 1
				d += 60.0 if profile == "high" else 110.0
	_marshals()


func _fan_group(d: float, outside: float, found: int, fans: Array[String], barrier_category: String = "props") -> bool:
	var anchor: Dictionary = {}
	for lateral in [3.4, 2.0, 5.5]:
		if anchor.is_empty():
			anchor = _site(d, outside, _half_width(d) + lateral, 2.0)
	if anchor.is_empty():
		return false
	_place("barrier", anchor, barrier_category, Vector3(0, 0, 0.9))
	for i in range(5 if profile == "high" else 4):
		_place(fans[(i + found) % 4], anchor, "life", Vector3(-1.6 + i * 0.8, 0, -0.4 - (i % 2) * 0.5), rng.randf_range(-0.3, 0.3), rng.randf_range(0.85, 1.05))
	return true


func _marshals() -> void:
	# Streckenposten mit Flagge.
	var marshals: int = 2 if profile == "medium" else 4
	for m in range(marshals):
		var md: float = _length() * (0.2 + 0.6 * float(m) / maxf(1.0, float(marshals - 1)))
		for attempt in range(4):
			var site: Dictionary = _site(md + attempt * 9.0, 1.0 if m % 2 == 0 else -1.0, _half_width(md) + 2.4, 0.5)
			if not site.is_empty():
				_place("marshal", site, "life")
				break
	# Schwärme (Möwen, Schmetterlinge, Drohnen) und ein Luftschiff/Bahn im Hintergrund.
	var flock_kind: String = str(theme.get("flock", ""))
	if flock_kind != "":
		var flocks: int = 3 if profile == "medium" else 6
		for f in range(flocks):
			var fd: float = _length() * (0.12 + 0.24 * f)
			var side: float = -1.0 if f % 2 == 0 else 1.0
			var centre: Vector3 = world.position_at(fd, side * (_half_width(fd) + 9.0)) + Vector3.UP * float(theme.get("flock_height", 9.0))
			_flock(flock_kind, centre, float(theme.get("flock_scale", 1.0)), theme.get("flock_tint", Color.WHITE), f)
	if bool(theme.get("airship", true)):
		_airship()


func _flock(kind: String, centre: Vector3, scale: float, tint: Color, index: int) -> void:
	var arrays: Array = KIT.part(kind)
	if arrays.is_empty():
		return
	var batch := KIT.Batch.new()
	batch.add_arrays(arrays, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO), tint, float(index) * 0.37)
	var glow: Array = KIT.part(kind + "__glow")
	var node := MeshInstance3D.new()
	node.name = "Flock_%s_%d" % [kind, index]
	node.mesh = batch.commit()
	var material: ShaderMaterial = (KIT.material("flock") as ShaderMaterial).duplicate()
	material.set_shader_parameter("orbit_speed", 0.18 + 0.05 * index if kind != "drone" else 0.3)
	material.set_shader_parameter("flap", 1.0 if kind == "gull_flock" else 0.0)
	node.material_override = material
	node.position = centre
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 260.0
	# Platz für die Kreisbahn, damit Frustum-Culling den Schwarm nicht verschluckt.
	node.extra_cull_margin = 12.0 * scale
	root.add_child(node)
	if not glow.is_empty():
		var glow_batch := KIT.Batch.new()
		glow_batch.add_arrays(glow, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO))
		var light := MeshInstance3D.new()
		light.name = node.name + "_Lights"
		light.mesh = glow_batch.commit()
		var light_material: ShaderMaterial = (KIT.material("flock") as ShaderMaterial).duplicate()
		light_material.set_shader_parameter("orbit_speed", material.get_shader_parameter("orbit_speed"))
		light_material.set_shader_parameter("roughness_base", 0.2)
		light.material_override = light_material
		light.position = centre
		light.extra_cull_margin = node.extra_cull_margin
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(light)
	stats.life += 1


## Luftschiff der Fantasie-Reederei "Wolkenwerk", das langsam um die Strecke zieht.
func _airship() -> void:
	var batch := KIT.Batch.new()
	var body := SphereMesh.new()
	body.radial_segments = 16
	body.rings = 8
	var arrays: Array = body.get_mesh_arrays()
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colors := PackedColorArray()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var accent: Color = theme.get("airship_color", Color("ff8a3d"))
	for i in range(count):
		var stripe: bool = absf(vertices[i].y) < 0.12
		var c: Color = (accent if stripe else Color("f4f0e8")).srgb_to_linear()
		colors.append(Color(c.r, c.g, c.b, 0.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	var radius: float = maxf(140.0, _length() / TAU * 0.9)
	var hull := Transform3D(Basis.IDENTITY.scaled(Vector3(4.0, 4.0, 13.0)), Vector3(radius, 0, 0))
	batch.add_arrays(arrays, hull)
	var box := BoxMesh.new()
	var box_arrays: Array = box.get_mesh_arrays()
	var box_colors := PackedColorArray()
	box_colors.resize((box_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var dark: Color = Color("3a3f45").srgb_to_linear()
	box_colors.fill(Color(dark.r, dark.g, dark.b, 0.0))
	box_arrays[Mesh.ARRAY_COLOR] = box_colors
	batch.add_arrays(box_arrays, Transform3D(Basis.IDENTITY.scaled(Vector3(1.6, 1.3, 4.0)), Vector3(radius, -4.6, 0.5)))
	for fin in [Vector3(0, 3.2, -11.0), Vector3(0, -3.2, -11.0)]:
		batch.add_arrays(box_arrays, Transform3D(Basis.IDENTITY.scaled(Vector3(0.3, 3.0, 3.0)), Vector3(radius, 0, 0) + fin))
	batch.add_arrays(box_arrays, Transform3D(Basis.IDENTITY.scaled(Vector3(6.0, 0.3, 3.0)), Vector3(radius, 0, -11.0)))
	var node := MeshInstance3D.new()
	node.name = "Airship"
	node.mesh = batch.commit()
	var material: ShaderMaterial = (KIT.material("flock") as ShaderMaterial).duplicate()
	material.set_shader_parameter("orbit_speed", 0.025)
	material.set_shader_parameter("flap", 0.0)
	node.material_override = material
	var centre := Vector3.ZERO
	for i in range(8):
		centre += world.position_at(_length() * float(i) / 8.0)
	centre /= 8.0
	node.position = centre + Vector3.UP * float(theme.get("airship_height", 48.0))
	node.extra_cull_margin = radius + 20.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	stats.life += 1


# ---------------------------------------------------------------- Licht

func _lights() -> void:
	var lantern: String = str(theme.get("lantern", ""))
	var spacing: float = 34.0 if profile == "high" else 55.0
	if lantern != "":
		var d: float = 30.0
		var side: float = 1.0
		while d < _length() - 20.0:
			d += spacing * rng.randf_range(0.8, 1.2)
			side = -side
			var site: Dictionary = _site(d, side, _half_width(d) + 1.9, 0.3)
			if not site.is_empty():
				_place(lantern, site, "light")
	# Lichterketten zwischen Pfosten entlang der Strecke.
	var strings: int = 3 if profile == "medium" else 7
	var colors: Array = theme.get("string_colors", [Color("ffd98a"), Color("ff9d5c"), Color("9fe6ff")])
	var made: int = 0
	var d2: float = _length() * 0.15
	while made < strings and d2 < _length() * 0.95:
		d2 += _length() * 0.09
		var side: float = -1.0 if made % 2 == 0 else 1.0
		var a: Dictionary = _site(d2, side, _half_width(d2) + 2.4, 0.2)
		var b: Dictionary = _site(d2 + 16.0, side, _half_width(d2 + 16.0) + 2.4, 0.2)
		if a.is_empty() or b.is_empty():
			continue
		_put("lamp_post_small", Transform3D(Basis.IDENTITY, a.at), a.d, "light")
		_put("lamp_post_small", Transform3D(Basis.IDENTITY, b.at), b.d, "light")
		_pennant_line(a.at + Vector3.UP * 2.45, b.at + Vector3.UP * 2.45, a.d, colors, 12, 0.22, "light", true)
		_pennant_line(a.at + Vector3.UP * 2.3, b.at + Vector3.UP * 2.3, a.d, theme.get("pennant_colors", [Color("ff6f91"), Color("ffd23f"), Color("3fb7e8"), Color("7ed957")]), 10, 0.55, "props")
		made += 1


# ---------------------------------------------------------------- Ausgabe

func _commit() -> void:
	var materials: Dictionary = {}
	var keys: Array = batches.keys()
	keys.sort()
	for key: String in keys:
		var batch: KIT.Batch = batches[key]
		if batch.is_empty():
			continue
		var kind: String = key.get_slice(":", 1)
		var node := MeshInstance3D.new()
		node.name = "Detail_" + key.replace(":", "_")
		var centre: Vector3 = batch.centre()
		node.mesh = batch.commit(centre)
		node.position = centre
		node.material_override = KIT.material(kind)
		var casts: bool = kind == "props" and profile == "high"
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if profile != "low":
			node.visibility_range_end = 240.0 if kind != "decal" and kind != "decal_wall" else 150.0
			node.visibility_range_end_margin = 20.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		node.set_meta("triangles", batch.triangles)
		root.add_child(node)
		materials[kind] = int(materials.get(kind, 0)) + batch.triangles
	stats["triangles"] = materials
	if theme.has("sky_tint"):
		var decal: ShaderMaterial = KIT.material("decal")
		decal.set_shader_parameter("sky_tint", theme.sky_tint)
