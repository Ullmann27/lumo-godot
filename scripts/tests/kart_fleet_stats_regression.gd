extends SceneTree
## Flotte, Werte und Tuning: vierzehn Karts mit unterscheidbaren Werten, Comet neutral, Freischalten
## über Fortschrittssterne, Werkstatt (Kauf, Rückgabe, Speichern, beschädigte Dateien, Sterne-Obergrenze)
## und echte Wirkung in der Fahrphysik (Tempo, Beschleunigung, Bremsweg, Lenken, Turbo-Dauer).

const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const GAME = "res://scenes/games/kart_island.tscn"
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _check_fleet() -> void:
	var ids: Array[String] = FLEET.ids()
	assert(ids.size() == 14, "Vierzehn Karts in der Flotte")
	assert(ids.has("comet") and ids.has("glider") and ids.has("turbo"), "Alte Kart-Kennungen bleiben gültig")
	for id in FLEET.IDS:
		assert(ids.has(id), "Profil-Design %s ist auswählbar" % id)
	assert(ids.size() == ids.duplicate().size() and _unique(ids), "Kennungen sind eindeutig")
	var last_unlock: int = -1
	for item in FLEET.KARTS:
		assert(int(item.unlock) >= last_unlock, "Freischaltung steigt von Kart zu Kart")
		last_unlock = int(item.unlock)
		var total: float = 0.0
		for key in FLEET.STATS:
			var value: float = float(item.stats[key])
			assert(value >= 0.0 and value <= 10.0, "%s %s liegt zwischen 0 und 10" % [item.id, key])
			total += value
		assert(total >= 30.0 and total <= 41.0, "%s: Summe der Werte ist ausgewogen (%d)" % [item.id, total])
		assert(not str(item.name).is_empty() and not str(item.description).is_empty() and not str(item.role).is_empty())
		assert(item.has("speed") and item.has("turn") and item.has("accel"), "Altbestand-Faktoren sind gesetzt")
	assert(int(FLEET.entry("comet").unlock) == 0, "Comet ist von Anfang an da")
	var neutral: Dictionary = FLEET.multipliers(FLEET.base_stats("comet"), FLEET.entry("comet").traits)
	for key in ["speed", "accel", "brake", "turn", "grip", "boost_power", "boost_time"]:
		assert(is_equal_approx(float(neutral[key]), 1.0), "Comet ist neutral: %s = 1,0" % key)
	assert(is_equal_approx(float(neutral.offroad), 0.54) and is_equal_approx(float(neutral.stability), 0.45), "Comet fährt wie bisher")
	# Jedes Kart ist in etwas wirklich besser als Comet und in etwas schlechter (außer dem Champion).
	for item in FLEET.KARTS:
		if item.id == "comet":
			continue
		var better: int = 0
		var worse: int = 0
		for key in FLEET.STATS:
			var delta: float = float(item.stats[key]) - float(FLEET.entry("comet").stats[key])
			if delta >= 2.0:
				better += 1
			elif delta <= -1.0:
				worse += 1
		assert(better >= 1, "%s hat eine echte Stärke" % item.id)
		if item.id != "stella" and item.id != "phantom" and item.id != "terra":
			assert(worse >= 1, "%s hat eine echte Schwäche" % item.id)
	assert(_is_best("turbo", "speed") and _is_best("stella", "speed"), "Aurora GT und Stella gehören zu den Schnellsten")
	assert(_is_best("blitz", "accel"), "Blitz beschleunigt am besten")
	assert(_best("brake") == "koloss", "Koloss bremst am besten")
	assert(_is_best("glider", "handling"), "Glider lenkt am besten")
	assert(float(FLEET.entry("terra").traits.offroad) > 0.7, "Terra bleibt abseits der Straße schnell")
	assert(float(FLEET.entry("koloss").traits.stability) > 0.6, "Koloss steckt Treffer weg")
	assert(CATALOG.entry(CATALOG.KARTS, "gibt_es_nicht").id == "comet", "Unbekanntes Kart wird zu Comet")
	assert(CATALOG.KARTS.size() == 14)
	var glider: Dictionary = CATALOG.entry(CATALOG.KARTS, "glider")
	assert(CATALOG.unlocked(glider, 8, []) and not CATALOG.unlocked(glider, 7, []), "Glider ab 8 Sternen")
	assert(CATALOG.unlocked(CATALOG.entry(CATALOG.KARTS, "stella"), 0, ["stella"]), "Einmal Freigeschaltetes bleibt offen")


func _is_best(id: String, stat: String) -> bool:
	return is_equal_approx(float(FLEET.entry(id).stats[stat]), float(FLEET.entry(_best(stat)).stats[stat]))


