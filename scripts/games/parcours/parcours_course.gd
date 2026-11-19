extends RefCounted
## LUMO Abenteuer-Parcours: Kursdaten und Bodenmodell einer Welt.
##
## Eine Welt besteht aus befahrbaren Platten („slabs“): gerade Stücke mit Steigung
## und Bogenstücke (auch Spiralrampen über mehrere Umdrehungen). Bewegliche Platten
## (Aufzug, Schiebeplattform, Drehscheibe) hängen an einer festen Kurszeit, damit jeder
## Lauf und jeder Test dieselbe Phase sieht. Das Kart fragt hier nach Boden, Geländer
## und Hindernissen – genau wie die Rennstrecken ihren Boden analytisch aus dem
## Streckenband lesen (kart_world.gd). Dieselben Daten bauen die sichtbare Geometrie
## (parcours_builder.gd), es gibt also keine unsichtbaren Böden und keine Attrappen.

## Halbe Breite des Karts für Geländer und Hindernisse.
const KART_RADIUS: float = 0.9
## So hoch darf eine Kante sein, die das Kart hinauffährt (Übergang zwischen Platten).
const STEP_UP: float = 0.7
## So weit darf die Kartmitte über eine offene Kante hinaus, bevor es kippt.
const SUPPORT_MARGIN: float = 0.2
## Überlappung an Plattenenden, damit Übergänge nie eine Lücke haben.
const END_MARGIN: float = 0.35

var id: String = ""
var title: String = ""
var tagline: String = ""
## Farben, Licht und Himmel der Welt (parcours_builder.gd liest sie).
var theme: Dictionary = {}
var kill_y: float = -40.0
var slabs: Array[Dictionary] = []
var blockers: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var stars: Array[Dictionary] = []
var secrets: Array[Dictionary] = []
## Ausstiegsstellen für die kurzen Fußabschnitte.
var stations: Array[Dictionary] = []
## Geschicklichkeitsstellen: Ankündigung (Satz von Lumo), Stelle, Hilfe nach Fehler.
var skills: Array[Dictionary] = []
## Druckplatten: das Kart fährt darüber und schaltet einen Mechanismus (Tor, Brücke).
var plates: Array[Dictionary] = []
## Umschaltbare Mechanismen (Brücke, Tor, Aufzug): Name -> Anfangszustand.
var mechanisms: Dictionary = {}
## Fahrlinie für den Prüf-Bot (und für die Kamera-Vorschau), mit Warteregeln.
var route: Array[Dictionary] = []
## Wegpunkte des Fußabschnitts für den Bot, je Station.
var foot_routes: Dictionary = {}
## Fahrlinien über die Geheimwege (für den Geheimweg-Test).
var secret_routes: Array = []
var start: Dictionary = {}
var finish: Dictionary = {}
## Deko-Inseln, Wolken, Bäume … (nur Optik, kein Boden).
var scenery: Array[Dictionary] = []
## Mindest- und Höchstzeit eines Kindes in Sekunden (für Tests und Lumos Ansage).
var target_seconds: Vector2 = Vector2(120, 240)
## Höchstgeschwindigkeit im Parcours relativ zum Renntempo (wie die Arena 0,68).
var pace: float = 0.42


func slab_count() -> int:
	return slabs.size()


## Weltlage einer Platte zur Kurszeit `t` (Ruhelage mal Bewegung).
func slab_transform(index: int, t: float, state: Dictionary = {}) -> Transform3D:
	var slab: Dictionary = slabs[index]
	return motion_transform(slab.get("motion", {}), t, state) * (slab.base as Transform3D)


