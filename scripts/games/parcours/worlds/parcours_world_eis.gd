extends RefCounted
## Welt B – Eis-Turm. Ein hoher Kristallturm über einem eisigen See: Spiralrampe mit
## wandernden Eisblöcken, durchsichtige Eisbrücke mit Hubtoren, Aufzug auf die Eissäule,
## Glasbrücke zurück auf die Turmspitze, dort ein Hebelrätsel zu Fuß (Reihenfolge zeigt das
## Kristalltor) und die lange Abfahrt über die Eisspirale ins Ziel.

const COURSE = preload("res://scripts/games/parcours/parcours_course.gd")
const FORKS = preload("res://scripts/games/parcours/parcours_forks.gd")
const PEN = preload("res://scripts/games/parcours/parcours_pen.gd")
const BASE_Y: float = 10.0
const WATER_Y: float = 3.0


static func build():
	var course = COURSE.new()
	course.id = "eisturm"
	course.title = "Eis-Turm"
	course.tagline = "Spiralrampen, Eisbrücken und ein Kristallrätsel"
	course.kill_y = WATER_Y - 4.0
	course.pace = 0.4
	course.theme = {
		"sky_top": Color("0b2a68"),
		"sky_horizon": Color("f0a978"),
		"ground": Color("1b3a63"),
		"sun": Color("ffc896"),
		"sun_energy": 1.35,
		"sun_rotation": Vector3(-17, -60, 0),
		"ambient": Color("6f93c8"),
		"ambient_energy": 0.42,
		"fog": Color("8fb3df"),
		"fog_density": 0.0026,
		"exposure": 0.88,
		"deck": Color("1f4a78"),
		"deck_top": Color("b9cde4"),
		"deck_line": Color("5f7fa6"),
		"edge": Color("5ff0ff"),
		"trim": Color("7ee8ff"),
		"rail": Color("cfe9ff"),
		"rail_post": Color("6f8fb3"),
		"ice": Color("86c4ec"),
		"ice_line": Color("2f6fa6"),
		"ice_glow": Color("7ff3ff"),
		"glass": Color("a6e2ff"),
		"snow": Color("f2f6fb"),
		"accent": Color("8a7bff"),
		"metal": Color("6b86a8"),
		"support": Color("5d7fa6"),
		"gear": Color("9ad7ff"),
		"cloud": Color("c9d9ef"),
		"rock": Color("4a5a76"),
		"grass": Color("f4f8ff"),
		"tree": Color("2f6b58"),
		"tower": Color("4f9fd8"),
		"water": Color("0a2f57"),
		"support_depth": 14.0,
		"music": "bergwelt",
		"moss": Color("cbdaea"),
		"stone_line": Color("7f98b6"),
		"boost": Color("5ff0ff")
	}
	var pen = PEN.new(course, Vector3(0.0, BASE_Y, 0.0), 0.0, 12.0)
	pen.style = "moss"
	course.start = {"pos": pen.pos + Vector3.FORWARD * 6.0, "heading": 0.0}
	pen.checkpoint("start", 8.0)
	pen.star_line(3, 36.0, 2.5)
	pen.straight(36.0)
	pen.star_line(2, 20.0, -2.0)
	pen.turn(22.0, -50.0)
	pen.straight(24.0)
	pen.turn(22.0, 50.0)
	pen.straight(16.0)
	# 1) Spiralrampe um den Kristallturm, mit wandernden Eisblöcken.
	pen.checkpoint("spirale")
	pen.skill(
		"spirale",
		"Spiralrampe",
		"Die Eisblöcke rutschen hin und her – fahr vorbei, wenn Platz ist!",
		"Schau auf die Eisblöcke und fahr in die Lücke."
	)
	var tower: Vector3 = pen.pos - pen.right() * 28.0
	course.scenery.append(
		{
			"kind": "ice_tower",
			"pos": Vector3(tower.x, WATER_Y - 2.0, tower.z),
			"size": 14.5,
			"height": BASE_Y + 32.0 - WATER_Y + 1.5,
			"anchored": true
		}
	)
	pen.style = "ice"
	var parts: Array[int] = []
	for k in range(3):
		if k > 0:
			pen.checkpoint("spirale_%d" % k)
		parts.append(pen.turn(28.0, 150.0, 16.0 / 3.0, true, true, {"width": 11.0}))
	for k in range(3):
		var s: Dictionary = course.slabs[parts[k]]
		var u: float = 0.55
		var a: float = lerpf(float(s.a0), float(s.a1), u)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var at: Vector3 = (
			Vector3(tower.x, lerpf(float(s.y0), float(s.y1), u), tower.z) + radial * 28.0
		)
		course.blockers.append(
			{
				"shape": "box",
				"base": Transform3D(Basis.looking_at(radial, Vector3.UP), at),
				"size": Vector3(2.6, 2.4, 2.6),
				"style": "block",
				"motion":
				{"type": "slide", "axis": radial, "amp": 3.0, "period": 4.2, "phase": k * 2.1}
			}
		)
		course.stars.append(
			{"pos": at + Vector3.UP * 1.1 - radial * 4.0, "secret": false, "id": "sb%d" % k}
		)
	pen.level = 1
	# 2) Durchsichtige Eisbrücke mit zwei Hubtoren.
	pen.style = "ice"
	pen.straight(8.0)
	pen.checkpoint("eisbruecke")
	pen.skill(
		"eisbruecke",
		"Durchsichtige Eisbrücke",
		"Die Eistore gehen auf und zu – warte, bis das Tor oben ist, dann flitz durch!",
		"Bremsen, kurz warten, dann los, wenn das Tor oben ist."
	)
	pen.style = "glass"
	pen.width = 5.6
	var fork_entry: int = course.route.size()
	var fork_from: float = pen.travelled
	var bridge_start: Vector3 = pen.pos
	var bridge_heading: float = pen.heading
	pen.star_line(4, 56.0)
	pen.straight(56.0, 0.0, false, false, {"cap": 12.0})
	for k in range(2):
		var d: float = [18.0, 38.0][k]
		var at: Vector3 = bridge_start + PEN.forward_of(bridge_heading) * d + Vector3.UP * 1.6
		course.blockers.append(
			{
				"shape": "box",
				"base": Transform3D(Basis(Vector3.UP, bridge_heading), at),
				"size": Vector3(5.8, 2.8, 0.7),
				"style": "ice_gate",
				"timed": true,
				"open_above": 0.5,
				"motion":
				{"type": "slide", "axis": Vector3.UP, "amp": 1.6, "period": 4.4, "phase": k * 1.7}
			}
		)
	# 3) Aufzug auf die Eissäule.
	pen.style = "ice"
	pen.width = 14.0
	pen.straight(14.0)
	FORKS.connect_route(
		course, fork_entry, course.route.size() - 1, "Kristallgrat", "ice", -14.0, 2.4, 6.0, 14.0, fork_from
	)
	pen.checkpoint("eisaufzug")
	pen.skill(
		"eisaufzug",
		"Eisaufzug",
		"Fahr auf den Aufzug und halte an – er bringt dich auf die Eissäule!",
		"Ganz auf den Aufzug fahren, dann geht es nach oben."
	)
	pen.width = 12.0
	pen.straight(8.0, 0.0, true, true, {"hold_unless": "lift_b_ready", "style": "wait"})
	course.blockers.append(
		{
			"shape": "box",
			"base": Transform3D(Basis(Vector3.UP, pen.heading), pen.pos),
			"size": Vector3(12.0, 2.2, 0.6),
			"closed_unless": "lift_b_ready",
			"style": "gate"
		}
	)
	pen.style = "lift"
	pen.straight(
		14.0,
		0.0,
		true,
		true,
		{
			"width": 12.0,
			"hold_unless": "lift_b_top",
			"hold_from": 0.42,
			"motion": {"type": "lift_trigger", "id": "lift_b", "height": 16.0, "travel": 3.6}
		}
	)
	course.mechanisms["lift_b_ready"] = true
	pen.shift(0.0, 16.0)
	pen.level = 2
	pen.style = "ice"
	pen.width = 11.0
	pen.straight(10.0)
	pen.star_line(3, 25.0, 0.0)
	pen.turn(9.0, 180.0, 0.0, true, true, {"width": 10.0})
	pen.checkpoint("rueckweg")
	# Glasbrücke mit Geländer zurück zur Turmspitze.
	pen.style = "glass"
	pen.width = 8.0
	var plaza := Vector3(tower.x, pen.pos.y, tower.z)
	pen.star_line(3, 30.0, 0.0)
	pen.aim_at(plaza, 14.0, 14.6, 0.0, true)
	# 4) Turmspitze: Hebelrätsel zu Fuß vor dem Kristalltor.
	var entry_heading: float = pen.heading
	pen.checkpoint("turmspitze")
	course.slabs.append(
		{
			"kind": "arc",
			"base": Transform3D(Basis.IDENTITY, Vector3(plaza.x, 0.0, plaza.z)),
			"radius": 7.5,
			"width": 15.0,
			"a0": 0.0,
			"a1": TAU,
			"y0": plaza.y,
			"y1": plaza.y,
			"rail_left": false,
			"rail_right": false,
			"style": "ice",
			"level": 2,
			"no_assist": true
		}
	)
	course.route.append({"pos": plaza + Vector3.UP * 0.3, "cap": 10.0})
	pen.pos = plaza + PEN.forward_of(entry_heading) * 15.0
	pen.width = 12.0
	pen.style = "ice"
	_crystal_puzzle(course, pen, plaza, entry_heading)
	# 5) Abfahrt: Kristallsteg und Eisspirale hinunter zum See.
	pen.style = "glass"
	pen.width = 9.0
	pen.straight(34.0, 0.0, true, true)
	pen.checkpoint("abfahrt")
	pen.skill(
		"abfahrt",
		"Eisspirale",
		"Jetzt geht es rund nach unten – schön in der Mitte bleiben!",
		"In der Kurve ein bisschen bremsen, dann klappt es."
	)
	pen.style = "ice"
	pen.width = 11.0
	var spiral_centre: Vector3 = pen.pos + pen.right() * 22.0
	course.scenery.append(
		{
			"kind": "crystal_column",
			"pos": Vector3(spiral_centre.x, WATER_Y - 2.0, spiral_centre.z),
			"size": 9.0,
			"height": pen.pos.y - WATER_Y + 6.0,
			"anchored": true
		}
	)
	pen.star_line(4, 80.0, 0.0)
	pen.turn(22.0, -180.0, -11.0, true, true)
	pen.checkpoint("spirale_unten")
	pen.turn(22.0, -180.0, -11.0, true, true)
	pen.checkpoint("seeufer")
	pen.style = "moss"
	pen.width = 12.0
	pen.straight(36.0, -10.0)
	# Breites Seeufer mit geheimem Eiszapfen-Steg links oben.
	pen.width = 18.0
	PEN.secret_ramp(
		course, pen.pos, pen.heading, -6.0, 3.0, "eiszapfensteg", "Geheimer Eiszapfen-Steg", "glass"
	)
	pen.star_line(3, 64.0, 3.0)
	pen.straight(64.0)
	pen.width = 12.0
	course.finish = {"pos": pen.pos + Vector3.UP * 0.5, "radius": 7.0, "heading": pen.heading}
	pen.straight(22.0)
	pen.end_route()
	_scenery(course)
	course.finalize()
	return course


