extends RefCounted
## Welt A – Wolkenwerkstatt. Eine Werkstatt hoch über den Wolken auf drei Ebenen:
## schmale Wolkenbrücke, schwebende Schiebeplattformen, ein Aufzug zur oberen Halle,
## eine Drehscheibe mit Zahnradsäulen, eine Schanze und ein geheimer Zahnradsteg.
## Alle Maße sind echte Fahrbahn (parcours_course.gd); die Optik baut parcours_builder.gd.

const COURSE = preload("res://scripts/games/parcours/parcours_course.gd")
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
		"sky_top": Color("3d7fd6"),
		"sky_horizon": Color("ffd9b0"),
		"ground": Color("f4f1ff"),
		"sun": Color("fff1d6"),
		"sun_energy": 1.55,
		"sun_rotation": Vector3(-38, 35, 0),
		"ambient": Color("b9cff5"),
		"fog": Color("e9eefc"),
		"fog_density": 0.0035,
		"deck": Color("2f5f99"),
		"deck_top": Color("e7eef9"),
		"edge": Color("ffc642"),
		"rail": Color("ffd56a"),
		"bridge": Color("d8a46a"),
		"float": Color("8fd3ff"),
		"accent": Color("ff8a3d"),
		"metal": Color("6d7f99"),
		"cloud": Color("ffffff"),
		"music": "bergwelt"
	}
	var pen = PEN.new(course, Vector3(0.0, BASE_Y, 0.0), 0.0, 12.0)
	course.start = {"pos": pen.pos + Vector3.FORWARD * 6.0, "heading": 0.0}
	pen.checkpoint("start", 8.0)
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
	pen.star_line(5, 52.0)
	pen.straight(52.0, 0.0, false, false, {"cap": 12.0})
	pen.style = "deck"
	pen.width = 11.0
	pen.straight(14.0)
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
	pen.checkpoint("finale")
	_secret_gear_path(course, wide_start, wide_heading)
	pen.width = 12.0
	pen.star_line(3, 28.0, 0.0)
	pen.turn(18.0, -90.0)
	pen.style = "ramp"
	pen.straight(30.0, -6.0)
	pen.style = "deck"
	pen.turn(16.0, 90.0)
	pen.straight(16.0)
	course.finish = {"pos": pen.pos + Vector3.UP * 0.5, "radius": 7.0, "heading": pen.heading}
	pen.straight(22.0)
	pen.end_route()
	_scenery(course)
	course.finalize()
	return course


## Geheimer Zahnradsteg: links auf dem breiten Deck führt eine Rampe auf einen schmalen
## Steg drei Meter über der Fahrbahn. Wer herunterfällt, landet weich auf dem Deck.
static func _secret_gear_path(course, start: Vector3, heading: float) -> void:
	var pen = PEN.new(course, start, heading, 3.6)
	pen.shift(-6.0)
	pen.straight(6.0, 0.0, false, false, {"style": "none"})
	pen.style = "secret"
	var first: int = pen.straight(14.0, 3.0, false, false, {"solid": true})
	course.secrets.append(
		{
			"id": "zahnradsteg",
			"name": "Geheimer Zahnradsteg",
			"pos": pen.pos + Vector3.UP * 0.6,
			"radius": 3.5
		}
	)
	pen.star_line(4, 26.0, 0.0, true)
	pen.straight(26.0, 0.0, false, false)
	var last: int = pen.straight(14.0, -3.0, false, false, {"solid": true})
	for index in [first, last]:
		course.slabs[index]["solid"] = true
	# Die Route des Bots bleibt auf dem Hauptweg; der Geheimweg hat eine eigene.
	course.route.resize(course.route.size() - 4)


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