## Bewegung als Transform. Nur Verschieben und Drehen um die Hochachse: Böden kippen nie.
static func motion_transform(motion: Dictionary, t: float, state: Dictionary = {}) -> Transform3D:
	if motion.is_empty():
		return Transform3D.IDENTITY
	var gate: String = str(motion.get("enabled_by", ""))
	if not gate.is_empty() and not bool(state.get(gate, false)):
		return motion_rest(motion)
	match str(motion.type):
		"slide":
			var amount: float = sin(TAU * (t / float(motion.period)) + float(motion.phase))
			return Transform3D(
				Basis.IDENTITY, (motion.axis as Vector3) * float(motion.amp) * amount
			)
		"lift":
			return Transform3D(Basis.IDENTITY, Vector3.UP * lift_offset(motion, t))
		"spin":
			var pivot: Vector3 = motion.pivot
			var angle: float = float(motion.speed) * t + float(motion.get("phase", 0.0))
			var turn := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
			return Transform3D(Basis.IDENTITY, pivot) * turn * Transform3D(Basis.IDENTITY, -pivot)
		"lift_trigger":
			return Transform3D(Basis.IDENTITY, Vector3.UP * trigger_lift_offset(motion, t, state))
		"extend":
			# Ausfahrbare Brücke: eingefahren, bis ihr Mechanismus umgeschaltet ist.
			var on: bool = bool(state.get(str(motion.mechanism), false))
			var since: float = float(state.get(str(motion.mechanism) + "_at", -100.0))
			var k: float = clampf((t - since) / float(motion.get("seconds", 1.6)), 0.0, 1.0)
			if not on:
				k = 0.0
			k = k * k * (3.0 - 2.0 * k)
			return Transform3D(Basis.IDENTITY, (motion.retract as Vector3) * (1.0 - k))
	return Transform3D.IDENTITY


static func motion_rest(motion: Dictionary) -> Transform3D:
	if str(motion.get("type", "")) == "extend":
		return Transform3D(Basis.IDENTITY, motion.retract as Vector3)
	return Transform3D.IDENTITY


## Aufzug: unten warten, hochfahren, oben warten, runterfahren (sanft, fest getaktet).
static func lift_offset(motion: Dictionary, t: float) -> float:
	var period: float = float(motion.period)
	var dwell: float = float(motion.dwell)
	var travel: float = (period - 2.0 * dwell) * 0.5
	var u: float = fposmod(t + float(motion.get("phase", 0.0)), period)
	var height: float = float(motion.height)
	if u < dwell:
		return 0.0
	u -= dwell
	if u < travel:
		var k: float = u / travel
		return height * k * k * (3.0 - 2.0 * k)
	u -= travel
	if u < dwell:
		return height
	u -= dwell
	var back: float = u / travel
	return height * (1.0 - back * back * (3.0 - 2.0 * back))


## Aufzug, der losfährt, sobald das Kart darauf steht (siehe update_mechanics).
static func trigger_lift_offset(motion: Dictionary, t: float, state: Dictionary) -> float:
	var lift: String = str(motion.id)
	var travel: float = float(motion.get("travel", 3.2))
	var up_at: float = float(state.get(lift + "_up_at", -1.0))
	var down_at: float = float(state.get(lift + "_down_at", -1.0))
	if up_at < 0.0:
		return 0.0
	var k: float = clampf((t - up_at) / travel, 0.0, 1.0)
	if down_at >= up_at:
		k = 1.0 - clampf((t - down_at) / travel, 0.0, 1.0)
	return float(motion.height) * k * k * (3.0 - 2.0 * k)


## Mechanik-Zustände für Aufzüge: `<id>_ready` (unten frei), `<id>_top` (oben angekommen).
## `on_slab` ist die Platte unter dem Kart (-1 in der Luft), `along` 0..1 darauf.
func update_mechanics(state: Dictionary, t: float, on_slab: int, along: float) -> void:
	for index in range(slabs.size()):
		var motion: Dictionary = slabs[index].get("motion", {})
		if str(motion.get("type", "")) != "lift_trigger":
			continue
		var lift: String = str(motion.id)
		var travel: float = float(motion.get("travel", 3.2))
		var up_at: float = float(state.get(lift + "_up_at", -1.0))
		var down_at: float = float(state.get(lift + "_down_at", -1.0))
		var aboard: bool = on_slab == index and along >= 0.3
		var at_bottom: bool = up_at < 0.0 or (down_at >= up_at and t - down_at >= travel)
		if at_bottom:
			state[lift + "_up_at"] = -1.0
			state[lift + "_down_at"] = -1.0
			state[lift + "_top"] = false
			var wait: float = float(state.get(lift + "_aboard", 0.0))
			wait = wait + (1.0 / 60.0) if aboard else 0.0
			state[lift + "_aboard"] = wait
			state[lift + "_ready"] = true
			if wait >= 0.45:
				state[lift + "_up_at"] = t
				state[lift + "_ready"] = false
			continue
		state[lift + "_ready"] = false
		var arrived: bool = down_at < up_at and t - up_at >= travel
		state[lift + "_top"] = arrived
		if arrived and not aboard:
			var away: float = float(state.get(lift + "_away", 0.0)) + 1.0 / 60.0
			state[lift + "_away"] = away
			if away >= 1.5:
				state[lift + "_down_at"] = t
				state[lift + "_top"] = false
				state[lift + "_away"] = 0.0
		else:
			state[lift + "_away"] = 0.0