func _best(stat: String) -> String:
	var best: String = ""
	var value: float = -1.0
	for item in FLEET.KARTS:
		if float(item.stats[stat]) > value:
			value = float(item.stats[stat])
			best = str(item.id)
	return best


func _unique(list: Array) -> bool:
	var seen: Dictionary = {}
	for entry in list:
		if seen.has(entry):
			return false
		seen[entry] = true
	return true


func _check_tuning() -> void:
	var child: String = "fleet_test_child"
	DirAccess.remove_absolute(TUNING.path_for(child))
	var shop = TUNING.new(child, 40)
	assert(shop.available() == 40 and shop.spent() == 0, "Start: 40 Sterne frei")
	assert(TUNING.path_for("a/b ä") == "user://kart_workshop_a_b__.cfg", "Dateiname wird bereinigt")
	# Stufen kosten 4, 8, 12, 18, 26.
	assert(shop.next_cost("comet", "motor") == 4)
	assert(shop.upgrade("comet", "motor") and shop.level("comet", "motor") == 1)
	assert(shop.available() == 36)
	assert(shop.upgrade("comet", "motor") and shop.upgrade("comet", "motor"))
	assert(shop.spent() == 24 and shop.available() == 16, "Stufe 1–3 kosten 24 Sterne")
	assert(shop.next_cost("comet", "motor") == 18 and not shop.can_upgrade("comet", "motor"), "Stufe 4 kostet 18, mit 16 Sternen zu teuer")
	assert(not shop.upgrade("comet", "motor") and shop.level("comet", "motor") == 3, "Zu teuer: nichts passiert")
	var motor: int = 3
	# Werte wirken: Motor +0,4 Tempo je Stufe.
	var stats: Dictionary = shop.stats("comet")
	assert(is_equal_approx(float(stats.speed), 6.0 + 0.4 * float(motor)), "Motor erhöht das Tempo")
	assert(is_equal_approx(float(stats.accel), 6.0 + 0.2 * float(motor)))
	assert(is_equal_approx(float(stats.brake), 6.0), "Andere Werte bleiben")
	assert(float(shop.multipliers("comet").speed) > 1.0, "Faktor steigt mit Tuning")
	assert(is_equal_approx(float(shop.multipliers("turbo").speed), 1.0 + 3.0 * 0.03), "Andere Karts bleiben unberührt")
	# Speichern und Neuladen.
	var again = TUNING.new(child, 0)
	assert(again.level("comet", "motor") == motor, "Stufen bleiben gespeichert")
	assert(again.lifetime_stars >= 40, "Die Sterne-Obergrenze bleibt gespeichert")
	assert(again.spent() == shop.spent() and again.available() == shop.available())
	# Die Obergrenze sinkt nie, auch wenn die App einmal weniger meldet.
	again.report_lifetime(5)
	assert(again.lifetime_stars >= 40)
	again.report_lifetime(100)
	assert(again.lifetime_stars == 100 and again.available() == 100 - again.spent())
	# Rückgabe: alle Sterne zurück, Aussehen bleibt.
	var paid: int = again.spent()
	assert(again.refund("comet") == paid and again.spent() == 0 and again.level("comet", "motor") == 0)
	assert(again.refund("comet") == 0, "Zweite Rückgabe bringt nichts")
	# Teile haben eine Höchststufe.
	again.report_lifetime(1000)
	for index in range(TUNING.MAX_LEVEL):
		assert(again.upgrade("glider", "reifen"))
	assert(not again.upgrade("glider", "reifen") and again.next_cost("glider", "reifen") == -1, "Höchststufe 5")
	assert(float(again.stats("glider").handling) == minf(12.0, 9.0 + 0.4 * 5.0), "Handling begrenzt auf die Skala")
	assert(again.spent() == TUNING.cost_to_reach(5) and TUNING.cost_to_reach(5) == 68)
	# Werte überschreiten nie 12.
	for part in TUNING.PARTS:
		for index in range(TUNING.MAX_LEVEL):
			again.upgrade("stella", str(part.id))
	for key in FLEET.STATS:
		assert(float(again.stats("stella")[key]) <= 12.0, "Skala endet bei 12")
	# Aussehen: kaufen, besitzen, wählen, kostenlose Standardwahl.
	var before: int = again.available()
	assert(again.chosen("comet", "paint") == "werk" and again.has_option("paint", "werk"))
	assert(not again.choose("comet", "paint", "feuer"), "Nicht gekauft: nicht wählbar")
	assert(again.buy_option("paint", "feuer") and again.available() == before - 6)
	assert(not again.buy_option("paint", "feuer"), "Nicht doppelt kaufen")
	assert(again.choose("comet", "paint", "feuer") and again.chosen("comet", "paint") == "feuer")
	assert(again.chosen("glider", "paint") == "werk", "Aussehen gilt je Kart")
	assert(not again.choose("comet", "paint", "gibt_es_nicht"))
	var look: Dictionary = again.look("comet")
	assert(look.paint == Color("b3202a") and look.has("trim") and look.has("accent") and look.has("neon") and look.has("rim"))
	assert(again.look("glider").paint == FLEET.entry("glider").look.paint, "Werksfarbe je Kart")
	var reloaded = TUNING.new(child, 0)
	assert(reloaded.chosen("comet", "paint") == "feuer" and reloaded.owned.has("paint:feuer"), "Aussehen bleibt gespeichert")
	assert(reloaded.refund("comet") == 0 and reloaded.chosen("comet", "paint") == "feuer", "Rückgabe lässt das Aussehen")
	# Beschädigte oder manipulierte Datei: nur gültige Werte kommen durch, ausgegeben wird neu gerechnet.
	var bad := ConfigFile.new()
	bad.set_value("kart_comet", "motor", 99)
	bad.set_value("kart_comet", "bremsen", -4)
	bad.set_value("kart_comet", "paint", "hacker")
	bad.set_value("kart_unbekannt", "motor", 3)
	bad.set_value("owned", "items", ["paint:feuer", "paint:feuer", "paint:nix", "kaputt", "rims:gold"])
	bad.set_value("meta", "lifetime", 77)
	bad.save(TUNING.path_for(child))
	var damaged = TUNING.new(child, 0)
	assert(damaged.level("comet", "motor") == 5 and damaged.level("comet", "bremsen") == 0, "Stufen werden begrenzt")
	assert(damaged.chosen("comet", "paint") == "werk", "Unbekanntes Aussehen wird zu Werk")
	assert(damaged.owned.size() == 2 and damaged.owned.has("paint:feuer") and damaged.owned.has("rims:gold"), "Nur echte Einträge")
	assert(damaged.spent() == TUNING.cost_to_reach(5) + 6 + 8, "Ausgaben werden aus den Stufen berechnet")
	assert(damaged.lifetime_stars == 77 and damaged.available() == maxi(0, 77 - damaged.spent()))
	var broken := FileAccess.open(TUNING.path_for(child), FileAccess.WRITE)
	broken.store_string("das ist keine Konfiguration [[[")
	broken.close()
	var empty = TUNING.new(child, 3)
	assert(empty.spent() == 0 and empty.available() == 3, "Kaputte Datei: sauberer Neustart")
	# Kinder getrennt.
	var other = TUNING.new(child + "_zwei", 0)
	assert(other.spent() == 0 and TUNING.path_for(child) != TUNING.path_for(child + "_zwei"))
	DirAccess.remove_absolute(TUNING.path_for(child))
	DirAccess.remove_absolute(TUNING.path_for(child + "_zwei"))


