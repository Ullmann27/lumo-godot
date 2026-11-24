extends Node3D
## Die gleiche sichtbare Schieberstellung und Torfolge gilt für das ganze Feld.

const ART_PATH := "res://scripts/games/kart_windwerk_art.gd"
const SLIDERS := [720.0, 810.0, 910.0]
const GATES := [2205.0, 2310.0, 2420.0]
const TARGETS := [-3.8, 3.8, -3.8]
const SYMBOLS := ["★", "◆", "●"]
const COLORS := [Color("ffd065"), Color("7fe5ff"), Color("e2a7ff")]
const LANE := 3.8
const SAFE := -4.3

var length := 3000.0
var sliders: Array[Node3D] = []
var gate_signs: Array[Label3D] = []
var lap_sign: Label3D
var shown_lap := -1
var scenery: Node3D
var whale_celebration_until := 0.0
var racers: Dictionary = {}
var player_reset := -1


static func slider_lane(index: int, seconds: float) -> float:
	return 1.95 + 2.48 * sin(seconds * 1.25 + float(index) * 2.0)


## Frei platzierbare Ringe wandern vor bzw. hinter den Versuch. Unterschiedliche
## Ausgangsdistanzen bleiben auch nach dem Verschieben unterscheidbar.
static func clear_distance(at: float, trials: Array) -> float:
	for trial: Dictionary in trials:
		var sector := Vector2(float(trial.start), float(trial.end))
		if at >= sector.x and at <= sector.y:
			var middle := (sector.x + sector.y) * 0.5
			return sector.x - 18.0 - (middle - at) * .25 if at < middle else sector.y + 18.0 + (at - middle) * .25
	return at


## In lap two the route marshal calls for the other painted symbol. Every
## racer follows their own lap; signs facing the local camera follow the child.
static func target_lane(index: int, lap: int) -> float:
	return float(TARGETS[index]) if lap % 2 == 0 else -float(TARGETS[index])


func set_sign_lap(lap: int) -> void:
	if lap == shown_lap:
		return
	shown_lap = lap
	lap_sign.text = "FOLGE DEM ZEICHEN" if lap % 2 == 0 else "NEUE WINDZEICHEN"
	for i in gate_signs.size():
		var symbol := (i + lap % 2) % SYMBOLS.size()
		gate_signs[i].text = SYMBOLS[symbol]
		gate_signs[i].modulate = COLORS[symbol]


func setup(world) -> void:
	length = world.length
	scenery = world.get_node_or_null("WindwerkKulissen")
	var art = load(ART_PATH)
	for i in SLIDERS.size():
		var line := _anchor(world, SLIDERS[i], "Schieber%d" % i)
		var slider: Node3D = art.module("slider")
		line.add_child(slider)
		slider.position.x = slider_lane(i, 0)
		sliders.append(slider)
		_mark(line, Vector3(SAFE, .045, 0), "✓", Color("8fe4b9"), true)
		_mark(line, Vector3(LANE, .045, 0), "↑", Color("ffd065"), true)
	var sign := _anchor(world, 600, "Weichenweg")
	sign.add_child(art.module("signal_gate"))
	_mark(sign, Vector3(-3.75, 6.8, 0.45), "SICHER", Color("8fe4b9"))
	_mark(sign, Vector3(3.75, 6.8, 0.45), "TURBO", Color("ffd065"))
	var instruction := _anchor(world, 2090, "Windzeichen")
	instruction.add_child(art.module("signal_gate"))
	lap_sign = _mark(instruction, Vector3(0, 6.9, .5), "FOLGE DEM ZEICHEN", Color("ffeada"))
	for i in GATES.size():
		var gate := _anchor(world, GATES[i], "Windtor%d" % i)
		gate.add_child(art.module("signal_gate"))
		gate_signs.append(_mark(gate, Vector3(0, 7.0, 0.6), SYMBOLS[i], COLORS[i]))
		for side: float in [-LANE, LANE]:
			var symbol := i if is_equal_approx(side, TARGETS[i]) else (i + 1) % SYMBOLS.size()
			for offset: float in [0.0, 16.0, 33.0]:
				var stripe := _anchor(world, GATES[i] - offset, "Bodensignal")
				_mark(stripe, Vector3(side, 0.045, 0), SYMBOLS[symbol], COLORS[symbol], true)


