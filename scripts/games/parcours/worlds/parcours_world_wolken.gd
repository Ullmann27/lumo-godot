extends RefCounted
## Welt A – Wolkenwerkstatt. Eine Werkstatt hoch über den Wolken auf drei Ebenen:
## schmale Wolkenbrücke, schwebende Schiebeplattformen, ein Aufzug zur oberen Halle,
## eine Drehscheibe mit Zahnradsäulen, eine Schanze und ein geheimer Zahnradsteg.
## Alle Maße sind echte Fahrbahn (parcours_course.gd); die Optik baut parcours_builder.gd.

const COURSE = preload("res://scripts/games/parcours/parcours_course.gd")
const FORKS = preload("res://scripts/games/parcours/parcours_forks.gd")
const PEN = preload("res://scripts/games/parcours/parcours_pen.gd")
const BASE_Y: float = 40.0


static func build():
	var course = COURSE.new()
	course.id = "wolkenwerkstatt"
	course.title = "Wolkenwerkstatt"
	course.tagline = "Brücken, Schwebeplattformen und ein Aufzug über den Wolken"
	course.kill_y = BASE_Y - 22.0
	course.pace = 0.4
	course.target_seconds = Vector2(120, 240)
	course.theme = {
		"sky_top": Color("27548c"),
		"sky_horizon": Color("d7ab94"),
		"ground": Color("6785a4"),
		"sun": Color("ffddb2"),
		"sun_energy": 0.91,
		"sun_rotation": Vector3(-34, 40, 0),
		"ambient": Color("b3c3d0"),
		"ambient_energy": 0.57,
		"fog": Color("9aaec1"),
		"fog_density": 0.0018,
		"exposure": 0.84,
		"deck": Color("27497c"),
		"deck_top": Color("607995"),
		"deck_line": Color("3a5788"),
		"edge": Color("f0ad4f"),
		"trim": Color("ffb43a"),
		"rail": Color("c6813c"),
		"rail_post": Color("374956"),
		"bridge": Color("c08a55"),
		"bridge_line": Color("6a4426"),
		"float": Color("6fbff2"),
		"float_line": Color("2f6ea8"),
		"float_glow": Color("8fe8ff"),
		"disc": Color("a8b8d6"),
		"secret": Color("d8a24a"),
		"secret_glow": Color("ffd166"),
		"boost": Color("3ef2ff"),
		"accent": Color("ff7a3d"),
		"metal": Color("5a6e91"),
		"support": Color("3b5480"),
		"gear": Color("d8a84a"),
		"cloud": Color("c6d9e3"),
		"rock": Color("9c8574"),
		"grass": Color("7cc46a"),
		"tree": Color("3f9a5a"),
		"support_depth": 26.0,
		"glow": 0.5,
	}
	var pen = PEN.new(course, Vector3(0.0, BASE_Y, 0.0), 0.0, 12.0)
	course.start = {"pos": pen.pos + Vector3.FORWARD * 6.0, "heading": 0.0}
	pen.checkpoint("start", 8.0)
	course.scenery.append(
		{
			"kind": "hangar",
			"pos": pen.pos + pen.right() * 26.0 + pen.forward() * 14.0 + Vector3.DOWN * 0.7,
			"size": 18.0,
			"yaw": PI * 0.5,
			"anchored": true
		}
	)
	# Startplatz der Werkstatt.
	pen.star_line(3, 34.0, -2.5)
	pen.straight(34.0)
	pen.width = 11.0
	pen.star_line(3, 25.0, 2.0)
	pen.turn(16.0, -90.0)
	pen.straight(18.0)
	pen.style = "ramp"
	pen.straight(36.0, 7.0)
	pen.style = "deck"
	pen.level = 1
	pen.straight(12.0)
	# 1) Schmale Wolkenbrücke ohne Geländer.
	pen.checkpoint("bruecke")
	pen.skill(
		"bruecke",
		"Schmale Wolkenbrücke",
		"Die Brücke ist schmal – bleib in der Mitte auf der gelben Linie!",
		"Fast! Lenk ganz sanft, dann bleibst du auf der Brücke."
	)
	pen.style = "bridge"
	pen.width = 4.8
	var fork_entry: int = course.route.size()
	var fork_from: float = pen.travelled
	pen.star_line(5, 52.0)
	pen.straight(52.0, 0.0, false, false, {"cap": 12.0})
	pen.style = "deck"
	pen.width = 11.0
	pen.straight(14.0)
	FORKS.connect_route(
		course, fork_entry, course.route.size() - 1, "Panoramasteg", "deck", 11.5, 1.8, 7.6, 15.0, fork_from
	)
	pen.star_line(2, 22.0, -2.0)
	pen.turn(14.0, 90.0)
	pen.straight(14.0)
	# 2) Schwebende Schiebeplattformen.
	pen.checkpoint("schweber")
	pen.skill(
		"schweber",
		"Schwebende Plattformen",
		"Die Plattformen schweben hin und her – fahr mit, wenn sie vor dir liegen!",
		"Warte kurz, bis die Plattform vor dir steht, dann fahr los."
	)
	pen.style = "float"
	var sideways: Vector3 = pen.right()
	for i in range(3):
		var phase: float = [0.0, 2.0, 4.1][i]
		pen.star(0.0, 6.0)
		pen.straight(
			12.0,
			0.0,
			false,
			false,
			{
				"width": 9.5,
				"cap": 11.0,
				"motion":
				{"type": "slide", "axis": sideways, "amp": 2.2, "period": 5.0, "phase": phase}
			}
		)
	pen.style = "deck"
	pen.width = 11.0
	pen.straight(16.0)
	pen.star_line(3, 30.0, 0.0)
	pen.turn(18.0, 60.0)
	pen.straight(20.0)
	# 3) Aufzug zur oberen Halle.
	pen.checkpoint("aufzug")
	pen.skill(
		"aufzug",
		"Wolkenaufzug",
		"Fahr auf den Aufzug und bleib stehen – er bringt dich nach oben!",
		"Der Aufzug wartet auf dich. Fahr ganz drauf, dann geht es los."
	)
	pen.straight(10.0, 0.0, true, true, {"hold_unless": "lift_a_ready", "style": "wait"})
	var gate_pos: Vector3 = pen.pos
	course.blockers.append(
		{
			"shape": "box",
			"base": Transform3D(Basis(Vector3.UP, pen.heading), gate_pos),
			"size": Vector3(11.0, 2.2, 0.6),
			"closed_unless": "lift_a_ready",
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
			"hold_unless": "lift_a_top",
			"hold_from": 0.42,
			"motion": {"type": "lift_trigger", "id": "lift_a", "height": 12.0, "travel": 3.2}
		}
	)
	course.mechanisms["lift_a_ready"] = true
	pen.shift(0.0, 12.0)
	pen.style = "deck"
	pen.level = 2
	pen.straight(18.0)
	pen.checkpoint("halle")
	pen.star_line(4, 40.0, 0.0)
	pen.turn(15.0, 180.0)
	pen.straight(16.0)
	# 4) Drehscheibe mit Zahnradsäulen.
	pen.checkpoint("drehscheibe")
	pen.skill(
		"drehscheibe",
		"Große Drehscheibe",
		"Die Scheibe dreht sich – lenk ein bisschen gegen und weich den Säulen aus!",
		"Gegenlenken! Fahr auf das Licht am anderen Ende zu."
	)
	var disc_radius: float = 9.5
	var centre: Vector3 = pen.pos + pen.forward() * disc_radius
	var spin := {"type": "spin", "pivot": Vector3(centre.x, 0.0, centre.z), "speed": 0.42}
	course.slabs.append(
		{
			"kind": "arc",
			"base": Transform3D(Basis.IDENTITY, Vector3(centre.x, 0.0, centre.z)),
			"radius": disc_radius * 0.5,
			"width": disc_radius,
			"a0": 0.0,
			"a1": TAU,
			"y0": centre.y,
			"y1": centre.y,
			"rail_left": false,
			"rail_right": false,
			"style": "disc",
			"level": 2,
			"no_assist": true,
			"cap": 12.0,
			"motion": spin
		}
	)
	for k in range(2):
		var a: float = PI * k + 0.6
		course.blockers.append(
			{
				"shape": "cylinder",
				"base": Transform3D(Basis.IDENTITY, centre + Vector3(cos(a), 0.0, sin(a)) * 5.6),
				"size": Vector3(0.7, 2.6, 0.7),
				"motion": spin,
				"style": "gear_post"
			}
		)
	pen.star(0.0, disc_radius)
	course.route.append({"pos": centre + Vector3.UP * 0.3, "cap": 10.0})
	pen.gap(disc_radius * 2.0)
	pen.straight(14.0)
	pen.checkpoint("schanze")
	# 5) Schanze über die Wolkenlücke.
	pen.skill(
		"schanze",
		"Wolkenschanze",
		"Das Schwungband gibt dir Tempo – geradeaus über die Lücke springen!",
		"Fahr gerade auf die Schanze zu, das Schwungband macht den Rest."
	)
	pen.turn(20.0, -45.0)
	pen.straight(16.0, 0.0, true, true, {"boost_to": 17.5, "style": "boostband"})
	pen.style = "ramp"
	pen.straight(12.0, 2.2, true, true, {"boost_to": 17.5})
	pen.gap(4.5, 2.0)
	pen.style = "deck"
	pen.width = 18.0
	var wide_start: Vector3 = pen.pos
	var wide_heading: float = pen.heading
	pen.star_line(3, 64.0, 3.0)
	pen.straight(64.0)
	pen.checkpoint("werkbank")
	PEN.secret_ramp(
		course, wide_start, wide_heading, -6.0, 3.0, "zahnradsteg", "Geheimer Zahnradsteg"
	)
	# Fußabschnitt: Die Werkbank-Brücke ist eingefahren. Lumo steigt aus, hüpft über
	# schwebende Trittsteine zum Hebel und fährt die Brücke aus.
	pen.width = 12.0
	_workbench_station(course, pen)
	pen.style = "deck"
	pen.checkpoint("bruecke_aus")
	pen.straight(12.0)
	# Zahnrad-Spirale: anderthalb Runden abwärts um den großen Zahnradturm.
	pen.checkpoint("spirale")
	pen.star_line(4, 60.0, 0.0)
	course.scenery.append(
		{
			"kind": "tower",
			"pos": pen.pos + pen.right() * 19.0 + Vector3.DOWN * 14.0,
			"size": 7.0,
			"height": 32.0,
			"anchored": true
		}
	)
	pen.style = "ramp"
	pen.turn(19.0, -270.0, -6.0, true, true, {"width": 10.0})
	pen.checkpoint("spirale_mitte")
	pen.turn(19.0, -270.0, -6.0, true, true, {"width": 10.0})
	pen.style = "deck"
	pen.checkpoint("zielgerade")
	pen.star_line(3, 24.0, -2.0)
	pen.straight(24.0)
	course.finish = {"pos": pen.pos + Vector3.UP * 0.5, "radius": 7.0, "heading": pen.heading}
	pen.straight(22.0)
	pen.end_route()
	_scenery(course)
	course.finalize()
	return course


