extends RefCounted
## Welt C – Dschungel-Tempel. Eine Tempelanlage im Urwald: schmale Wurzelwege über den
## Fluss, die Lianenhalle (Sonnenplatte öffnet das Lianentor), der Gang der rollenden
## Steinwalzen, Treppenrampen auf die obere Terrasse, zu Fuß über Steinsäulen zum alten
## Hebel (die Steinbrücke hebt sich aus der Schlucht) und das Finale im Kart: Tempelabfahrt
## mit Schwungband und Sprung bis zum Flusstor.

const COURSE = preload("res://scripts/games/parcours/parcours_course.gd")
const PEN = preload("res://scripts/games/parcours/parcours_pen.gd")
const BASE_Y: float = 6.0
const WATER_Y: float = 0.0


static func build():
	var course = COURSE.new()
	course.id = "dschungeltempel"
	course.title = "Dschungel-Tempel"
	course.tagline = "Wurzelwege, Lianentore und eine alte Steinbrücke"
	course.kill_y = WATER_Y - 4.0
	course.pace = 0.4
	course.theme = {
		"sky_top": Color("2f74c0"), "sky_horizon": Color("ffd59a"), "ground": Color("2d4a22"),
		"sun": Color("ffd89a"), "sun_energy": 1.3, "sun_rotation": Vector3(-42, 25, 0),
		"ambient": Color("8fb27a"), "ambient_energy": 0.42, "fog": Color("a9c99a"),
		"fog_density": 0.0022, "exposure": 0.86, "deck": Color("4a3a2a"),
		"deck_top": Color("9c8664"), "deck_line": Color("57452f"), "edge": Color("ffd24a"),
		"trim": Color("e8b44a"), "rail": Color("7a5a38"), "rail_post": Color("5b4430"),
		"stone": Color("a08b6c"), "stone_line": Color("4f4232"), "bridge": Color("9a6a3e"),
		"bridge_line": Color("4a321c"), "moss": Color("7aa24e"), "accent": Color("ff9a3c"),
		"metal": Color("6d5b45"), "support": Color("6a5a46"), "secret": Color("8f6a3a"),
		"secret_glow": Color("ffd36a"), "boost": Color("ffd24a"), "plate": Color("ffcf4a"),
		"cloud": Color("dfe8d6"), "post": Color("8a7658"), "rock": Color("6b6252"), "grass": Color("5f9a3e"),
		"tree": Color("2a6e34"), "water": Color("123f3a"), "tower": Color("8a7658"),
		"support_depth": 10.0, "music": "zauberwald", "float": Color("b8a68a"),
		"float_line": Color("6c5c46"), "float_glow": Color("ffd24a"), "gear": Color("c9a050")
	}
	var pen = PEN.new(course, Vector3(0.0, BASE_Y, 0.0), 0.0, 12.0)
	pen.style = "stone"
	course.start = {"pos": pen.pos + Vector3.FORWARD * 6.0, "heading": 0.0}
	pen.checkpoint("start", 8.0)
	pen.star_line(3, 30.0, -2.5)
	pen.straight(30.0)
	pen.turn(18.0, 35.0)
	pen.straight(12.0)
	# 1) Schmale Wurzelwege über dem Fluss.
	pen.checkpoint("wurzelweg")
	pen.skill(
		"wurzelweg", "Schmale Wurzelwege",
		"Die Wurzelwege sind schmal – bleib auf der gelben Linie in der Mitte!",
		"Ganz sanft lenken, dann bleibst du auf der Wurzel."
	)
	pen.style = "wood"
	pen.width = 5.4
	pen.star_line(3, 22.0)
	pen.straight(22.0, 0.0, false, false, {"cap": 11.0})
	pen.turn(24.0, -35.0, 0.0, false, false, {"cap": 10.0})
	pen.star_line(3, 20.0)
	pen.straight(20.0, 0.0, false, false, {"cap": 11.0})
	pen.turn(24.0, 35.0, 0.0, false, false, {"cap": 10.0})
	pen.straight(12.0, 0.0, false, false, {"cap": 11.0})
	pen.style = "stone"
	pen.width = 12.0
	pen.straight(10.0)
	# 2) Lianenhalle: Sonnenplatte öffnet das Lianentor.
	pen.checkpoint("lianenhalle")
	pen.skill(
		"lianenhalle", "Lianenhalle",
		"Fahr über die Sonnenplatte – dann gehen die Lianen am Tor zur Seite!",
		"Die Sonnenplatte liegt rechts in der Halle. Einfach drüberfahren!"
	)
	var room_start: Vector3 = pen.pos
	var room_heading: float = pen.heading
	pen.width = 24.0
	pen.straight(34.0, 0.0, true, true, {"room": true})
	var plate: Vector3 = room_start + PEN.forward_of(room_heading) * 15.0 + PEN.right_of(room_heading) * 7.0
	course.plates.append({
		"pos": plate, "radius": 3.2, "mechanism": "vines_1",
		"text": "Die Sonnenplatte leuchtet – das Lianentor öffnet sich!"
	})
	course.route.append({"pos": plate + Vector3.UP * 0.3, "cap": 10.0})
	course.route.append({"pos": room_start + PEN.forward_of(room_heading) * 28.0 + Vector3.UP * 0.3, "cap": 10.0})
	course.mechanisms["vines_1"] = false
	course.blockers.append({
		"shape": "box", "base": Transform3D(Basis(Vector3.UP, room_heading), pen.pos),
		"size": Vector3(24.0, 4.2, 0.8), "closed_unless": "vines_1", "style": "vine_gate"
	})
	_room_walls(course, room_start, room_heading, 34.0, 24.0)
	pen.width = 12.0
	pen.straight(12.0)
	# 3) Gang der rollenden Steinwalzen.
	pen.checkpoint("walzengang")
	pen.skill(
		"walzengang", "Rollende Steinwalzen",
		"Die Steinwalzen rollen hin und her – fahr durch die Lücke!",
		"Warte auf die Lücke neben der Walze, dann fahr durch."
	)
	pen.width = 11.0
	var corridor_start: Vector3 = pen.pos
	var corridor_heading: float = pen.heading
	pen.star_line(3, 46.0, 0.0)
	pen.straight(46.0, 0.0, true, true, {"room": true})
	for k in range(3):
		var at: Vector3 = corridor_start + PEN.forward_of(corridor_heading) * (11.0 + k * 12.0)
		course.blockers.append({
			"shape": "box", "base": Transform3D(Basis(Vector3.UP, corridor_heading), at),
			"size": Vector3(2.3, 2.3, 3.4), "style": "log",
			"motion": {
				"type": "slide", "axis": PEN.right_of(corridor_heading), "amp": 3.0,
				"period": 3.8, "phase": k * 2.2
			}
		})
	_room_walls(course, corridor_start, corridor_heading, 46.0, 11.0)
	pen.width = 12.0
	pen.straight(10.0)
	# 4) Tempelhof mit der drehenden Sonnenscheibe.
	pen.checkpoint("sonnenscheibe")
	pen.skill(
		"sonnenscheibe", "Drehende Sonnenscheibe",
		"Die Sonnenscheibe dreht sich – lenk gegen und fahr auf das Tor gegenüber zu!",
		"Ein bisschen gegenlenken und geradeaus aufs Tor zielen."
	)
	pen.star(0.0, 10.0)
	pen.spin_disc(10.0, -0.36, 3, {"style": "sun_disc"})
	pen.straight(12.0)
	pen.star_line(3, 40.0, 2.0)
	pen.turn(26.0, 60.0)
	pen.straight(26.0)
	pen.turn(26.0, -60.0)
	# 5) Treppenrampen auf die obere Terrasse.
	pen.checkpoint("terrasse")
	pen.turn(16.0, -90.0)
	pen.straight(30.0, 8.0, true, true, {"style": "stairs"})
	pen.level = 1
	pen.straight(8.0)
	pen.star_line(3, 30.0, 0.0)
	pen.turn(13.0, 180.0)
	pen.checkpoint("treppe")
	pen.straight(30.0, 8.0, true, true, {"style": "stairs"})
	pen.level = 2
	pen.width = 18.0
	var terrace: Vector3 = pen.pos
	PEN.secret_ramp(course, terrace, pen.heading, 6.0, 3.0, "wurzelbruecke", "Geheime Wurzelbrücke", "secret")
	pen.star_line(3, 56.0, -3.0)
	pen.straight(56.0)
	pen.width = 12.0
	pen.checkpoint("schlucht")
	# 6) Zu Fuß über Steinsäulen zum alten Hebel: die Steinbrücke hebt sich.
	_pillar_station(course, pen)
	pen.checkpoint("finale")
	# 7) Finale im Kart: Tempelabfahrt mit Schwungband und Sprung zum Flusstor.
	pen.skill(
		"finale", "Tempelabfahrt",
		"Jetzt volle Fahrt: das Schwungband trägt dich über die Schlucht ins Ziel!",
		"Gerade auf die Schanze zu – das Schwungband macht den Rest."
	)
	pen.straight(10.0)
	pen.style = "boostband"
	pen.straight(40.0, -10.0, true, true, {"boost_to": 17.5})
	pen.style = "stone"
	pen.straight(10.0, 1.8, true, true, {"boost_to": 17.5})
	pen.gap(5.0, 3.0)
	pen.width = 16.0
	pen.straight(28.0)
	pen.checkpoint("flusstor")
	pen.width = 12.0
	pen.straight(24.0, -4.8)
	pen.star_line(3, 30.0, 2.0)
	pen.turn(18.0, 70.0)
	pen.straight(10.0)
	course.finish = {"pos": pen.pos + Vector3.UP * 0.5, "radius": 7.0, "heading": pen.heading}
	pen.straight(22.0)
	pen.end_route()
	_scenery(course)
	course.finalize()
	return course