## Drei Kristallhebel auf der Turmspitze. Das Tor zeigt mit Farblampen die Reihenfolge.
static func _crystal_puzzle(course, pen, plaza: Vector3, heading: float) -> void:
	var ahead: Vector3 = PEN.forward_of(heading)
	var side: Vector3 = PEN.right_of(heading)
	var levers: Array = [
		{
			"pos": plaza + side * 9.0,
			"color": Color("4fb3ff"),
			"name": "Blau",
			"heading": heading - PI * 0.5
		},
		{
			"pos": plaza - side * 9.0,
			"color": Color("5be38a"),
			"name": "Grün",
			"heading": heading + PI * 0.5
		},
		{
			"pos": plaza - ahead * 9.0,
			"color": Color("b47cff"),
			"name": "Lila",
			"heading": heading + PI
		}
	]
	var order: Array = [1, 2, 0]
	var wait_start: Vector3 = pen.pos
	pen.straight(
		12.0, 0.0, true, true, {"style": "wait", "hold_unless": "crystal_gate", "hold_from": 0.35}
	)
	course.blockers.append(
		{
			"shape": "box",
			"base": Transform3D(Basis(Vector3.UP, heading), pen.pos),
			"size": Vector3(12.0, 2.2, 0.6),
			"closed_unless": "crystal_gate",
			"style": "gate",
			"lamps": [levers[order[0]].color, levers[order[1]].color, levers[order[2]].color]
		}
	)
	course.mechanisms["crystal_gate"] = false
	var kart_pos: Vector3 = wait_start + ahead * 6.0
	var route: Array = []
	for index in order:
		var p: Vector3 = levers[index].pos
		route.append({"pos": p + (plaza - p).normalized() * 1.4, "press": true})
	course.stations.append(
		{
			"id": "kristallraetsel",
			"kart_pos": kart_pos,
			"radius": 7.0,
			"foot_start": kart_pos - ahead * 3.0,
			"foot_heading": heading + PI,
			"levers": levers,
			"order": order,
			"lever": levers[order[2]].pos,
			"mechanism": "crystal_gate",
			"jump_back": false,
			"intro": "Das Kristalltor ist zu. Tipp auf AUSSTEIGEN!",
			"foot_intro": "Schau auf das Tor: Leg die Hebel in der Reihenfolge der Lampen um!",
			"hint": "Hoppla, falsche Reihenfolge. Schau auf die Lampen am Tor: 1, 2, 3!",
			"done_text": "Das Kristalltor geht auf! Zurück zum Kart und EINSTEIGEN.",
			"foot_retry": "Die Lumo-Wolke bringt dich zurück aufs Eis.",
			"foot_route": route
		}
	)


static func _scenery(course) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	course.scenery.append(
		{"kind": "water", "pos": Vector3(0, WATER_Y, -120), "size": 900.0, "anchored": true}
	)
	for i in range(14):
		var a: float = TAU * i / 14.0 + rng.randf() * 0.2
		var r: float = rng.randf_range(260.0, 380.0)
		course.scenery.append(
			{
				"kind": "mountain",
				"pos": Vector3(cos(a) * r, WATER_Y - 2.0, sin(a) * r - 120.0),
				"size": rng.randf_range(50.0, 95.0),
				"anchored": true
			}
		)
	for i in range(26):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(90.0, 210.0)
		course.scenery.append(
			{
				"kind": "floe",
				"pos": Vector3(cos(a) * r, WATER_Y + 0.1, sin(a) * r - 120.0),
				"size": rng.randf_range(3.0, 9.0)
			}
		)
	for i in range(12):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(120.0, 220.0)
		course.scenery.append(
			{
				"kind": "pine_isle",
				"pos": Vector3(cos(a) * r, WATER_Y, sin(a) * r - 120.0),
				"size": rng.randf_range(8.0, 16.0)
			}
		)