func _start(kart: String) -> void:
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": kart, "track": "sonnenhafen", "difficulty": "flott"})
	game.countdown = 0
	game.racing = true
	await process_frame


func _steer_towards(target: Vector3) -> void:
	var direction: Vector3 = target - game.player.position
	var heading: float = atan2(-direction.x, -direction.z)
	game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)


func _face(heading: float, speed: float) -> void:
	game.player_heading = heading
	game.speed = speed
	game.physical_velocity = Vector3(-sin(heading), 0, -cos(heading)) * speed


## Fährt 4,5 Sekunden mit Gas und gibt Tempo und Strecke zurück.
func _run_top_speed(kart: String) -> Dictionary:
	await _start(kart)
	game.gas_held = true
	var start_distance: float = game.distance
	var reached_at: float = -1.0
	for frame in range(270):
		# Turbo-Platten auf der Strecke würden die Messung verfälschen.
		game.boost_time = 0.0
		_steer_towards(game.world.position_at(game.previous_road_distance + 12.0))
		game._physics_process(STEP)
		if reached_at < 0.0 and game.speed >= 15.0:
			reached_at = float(frame) * STEP
	return {"speed": game.speed, "gain": game.distance - start_distance, "t15": reached_at}


func _run_brake(kart: String) -> float:
	await _start(kart)
	game.player.transform = game.world.reset_transform(game.track_length * 0.05)
	game.previous_road_distance = game.track_length * 0.05
	game.distance = game.previous_road_distance
	_face(game._heading(game.previous_road_distance), 20.0)
	game.gas_held = false
	game.auto_gas = false
	var start: float = game.distance
	game.control_brake = 1.0
	for frame in range(420):
		game.boost_time = 0.0
		_steer_towards(game.world.position_at(game.previous_road_distance + 12.0))
		game._physics_process(STEP)
		if game.speed < 0.5:
			break
	game.control_brake = 0.0
	return game.distance - start