## 0 unten, 1 oben – für Ampeln an Aufzügen und für den Bot.
static func lift_phase(motion: Dictionary, t: float) -> String:
	var period: float = float(motion.period)
	var dwell: float = float(motion.dwell)
	var travel: float = (period - 2.0 * dwell) * 0.5
	var u: float = fposmod(t + float(motion.get("phase", 0.0)), period)
	if u < dwell:
		return "bottom"
	if u < dwell + travel:
		return "up"
	if u < dwell * 2.0 + travel:
		return "top"
	return "down"


## Sekunden, bis der Aufzug wieder unten ankommt bzw. unten noch steht.
static func lift_bottom_left(motion: Dictionary, t: float) -> float:
	var period: float = float(motion.period)
	var u: float = fposmod(t + float(motion.get("phase", 0.0)), period)
	return float(motion.dwell) - u if u < float(motion.dwell) else -1.0


## Boden unter `p` zur Kurszeit `t`. Liefert die höchste Fläche, die das Kart von hier
## aus erreicht (höchstens STEP_UP über p). Leer = kein Boden (Sturz).
func ground(
	p: Vector3, t: float, state: Dictionary = {}, margin: float = SUPPORT_MARGIN
) -> Dictionary:
	var best: Dictionary = {}
	var best_height: float = -INF
	for index in range(slabs.size()):
		var slab: Dictionary = slabs[index]
		if not _near_bounds(slab, p):
			continue
		var hit: Dictionary = _slab_ground(index, p, t, state, margin)
		if hit.is_empty():
			continue
		var height: float = float(hit.height)
		if height <= p.y + STEP_UP and height > best_height:
			best_height = height
			best = hit
	return best


func _near_bounds(slab: Dictionary, p: Vector3) -> bool:
	var reach: Vector3 = slab.reach_center
	var radius: float = float(slab.reach_radius)
	return Vector2(p.x - reach.x, p.z - reach.z).length_squared() <= radius * radius


func _slab_ground(index: int, p: Vector3, t: float, state: Dictionary, margin: float) -> Dictionary:
	var slab: Dictionary = slabs[index]
	var xform: Transform3D = slab_transform(index, t, state)
	var local: Vector3 = xform.affine_inverse() * p
	var width: float = float(slab.width)
	if str(slab.kind) == "box":
		var length: float = float(slab.length)
		if absf(local.x) > width * 0.5 + margin:
			return {}
		if local.z > END_MARGIN or local.z < -length - END_MARGIN:
			return {}
		var along: float = clampf(-local.z / length, 0.0, 1.0)
		var rise: float = float(slab.rise)
		var surface := Vector3(local.x, rise * along, local.z)
		var normal_local := Vector3(0.0, 1.0, rise / length).normalized()
		return {
			"slab": index,
			"height": (xform * surface).y,
			"normal": (xform.basis * normal_local).normalized(),
			"lateral": local.x,
			"along": along,
			"width": width,
			"forward": (xform.basis * Vector3.FORWARD).normalized()
		}
	# Bogen bzw. Spirale um den Ursprung der Platte.
	var radial: float = Vector2(local.x, local.z).length()
	var radius: float = float(slab.radius)
	if absf(radial - radius) > width * 0.5 + margin:
		return {}
	var a0: float = float(slab.a0)
	var a1: float = float(slab.a1)
	var span: float = a1 - a0
	var angle: float = atan2(local.z, local.x)
	var tolerance: float = END_MARGIN / maxf(radius * absf(span), 0.01)
	var chosen: float = -1.0
	var chosen_height: float = -INF
	var lo: float = minf(a0, a1)
	var hi: float = maxf(a0, a1)
	var k_min: int = floori((lo - angle) / TAU) - 1
	var k_max: int = ceili((hi - angle) / TAU) + 1
	for k in range(k_min, k_max + 1):
		var candidate: float = angle + TAU * k
		var u: float = (candidate - a0) / span
		if u < -tolerance or u > 1.0 + tolerance:
			continue
		u = clampf(u, 0.0, 1.0)
		var h: float = lerpf(float(slab.y0), float(slab.y1), u) + xform.origin.y
		if h <= p.y + STEP_UP and h > chosen_height:
			chosen_height = h
			chosen = u
	if chosen < 0.0:
		return {}
	var a: float = lerpf(a0, a1, chosen)
	var tangent := Vector3(-sin(a), 0.0, cos(a)) * signf(span)
	var length_total: float = radius * absf(span)
	var slope: float = (float(slab.y1) - float(slab.y0)) / maxf(length_total, 0.01)
	var normal_local := (Vector3.UP - tangent * slope).normalized()
	# Seitenlage: positiv = rechts in Fahrtrichtung.
	var outward: float = radial - radius
	var right_is_outer: bool = span > 0.0
	return {
		"slab": index,
		"height": chosen_height,
		"normal": (xform.basis * normal_local).normalized(),
		"lateral": outward if right_is_outer else -outward,
		"along": chosen,
		"width": width,
		"forward": (xform.basis * (tangent + Vector3.UP * slope)).normalized()
	}