func _anchor(world, at: float, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.transform = Transform3D(world.frame(at), world.position_at(at))
	add_child(node)
	return node


func _mark(parent: Node3D, at: Vector3, text: String, color: Color, flat: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 108
	label.modulate = color
	label.outline_modulate = Color("142c38")
	label.outline_size = 14
	label.pixel_size = 0.026 if text.length() == 1 else 0.009
	label.position = at
	label.double_sided = false
	label.visibility_range_end = 145.0
	if flat:
		label.rotation.x = -PI * 0.5
	parent.add_child(label)
	return label


## Verkehr und Kurvenplanung dürfen diese Wunschlinie weiterhin anpassen.
func rival_lane(distance: float, speed: float, seconds: float, driver: int, preferred: float) -> float:
	var d := fposmod(distance, length)
	for i in SLIDERS.size():
		var ahead: float = SLIDERS[i] - d
		if ahead >= 0 and ahead <= 67:
			var arrival := seconds + ahead / maxf(10.0, speed)
			return LANE if driver % 2 == 1 and absf(slider_lane(i, arrival) - LANE) > 2.45 else SAFE
	for i in GATES.size():
		var ahead: float = GATES[i] - d
		if ahead >= 0 and ahead <= 73:
			return 0.0 if driver % 4 == 0 else target_lane(i, floori(distance / length))
	return preferred


## Ein Ereignis je Linie, Fahrer und Runde. Rückwärtsfahren, Wiedereinstieg und
## weite Positionssprünge lösen am übersprungenen Tor nichts aus.
func cross(driver: int, distance: float, lane: float, seconds: float, dt: float, speed: float, flying: bool = false) -> String:
	var lap := floori(distance / length)
	if racers.has(driver) and lap < int(racers[driver].lap):
		return ""
	if not racers.has(driver) or int(racers[driver].lap) < lap:
		racers[driver] = {"lap": lap, "distance": distance, "lane": lane, "used": 0, "combo": 0, "slow_until": 0.0}
		return ""
	var state: Dictionary = racers[driver]
	var before := float(state.distance)
	var previous_lane := float(state.lane)
	state.distance = distance
	state.lane = lane
	var step := distance - before
	if step <= 0.0 or step > maxf(9.0, absf(speed) * dt * 2.0 + 3.0):
		return ""
	for i in SLIDERS.size() + GATES.size():
		var plate := i < SLIDERS.size()
		var j := i if plate else i - SLIDERS.size()
		var at: float = lap * length + (SLIDERS[j] if plate else GATES[j])
		if before >= at or distance < at or (int(state.used) & (1 << i)) != 0:
			continue
		state.used = int(state.used) | (1 << i)
		var t := (at - before) / step
		var x := lerpf(previous_lane, lane, t)
		if plate:
			if not flying and absf(x - slider_lane(j, seconds - dt * (1.0 - t))) <= 2.0:
				state.slow_until = seconds + 0.60
				return "bump"
			return "draft" if absf(x - LANE) <= 1.7 else "safe"
		if absf(x - target_lane(j, lap)) <= 1.72:
			state.combo = int(state.combo) + 1
			return "combo" if int(state.combo) == GATES.size() else "gate"
		state.combo = 0
		return "neutral"
	return ""


func speed_factor(driver: int, seconds: float) -> float:
	if racers.has(driver) and seconds < float(racers[driver].slow_until):
		return 0.85
	return 1.0


func advance(game, dt: float) -> void:
	set_sign_lap(maxi(0, floori(game.distance / length)))
	if is_instance_valid(scenery):
		scenery.update_wind_whales(game.elapsed, whale_celebration_until - game.elapsed, game.reduced_motion)
	for i in sliders.size():
		sliders[i].position.x = slider_lane(i, game.elapsed)
	if player_reset != game.reset_count:
		# Eine Bergung kann vor den Schieber zurücksetzen. Bereits ausgelöste
		# Linien bleiben verbraucht, die unterbrochene Torfolge endet.
		if racers.has(-1):
			racers[-1].distance = game.distance
			racers[-1].lane = game.lane
			racers[-1].combo = 0
			racers[-1].slow_until = 0.0
		player_reset = game.reset_count
	for driver in range(-1, game.opponents.size()):
		var child := driver == -1
		var distance: float = game.distance if child else game.opponent_distances[driver]
		var lane: float = game.lane if child else game.opponent_lanes[driver]
		var speed: float = game.speed if child else game.opponents[driver].motion_speed
		var airborne: bool = game.airborne if child else false
		if not child and game.opponents[driver].has_meta(&"lumo_ballistic_flight"):
			var flight = game.opponents[driver].get_meta(&"lumo_ballistic_flight")
			airborne = flight != null and flight.active
		var event := cross(driver, distance, lane, game.elapsed, dt, speed, airborne)
		if event.is_empty():
			continue
		var boost := 0.0
		var message := ""
		match event:
			"bump":
				message = "Schieber berührt"
			"draft":
				boost = 0.85
				message = "Windschub!"
			"gate":
				boost = 0.40
				message = "Windzeichen getroffen!"
			"combo":
				boost = 1.65
				message = "Drei Windzeichen · großer Windschub!"
				if child:
					whale_celebration_until = game.elapsed + 2.1
		if child and not message.is_empty():
			game.message.text = message
		if boost > 0.0:
			if child:
				game.boost_time = maxf(game.boost_time, boost)
				game._sound_effect("boost")
			else:
				game.opponent_boost_times[driver] = maxf(game.opponent_boost_times[driver], boost)
