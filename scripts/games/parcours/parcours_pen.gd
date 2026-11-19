extends RefCounted
## Bau-Stift für Parcours-Welten: legt Fahrbahnstücke lückenlos hintereinander.
## Jedes Stück beginnt genau dort, wo das vorige endet (Lage, Höhe, Richtung), daher
## gibt es keine Fugen. Richtung wie im Kart: heading 0 fährt nach -Z, links = +heading.

var course
var pos: Vector3 = Vector3.ZERO
var heading: float = 0.0
var width: float = 9.0
## Laufende Weglänge (für Bot-Route und Checkpoint-Abstände).
var travelled: float = 0.0
## Stil des nächsten Stücks (Material im Builder): deck, bridge, ice, glass, stone, wood …
var style: String = "deck"
var level: int = 0


func _init(target, start: Vector3, start_heading: float, start_width: float = 9.0) -> void:
	course = target
	pos = start
	heading = start_heading
	width = start_width


static func forward_of(h: float) -> Vector3:
	return Vector3(-sin(h), 0.0, -cos(h))


static func right_of(h: float) -> Vector3:
	return Vector3(cos(h), 0.0, -sin(h))


func forward() -> Vector3:
	return forward_of(heading)


func right() -> Vector3:
	return right_of(heading)


## Gerades Stück mit Steigung `rise` (Meter über die Länge). Rails: Geländer links/rechts.
func straight(
	length: float,
	rise: float = 0.0,
	rail_left: bool = true,
	rail_right: bool = true,
	extra: Dictionary = {}
) -> int:
	var slab := {
		"kind": "box",
		"base": Transform3D(Basis(Vector3.UP, heading), pos),
		"length": length,
		"width": float(extra.get("width", width)),
		"rise": rise,
		"rail_left": rail_left,
		"rail_right": rail_right,
		"style": style,
		"level": level,
		"route_from": travelled
	}
	slab.merge(extra, true)
	course.slabs.append(slab)
	var index: int = course.slabs.size() - 1
	_route_point(pos, extra)
	pos += forward() * length + Vector3.UP * rise
	travelled += Vector2(length, rise).length()
	return index


## Bogen um `degrees` (positiv = links). Mit `rise` wird er zur Spiralrampe.
func turn(
	radius: float,
	degrees: float,
	rise: float = 0.0,
	rail_inner: bool = true,
	rail_outer: bool = true,
	extra: Dictionary = {}
) -> int:
	var angle: float = deg_to_rad(absf(degrees))
	var left: bool = degrees > 0.0
	var centre: Vector3 = pos - right() * radius if left else pos + right() * radius
	var from_centre: Vector3 = pos - centre
	var a0: float = atan2(from_centre.z, from_centre.x)
	var a1: float = a0 - angle if left else a0 + angle
	var slab := {
		"kind": "arc",
		"base": Transform3D(Basis.IDENTITY, Vector3(centre.x, 0.0, centre.z)),
		"radius": radius,
		"width": float(extra.get("width", width)),
		"a0": a0,
		"a1": a1,
		"y0": pos.y,
		"y1": pos.y + rise,
		"style": style,
		"level": level,
		# Rechts in Fahrtrichtung liegt bei a1 > a0 außen.
		"rail_left": rail_inner if left else rail_outer,
		"rail_right": rail_outer if left else rail_inner,
		"route_from": travelled
	}
	slab.merge(extra, true)
	course.slabs.append(slab)
	var index: int = course.slabs.size() - 1
	var steps: int = maxi(2, ceili(rad_to_deg(angle) / 30.0))
	for i in range(steps):
		var u: float = float(i) / steps
		var a: float = lerpf(a0, a1, u)
		_route_point(
			Vector3(centre.x + cos(a) * radius, pos.y + rise * u, centre.z + sin(a) * radius), extra
		)
	pos = Vector3(centre.x + cos(a1) * radius, pos.y + rise, centre.z + sin(a1) * radius)
	heading += angle if left else -angle
	travelled += Vector2(radius * angle, rise).length()
	return index


## Auf einen Punkt zudrehen (Bogen mit `radius`) und bis `stop_short` davor fahren.
func aim_at(
	target: Vector3, radius: float, stop_short: float, rise: float = 0.0, rails: bool = true,
	extra: Dictionary = {}
) -> void:
	for attempt in range(2):
		var to: Vector3 = target - pos
		var wanted: float = atan2(-to.x, -to.z)
		var delta: float = rad_to_deg(angle_difference(heading, wanted))
		if absf(delta) > 0.5:
			turn(radius, delta, 0.0, rails, rails, extra)
	var rest: Vector3 = target - pos
	var length: float = Vector2(rest.x, rest.z).length() - stop_short
	if length > 0.5:
		straight(length, rise, rails, rails, extra)