## Hält das Kart an den Geländern seiner Platte. Liefert {pushed, normal, into} oder leer.
func rail_contact(hit: Dictionary, p: Vector3, t: float, state: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var index: int = int(hit.slab)
	var slab: Dictionary = slabs[index]
	var lateral: float = float(hit.lateral)
	var limit: float = float(slab.width) * 0.5 - KART_RADIUS
	var side: float = signf(lateral)
	if absf(lateral) <= limit:
		return {}
	var railed: bool = bool(slab.rail_right) if side > 0.0 else bool(slab.rail_left)
	if not railed:
		return {}
	var xform: Transform3D = slab_transform(index, t, state)
	var right: Vector3
	if str(slab.kind) == "box":
		right = (xform.basis * Vector3.RIGHT).normalized()
	else:
		var local: Vector3 = xform.affine_inverse() * p
		var radial := Vector3(local.x, 0.0, local.z).normalized()
		right = (xform.basis * radial).normalized()
		if float(slab.a1) < float(slab.a0):
			right = -right
	var correction: float = absf(lateral) - limit
	return {"push": -right * side * correction, "normal": -right * side}


## Hindernisse und Tore: Kreis (Kart) gegen gedrehten Quader oder Zylinder.
## Liefert die stärkste Berührung {push, normal, blocker} oder leer.
func blocker_contact(
	p: Vector3, t: float, state: Dictionary, radius: float = KART_RADIUS
) -> Dictionary:
	var best: Dictionary = {}
	var best_depth: float = 0.0
	for index in range(blockers.size()):
		var blocker: Dictionary = blockers[index]
		if not blocker_active(index, state):
			continue
		var xform: Transform3D = blocker_transform(index, t, state)
		var local: Vector3 = xform.affine_inverse() * p
		var size: Vector3 = blocker.size
		if local.y < -1.2 or local.y > size.y + 0.4:
			continue
		var push_local := Vector3.ZERO
		var depth: float = 0.0
		if str(blocker.shape) == "cylinder":
			var flat := Vector2(local.x, local.z)
			var reach: float = size.x + radius
			if flat.length() >= reach:
				continue
			depth = reach - flat.length()
			var away: Vector2 = flat.normalized() if flat.length() > 0.001 else Vector2(0, 1)
			push_local = Vector3(away.x, 0.0, away.y) * depth
		else:
			var half := Vector2(size.x * 0.5, size.z * 0.5)
			var closest := Vector2(
				clampf(local.x, -half.x, half.x), clampf(local.z, -half.y, half.y)
			)
			var offset := Vector2(local.x, local.z) - closest
			if offset.length() >= radius:
				continue
			if offset.length() > 0.0001:
				depth = radius - offset.length()
				var n: Vector2 = offset.normalized()
				push_local = Vector3(n.x, 0.0, n.y) * depth
			else:
				# Mitte im Quader: kürzester Weg hinaus.
				var dx: float = half.x - absf(local.x) + radius
				var dz: float = half.y - absf(local.z) + radius
				if dx < dz:
					depth = dx
					push_local = Vector3(signf(local.x) if local.x != 0.0 else 1.0, 0, 0) * dx
				else:
					depth = dz
					push_local = Vector3(0, 0, signf(local.z) if local.z != 0.0 else 1.0) * dz
		if depth > best_depth:
			best_depth = depth
			var push: Vector3 = xform.basis * push_local
			push.y = 0.0
			best = {"push": push, "normal": push.normalized(), "blocker": index}
	return best


func blocker_active(index: int, state: Dictionary) -> bool:
	var blocker: Dictionary = blockers[index]
	var needs: String = str(blocker.get("closed_unless", ""))
	if not needs.is_empty():
		return not bool(state.get(needs, false))
	return true


## Ein Hubtor (Gleitbewegung nach oben) ist offen, wenn es hoch genug steht.
func timed_gate_open(index: int, t: float) -> bool:
	var lift: Vector3 = blocker_transform(index, t).origin - (blockers[index].base as Transform3D).origin
	return lift.y > float(blockers[index].get("open_above", 1.9))


func blocker_transform(index: int, t: float, state: Dictionary = {}) -> Transform3D:
	var blocker: Dictionary = blockers[index]
	return motion_transform(blocker.get("motion", {}), t, state) * (blocker.base as Transform3D)


## Erster Checkpoint, dessen Kugel `p` berührt (Reihenfolge egal; Index zurück, -1 sonst).
func checkpoint_at(p: Vector3) -> int:
	for index in range(checkpoints.size()):
		var c: Dictionary = checkpoints[index]
		if p.distance_to(c.pos as Vector3) <= float(c.radius):
			return index
	return -1


func checkpoint_index_of(checkpoint_id: String) -> int:
	for index in range(checkpoints.size()):
		if str(checkpoints[index].id) == checkpoint_id:
			return index
	return -1


func skill_at(p: Vector3) -> int:
	for index in range(skills.size()):
		var s: Dictionary = skills[index]
		if p.distance_to(s.pos as Vector3) <= float(s.radius):
			return index
	return -1


func station_at(p: Vector3) -> int:
	for index in range(stations.size()):
		var s: Dictionary = stations[index]
		if p.distance_to(s.kart_pos as Vector3) <= float(s.radius):
			return index
	return -1


## Abschluss nach dem Bau: Reichweiten je Platte für die schnelle Vorauswahl und
## Seitenwände unter festen Rampen (man fährt nicht unter einer Rampe hindurch).
func finalize() -> void:
	for slab in slabs.duplicate():
		if not bool(slab.get("solid", false)) or str(slab.kind) != "box":
			continue
		var rise: float = float(slab.rise)
		var length: float = float(slab.length)
		var low: float = minf(0.0, rise)
		for side in [-1.0, 1.0]:
			var offset := Vector3(side * (float(slab.width) * 0.5 + 0.15), low, -length * 0.5)
			blockers.append(
				{
					"shape": "box",
					"base": (slab.base as Transform3D) * Transform3D(Basis.IDENTITY, offset),
					"size": Vector3(0.3, absf(rise) - 0.2, length),
					"style": "ramp_wall"
				}
			)
	for index in range(slabs.size()):
		var slab: Dictionary = slabs[index]
		var base: Transform3D = slab.base
		var reach_center: Vector3
		var reach_radius: float
		if str(slab.kind) == "box":
			reach_center = base * Vector3(0, 0, -float(slab.length) * 0.5)
			reach_radius = Vector2(float(slab.width), float(slab.length)).length() * 0.5 + 2.0
		else:
			reach_center = base.origin
			reach_radius = float(slab.radius) + float(slab.width) * 0.5 + 2.0
		var motion: Dictionary = slab.get("motion", {})
		match str(motion.get("type", "")):
			"slide":
				reach_radius += float(motion.amp)
			"spin":
				var pivot: Vector3 = motion.pivot
				reach_radius += Vector2(reach_center.x - pivot.x, reach_center.z - pivot.z).length()
				reach_center = pivot
			"extend":
				reach_radius += (motion.retract as Vector3).length()
		slab["reach_center"] = reach_center
		slab["reach_radius"] = reach_radius