static func _workbench_station(course, pen) -> void:
	var wait_start: Vector3 = pen.pos
	var heading: float = pen.heading
	var ahead: Vector3 = pen.forward()
	var side: Vector3 = pen.right()
	pen.straight(
		14.0, 0.0, true, false, {"style": "wait", "hold_unless": "bridge_a", "hold_from": 0.4}
	)
	var kart_pos: Vector3 = wait_start + ahead * 8.0
	# Lücke mit Tor; die Brücke parkt links daneben, bis der Hebel sie ausfährt.
	course.blockers.append(
		{
			"shape": "box",
			"base": Transform3D(Basis(Vector3.UP, heading), pen.pos),
			"size": Vector3(12.0, 2.2, 0.6),
			"closed_unless": "bridge_a",
			"style": "gate"
		}
	)
	pen.style = "bridge"
	pen.straight(
		16.0,
		0.0,
		true,
		true,
		{
			"motion":
			{"type": "extend", "mechanism": "bridge_a", "retract": -side * 15.0, "seconds": 1.8}
		}
	)
	course.mechanisms["bridge_a"] = false
	# Trittsteine rechts neben dem Wartefeld, dann die Hebelinsel.
	var stones: Array[float] = [9.0, 12.9, 16.8]
	for k in range(stones.size()):
		var centre: Vector3 = kart_pos + side * stones[k]
		course.slabs.append(
			{
				"kind": "box",
				"base": Transform3D(Basis(Vector3.UP, heading), centre - ahead * 1.2),
				"length": 2.4,
				"width": 2.4,
				"rise": 0.0,
				"rail_left": false,
				"rail_right": false,
				"style": "float",
				"level": 3,
				"foot_only": true
			}
		)
	var island: Vector3 = kart_pos + side * 21.5
	course.slabs.append(
		{
			"kind": "box",
			"base": Transform3D(Basis(Vector3.UP, heading), island - ahead * 2.0),
			"length": 4.0,
			"width": 4.0,
			"rise": 0.0,
			"rail_left": false,
			"rail_right": false,
			"style": "deck",
			"level": 3,
			"foot_only": true
		}
	)
	var route: Array = [{"pos": kart_pos + side * 5.2}]
	for k in range(stones.size()):
		route.append({"pos": kart_pos + side * stones[k], "jump": true})
	route.append({"pos": kart_pos + side * 20.5, "jump": true})
	course.stations.append(
		{
			"id": "werkbank",
			"kart_pos": kart_pos,
			"radius": 7.0,
			"foot_start": kart_pos + side * 2.6,
			"foot_heading": heading - PI * 0.5,
			"lever": island,
			"lever_heading": heading - PI * 0.5,
			"mechanism": "bridge_a",
			"intro": "Hier geht es nur zu Fuß weiter. Tipp auf AUSSTEIGEN!",
			"foot_intro": "Spring über die Trittsteine zum Hebel!",
			"done_text": "Die Brücke fährt aus! Zurück zum Kart und EINSTEIGEN.",
			"foot_retry": "Plumps – die Lumo-Wolke trägt dich zurück. Spring etwas früher!",
			"foot_route": route
		}
	)


static func _scenery(course) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in range(46):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(70.0, 240.0)
		course.scenery.append(
			{
				"kind": "cloud",
				"pos": Vector3(cos(a) * r, BASE_Y - rng.randf_range(10, 34), sin(a) * r),
				"size": rng.randf_range(9.0, 26.0)
			}
		)
	for i in range(9):
		var a: float = TAU * i / 9.0 + 0.3
		var r: float = rng.randf_range(120.0, 190.0)
		course.scenery.append(
			{
				"kind": "island",
				"pos": Vector3(cos(a) * r, BASE_Y + rng.randf_range(-6, 24), sin(a) * r),
				"size": rng.randf_range(10.0, 22.0)
			}
		)
	for i in range(6):
		var a: float = TAU * i / 6.0
		course.scenery.append(
			{
				"kind": "gear",
				"pos": Vector3(cos(a) * 95.0, BASE_Y + 18.0 + i * 3.0, sin(a) * 95.0 - 60),
				"size": rng.randf_range(6.0, 12.0)
			}
		)