## Drehscheibe direkt voraus (rund, ohne Geländer); der Stift steht danach dahinter.
func spin_disc(radius: float, speed: float, posts: int = 0, extra: Dictionary = {}) -> int:
	var centre: Vector3 = pos + forward() * radius
	var spin := {"type": "spin", "pivot": Vector3(centre.x, 0.0, centre.z), "speed": speed}
	var slab := {
		"kind": "arc", "base": Transform3D(Basis.IDENTITY, Vector3(centre.x, 0.0, centre.z)),
		"radius": radius * 0.5, "width": radius, "a0": 0.0, "a1": TAU, "y0": centre.y,
		"y1": centre.y, "rail_left": false, "rail_right": false, "style": "disc",
		"level": level, "no_assist": true, "cap": 12.0, "motion": spin
	}
	slab.merge(extra, true)
	course.slabs.append(slab)
	for k in range(posts):
		var a: float = TAU * k / posts + 0.6
		course.blockers.append({
			"shape": "cylinder",
			"base": Transform3D(Basis.IDENTITY, centre + Vector3(cos(a), 0.0, sin(a)) * radius * 0.6),
			"size": Vector3(0.7, 2.6, 0.7), "motion": spin, "style": "gear_post",
			"color": Color(course.theme.get("post", Color("ffb13b")))
		})
	course.route.append({"pos": centre + Vector3.UP * 0.3, "cap": 10.0})
	pos += forward() * radius * 2.0
	travelled += radius * 2.0
	return course.slabs.size() - 1


## Lücke für einen Sprung: der Stift springt weiter, ohne Boden zu legen.
func gap(length: float, drop: float = 0.0) -> void:
	pos += forward() * length - Vector3.UP * drop
	travelled += length


## Seitlich versetzen (für parallele Wege, z. B. Geheimweg).
func shift(right_metres: float, up_metres: float = 0.0) -> void:
	pos += right() * right_metres + Vector3.UP * up_metres


func checkpoint(checkpoint_id: String, radius: float = 7.0) -> void:
	course.checkpoints.append(
		{
			"id": checkpoint_id,
			"pos": pos + Vector3.UP * 0.4,
			"heading": heading,
			"radius": radius,
			"route_at": travelled
		}
	)


func star(
	lateral: float = 0.0, ahead: float = 0.0, height: float = 1.1, secret: bool = false
) -> void:
	var p: Vector3 = pos + right() * lateral + forward() * ahead + Vector3.UP * height
	course.stars.append({"pos": p, "secret": secret, "id": "s%d" % course.stars.size()})


## Sternreihe über die nächsten `length` Meter (vor dem Legen des Stücks aufrufen).
func star_line(count: int, length: float, lateral: float = 0.0, secret: bool = false) -> void:
	for i in range(count):
		star(lateral, length * (float(i) + 0.5) / count, 1.1, secret)


func skill(
	skill_id: String, name: String, intro: String, retry: String, radius: float = 9.0
) -> void:
	course.skills.append(
		{
			"id": skill_id,
			"name": name,
			"intro": intro,
			"retry": retry,
			"pos": pos + Vector3.UP * 0.5,
			"radius": radius,
			"heading": heading
		}
	)


func _route_point(p: Vector3, extra: Dictionary) -> void:
	var point := {"pos": p + Vector3.UP * 0.3, "cap": float(extra.get("cap", 0.0))}
	if extra.has("wait"):
		point["wait"] = extra.wait
	course.route.append(point)


## Wegpunkt mit Warteregel für den Bot (z. B. auf den Aufzug warten).
func wait_point(rule: Dictionary, cap: float = 0.0) -> void:
	var point := {"pos": pos + Vector3.UP * 0.3, "cap": cap, "wait": rule}
	course.route.append(point)


func end_route() -> void:
	course.route.append({"pos": pos + Vector3.UP * 0.3, "cap": 0.0})


## Geheimer Steg über einem breiten Deck: Rampe hinauf, schmaler Steg mit Geheimsternen,
## Rampe hinunter. Wer herunterfällt, landet weich auf dem Deck darunter (kein Sturz).
static func secret_ramp(
	course, start: Vector3, facing: float, lateral: float, height: float, secret_id: String,
	secret_name: String, style_id: String = "secret"
) -> void:
	var pen = new(course, start, facing, 3.6)
	var keep: int = course.route.size()
	pen.shift(lateral)
	pen.straight(6.0, 0.0, false, false, {"style": "none"})
	pen.style = style_id
	var first: int = pen.straight(14.0, height, false, false, {"solid": true, "secret_path": true})
	course.secrets.append({
		"id": secret_id, "name": secret_name, "pos": pen.pos + Vector3.UP * 0.6, "radius": 3.5
	})
	pen.star_line(4, 26.0, 0.0, true)
	pen.straight(26.0, 0.0, false, false, {"secret_path": true})
	var last: int = pen.straight(14.0, -height, false, false, {"solid": true, "secret_path": true})
	course.slabs[first]["solid"] = true
	course.slabs[last]["solid"] = true
	# Eigene Route für den Geheimweg; die Hauptroute des Bots bleibt unverändert.
	course.secret_routes.append(course.route.slice(keep))
	course.route.resize(keep)