func _run_turn(kart: String) -> float:
	await _start(kart)
	var d: float = game.track_length * 0.05
	game.player.transform = game.world.reset_transform(d)
	game.previous_road_distance = d
	game.distance = d
	_face(game._heading(d), 16.0)
	game.gas_held = true
	var start_heading: float = game.player_heading
	game.steering = 1.0
	for frame in range(45):
		game.boost_time = 0.0
		game.steering = 1.0
		game._physics_process(STEP)
	return absf(angle_difference(start_heading, game.player_heading))


func _round(source: Dictionary, key: String) -> Dictionary:
	var result: Dictionary = {}
	for kart in source:
		result[kart] = snappedf(float(source[kart][key]), 0.01)
	return result


func _check_physics() -> void:
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	game = load(GAME).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.workshop = TUNING.new("fleet_physics_test", 0)
	game.workshop.save_enabled = false
	var speeds: Dictionary = {}
	for kart in ["comet", "glider", "turbo", "blitz", "koloss"]:
		speeds[kart] = await _run_top_speed(kart)
	assert(float(speeds.turbo.speed) > float(speeds.comet.speed) + 1.2, "Aurora GT wird schneller (%.1f gegen %.1f)" % [speeds.turbo.speed, speeds.comet.speed])
	assert(float(speeds.glider.speed) < float(speeds.comet.speed) - 0.2, "Glider ist langsamer")
	assert(absf(float(speeds.comet.speed) - 20.5) < 0.6, "Comet fährt unverändert 20,5 m/s (%.2f)" % float(speeds.comet.speed))
	assert(float(speeds.blitz.t15) < float(speeds.comet.t15) - 0.1, "Blitz erreicht Tempo früher (%.2f gegen %.2f s)" % [speeds.blitz.t15, speeds.comet.t15])
	assert(float(speeds.koloss.t15) > float(speeds.comet.t15) + 0.1, "Koloss braucht länger")
	var stops: Dictionary = {}
	for kart in ["comet", "turbo", "koloss"]:
		stops[kart] = await _run_brake(kart)
	assert(float(stops.koloss) < float(stops.comet) - 1.0, "Koloss bremst kürzer (%.1f gegen %.1f m)" % [stops.koloss, stops.comet])
	assert(float(stops.turbo) > float(stops.comet) + 0.4, "Aurora GT bremst länger (%.1f gegen %.1f m)" % [stops.turbo, stops.comet])
	var turns: Dictionary = {}
	for kart in ["comet", "glider", "turbo"]:
		turns[kart] = await _run_turn(kart)
	print("[KartFleetStats] gemessen: Endtempo ", _round(speeds, "speed"), " · Zeit bis 15 m/s ", _round(speeds, "t15"), " · Bremsweg ", stops, " · Lenken ", turns)
	assert(float(turns.glider) > float(turns.comet) * 1.08, "Glider lenkt enger (%.2f gegen %.2f rad)" % [turns.glider, turns.comet])
	assert(float(turns.turbo) < float(turns.comet) * 0.99, "Aurora GT lenkt weiter")
	# Turbo-Dauer wächst mit dem Turbo-Wert.
	await _start("comet")
	assert(is_equal_approx(game._boost_for(2.0), 2.0), "Comet: Boost-Dauer wie bisher")
	await _start("blitz")
	assert(game._boost_for(2.0) > 2.15, "Blitz: längerer Boost")
	# Tuning wirkt in der Fahrt: Motor auf Stufe 5.
	game.workshop.report_lifetime(500)
	var before: Dictionary = await _run_top_speed("comet")
	for index in range(5):
		game.workshop.upgrade("comet", "motor")
	var tuned: Dictionary = await _run_top_speed("comet")
	assert(float(tuned.speed) > float(before.speed) + 0.8, "Motor-Tuning macht schneller (%.2f gegen %.2f)" % [tuned.speed, before.speed])
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_preferences.cfg")


func _run() -> void:
	_check_fleet()
	_check_tuning()
	await _check_physics()
	# Freigegebene Rennszenen, Viewports und Audio-Wiedergaben vor dem Beenden ganz abbauen lassen.
	for frame in range(6):
		await process_frame
	await create_timer(0.25).timeout
	print("[KartFleetStats] PASS: vierzehn Karts mit unterscheidbaren Werten, Comet neutral, Werkstatt (Kauf, Rückgabe, Speichern, Schutz vor kaputten Dateien) und Wirkung bei Tempo, Beschleunigung, Bremsen, Lenken und Turbo")
	quit(0)