## Hohe Tempelmauern links und rechts eines Raums (Optik; das Geländer ist die Kollision).
static func _room_walls(course, start: Vector3, heading: float, length: float, width: float) -> void:
	var ahead: Vector3 = PEN.forward_of(heading)
	var side: Vector3 = PEN.right_of(heading)
	for s in [-1.0, 1.0]:
		course.scenery.append({
			"kind": "temple_wall", "pos": start + ahead * length * 0.5 + side * s * (width * 0.5 + 0.8),
			"size": length, "yaw": heading, "height": 7.0, "anchored": true
		})


static func _pillar_station(course, pen) -> void:
	var wait_start: Vector3 = pen.pos
	var heading: float = pen.heading
	var ahead: Vector3 = pen.forward()
	var side: Vector3 = pen.right()
	pen.straight(14.0, 0.0, true, false, {"style": "wait", "hold_unless": "stone_bridge", "hold_from": 0.4})
	var kart_pos: Vector3 = wait_start + ahead * 8.0
	course.blockers.append({
		"shape": "box", "base": Transform3D(Basis(Vector3.UP, heading), pen.pos),
		"size": Vector3(12.0, 2.2, 0.6), "closed_unless": "stone_bridge", "style": "gate"
	})
	pen.style = "stone"
	pen.straight(18.0, 0.0, true, true, {
		"motion": {"type": "extend", "mechanism": "stone_bridge", "retract": Vector3.DOWN * 9.0, "seconds": 2.2}
	})
	course.mechanisms["stone_bridge"] = false
	var stones: Array[float] = [9.0, 12.9, 16.8]
	var heights: Array[float] = [0.4, 0.9, 0.4]
	for k in range(stones.size()):
		var centre: Vector3 = kart_pos + side * stones[k] + Vector3.UP * heights[k]
		course.slabs.append({
			"kind": "box", "base": Transform3D(Basis(Vector3.UP, heading), centre - ahead * 1.3),
			"length": 2.6, "width": 2.6, "rise": 0.0, "rail_left": false, "rail_right": false,
			"style": "stone", "level": 3, "foot_only": true, "pillar": 14.0
		})
	var island: Vector3 = kart_pos + side * 21.5
	course.slabs.append({
		"kind": "box", "base": Transform3D(Basis(Vector3.UP, heading), island - ahead * 2.2),
		"length": 4.4, "width": 4.4, "rise": 0.0, "rail_left": false, "rail_right": false,
		"style": "stone", "level": 3, "foot_only": true, "pillar": 14.0
	})
	var route: Array = [{"pos": kart_pos + side * 5.2}]
	for k in range(stones.size()):
		route.append({"pos": kart_pos + side * stones[k] + Vector3.UP * heights[k], "jump": true})
	route.append({"pos": kart_pos + side * 20.5, "jump": true})
	course.stations.append({
		"id": "steinbruecke", "kart_pos": kart_pos, "radius": 7.0,
		"foot_start": kart_pos + side * 2.6, "foot_heading": heading - PI * 0.5,
		"lever": island, "lever_heading": heading - PI * 0.5, "mechanism": "stone_bridge",
		"intro": "Die Steinbrücke liegt unten in der Schlucht. Tipp auf AUSSTEIGEN!",
		"foot_intro": "Hüpf über die Steinsäulen zum alten Hebel!",
		"done_text": "Die Steinbrücke hebt sich! Zurück zum Kart und EINSTEIGEN.",
		"foot_retry": "Platsch – die Lumo-Wolke holt dich zurück. Spring etwas früher!",
		"foot_route": route
	})


static func _scenery(course) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1302
	course.scenery.append({"kind": "water", "pos": Vector3(0, WATER_Y, -100), "size": 900.0, "anchored": true})
	for i in range(150):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(10.0, 230.0)
		course.scenery.append({
			"kind": "jungle_tree", "pos": Vector3(cos(a) * r + 40.0, WATER_Y, sin(a) * r - 90.0),
			"size": rng.randf_range(5.0, 11.0)
		})
	for i in range(5):
		var a: float = TAU * i / 5.0 + 0.4
		course.scenery.append({
			"kind": "pyramid", "pos": Vector3(cos(a) * 250.0 + 40.0, WATER_Y, sin(a) * 250.0 - 90.0),
			"size": rng.randf_range(40.0, 70.0), "anchored": true
		})
