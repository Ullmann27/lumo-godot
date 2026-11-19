extends SceneTree
## Erweiterte Lumo-Kart-Items im echten Rennen (headless): Wirkung, Konter (Schild),
## Schonzeit, Sturzstellen-Sperre, KI-Einsatz und -Reaktion, Speichern/Fortsetzen.
## Usage: godot --headless --path . --script res://scripts/tests/kart_item_ext_regression.gd \
##   -- [tracks=sonnenhafen,winter_sprint,jungle_emerald_3600] [items=thunder_star,...]
const STEP: float = 1.0 / 60.0
const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const REGISTRY = preload("res://scripts/games/kart_items/ext/kart_item_ext_registry.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const ALL_ITEMS: Array[String] = [
	"thunder_star", "frost_crystal", "fire_meteor", "star_fortress", "whirlwind"
]
var game
var ext
var checks: int = 0
var failures: Array[String] = []
var track: String = ""
var safe_d: float = 0.0
var items: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append("[%s] %s" % [track, label])
		push_error("[KartItemExt] FAIL [%s]: %s" % [track, label])


func _start(track_id: String) -> void:
	track = track_id
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track_id,
			"difficulty": "normal"
		}
	)
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame
	ext = game.item_ext
	safe_d = _find_safe(game.track_length * 0.18)


## Strecke absuchen: Stelle, an der Kind und Rivalen 0..40 m davor sicher fahren.
func _find_safe(from: float) -> float:
	var d: float = from
	for _i in range(400):
		var ok: bool = true
		for gap in [-20.0, 0.0, 20.0, 40.0, 60.0, 80.0, 100.0]:
			if not ext.safe_at(d + gap):
				ok = false
				break
		if ok:
			return d
		d += 7.0
	return from


func _place(at: float, offsets: Array) -> void:
	game.distance = at
	game.previous_road_distance = fposmod(at, game.track_length)
	game.lane = float(offsets[0][1]) if offsets.size() > 0 and offsets[0].size() > 2 else 0.0
	game.player.transform = game.world.reset_transform(fposmod(at, game.track_length), game.lane)
	game.player_heading = game._heading(fposmod(at, game.track_length))
	for i in range(game.opponents.size()):
		var entry: Array = offsets[i + 1] if i + 1 < offsets.size() else [-80.0 - i * 6.0, 0.0]
		var d: float = at + float(entry[0])
		game.opponent_distances[i] = d
		game.opponent_lanes[i] = float(entry[1])
		game.opponents[i].transform = game.world.reset_transform(
			fposmod(d, game.track_length), float(entry[1])
		)
		game.opponent_headings[i] = game._heading(fposmod(d, game.track_length))


## Karts bleiben fest, nur die Item-Ebene läuft (Physik ist im Test aus).
func _tick(seconds: float, at: float, offsets: Array, keep_pushes: bool = false) -> void:
	for _f in range(maxi(1, int(round(seconds / STEP)))):
		if not keep_pushes:
			_place(at, offsets)
		game.shield_time = maxf(0.0, game.shield_time - STEP)
		for i in game.opponent_shield_times.size():
			game.opponent_shield_times[i] = maxf(0.0, game.opponent_shield_times[i] - STEP)
		game._update_gameplay_layer(STEP)
		game.shield_visual.advance(STEP, game.shield_time)


func _fresh() -> void:
	game._reset_gameplay_layer()
	game.shield_time = 0.0
	game.player_grace_time = 0.0
	game.item = ""
	game.item_charges = 0
	for i in range(game.opponents.size()):
		game.opponent_shield_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 0.0
		game.opponent_aurora_times[i] = 0.0


func _player_use(id: String) -> void:
	game._grant_item(id)
	game.item_roulette_time = 0.0
	game._use_item()


# --- Katalog -------------------------------------------------------------------------------


func _test_catalog() -> void:
	for id in items:
		var row: Dictionary = CATALOG.entry(id)
		_check(not row.is_empty(), "%s steht im Katalog" % id)
		if row.is_empty():
			continue
		_check(
			REGISTRY.has_behaviour(str(row.behaviour)), "%s hat ein registriertes Verhalten" % id
		)
		_check(REGISTRY.script_for(str(row.behaviour)) != null, "%s hat eine Verhaltensdatei" % id)
		_check(ResourceLoader.exists(REGISTRY.icon_path(id)), "%s hat ein HUD-Symbol" % id)
		_check(float(row.weights[0]) <= 1.0, "%s: Spitzenreiter zieht es selten" % id)
		for sound in row.get("sounds", []):
			_check(
				(
					REGISTRY.has_sound(str(sound))
					and ResourceLoader.exists("res://assets/audio/kart/items/%s.ogg" % sound)
				),
				"%s: Ton %s vorhanden" % [id, sound]
			)
	for place in range(1, 7):
		var total: float = 0.0
		for value in CATALOG.odds(place).values():
			total += value
		_check(
			absf(total - 1.0) < 0.001, "Wahrscheinlichkeiten Platz %d summieren sich zu 1" % place
		)


# --- Donnerstern ---------------------------------------------------------------------------


func _test_thunder() -> void:
	var at: float = safe_d
	var ahead: Array = [[0.0, 0.0, 0.0], [16.0, 1.0]]
	# Wirkung: Blitz von oben, kurze kontrollierte Temporeduktion, Schonzeit danach.
	_fresh()
	_place(at, ahead)
	_player_use("thunder_star")
	_check(game.item.is_empty(), "Donnerstern: Item verbraucht")
	var effect = ext.effect("lightning_strike")
	_check(
		effect.active.size() == 1 and int(effect.active[0].target) == 0,
		"Donnerstern zielt auf den nahen Rivalen vorn"
	)
	var warn_seconds: float = ext.incoming_for(0)
	_check(
		warn_seconds > 0.8 and warn_seconds < 1.3,
		"Ziel hat eine Vorwarnzeit (%.2f s)" % warn_seconds
	)
	await _tick(0.6, at, ahead)
	var star_up: bool = false
	var rig: Node3D = effect.active[0].get("rig") if not effect.active.is_empty() else null
	if is_instance_valid(rig):
		star_up = (
			(rig.get_node("Star") as Node3D).visible or (rig.get_node("Cloud") as Node3D).visible
		)
	_check(star_up, "Stern/Wolke sichtbar vor dem Einschlag")
	var cloud_ok: bool = false
	await _tick(0.3, at, ahead)
	if is_instance_valid(rig):
		var cloud: Node3D = rig.get_node("Cloud")
		var above: Vector3 = cloud.global_position - game.opponents[0].global_position
		cloud_ok = cloud.visible and above.y > 3.0 and Vector2(above.x, above.z).length() < 1.5
	_check(cloud_ok, "Gewitterwolke steht über dem Ziel (nicht irgendwo)")
	var slowest: float = 1.0
	var bolt_seen: bool = false
	for _f in range(60):
		await _tick(STEP, at, ahead)
		slowest = minf(slowest, ext.speed_factor(0))
		if (
			is_instance_valid(rig)
			and (
				((rig.get_node("Bolt") as MeshInstance3D).mesh as ImmediateMesh).get_surface_count()
				> 0
			)
		):
			bolt_seen = true
	_check(bolt_seen, "Blitz-Geometrie wurde gezeichnet")
	_check(slowest < 0.72 and slowest > 0.6, "Treffer: kurz langsamer, kein Stopp (%.2f)" % slowest)
	_check(game.opponent_grace_times[0] > 0.0, "Treffer setzt die Schonzeit")
	_check(game.opponent_spin_times[0] <= 0.0, "kein Dreher, kein hartes Stoppen")
	await _tick(1.6, at, ahead)
	_check(is_equal_approx(ext.speed_factor(0), 1.0), "Tempo kehrt vollständig zurück")
	_check(effect.active.is_empty(), "Effekt räumt sich nach dem Abklingen auf")
	# Schonzeit: zweiter Donnerstern direkt danach trifft nicht.
	game.opponent_grace_times[0] = 2.0
	_place(at, ahead)
	game._grant_item("thunder_star")
	game._use_item()
	_check(game.item == "thunder_star", "Ziel in Schonzeit wird nicht anvisiert (Item bleibt)")
	# Konter: Schild wehrt ab.
	_fresh()
	game.opponent_shield_times[0] = 5.0
	_place(at, ahead)
	_player_use("thunder_star")
	await _tick(1.4, at, ahead)
	_check(
		int(effect.stats.blocked) >= 1 and is_equal_approx(ext.speed_factor(0), 1.0),
		"Schild wehrt den Blitz ab"
	)
	_check(game.opponent_grace_times[0] <= 0.0, "Abwehr setzt keine Schonzeit")
	# Kein Ziel: Item bleibt erhalten.
	_fresh()
	var far: Array = [
		[0.0, 0.0, 0.0], [-120.0, 0.0], [-130.0, 1.0], [-140.0, -1.0], [-150.0, 2.0], [-160.0, -2.0]
	]
	_place(at, far)
	game._grant_item("thunder_star")
	game._use_item()
	_check(
		game.item == "thunder_star" and effect.active.is_empty(),
		"ohne Ziel bleibt der Donnerstern im Knopf"
	)
	# KI: Rivale hinter dem Kind setzt ihn ein, Kind wird gewarnt und getroffen.
	_fresh()
	var behind: Array = [[0.0, 0.0, 0.0], [-14.0, 0.5], [-60.0, 1.0]]
	_place(at, behind)
	game.opponent_items[0] = "thunder_star"
	game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	_check(
		game.opponent_items[0].is_empty() and ext.incoming_for(-1) < INF,
		"KI setzt den Donnerstern gegen das Kind ein"
	)
	await _tick(0.2, at, behind)
	_check(game.player_warning > 0.3, "Kind sieht die Warnung (%.2f)" % game.player_warning)
	var child_slow: float = 1.0
	for _f in range(90):
		await _tick(STEP, at, behind)
		child_slow = minf(child_slow, ext.speed_factor(-1))
	_check(
		child_slow < 0.75 and game._gameplay_speed_factor() > 0.0,
		"Kind kurz langsamer, fährt weiter"
	)
	# Keine Trefferkette: zweiter Rivale darf das Kind direkt danach nicht angreifen.
	game.opponent_items[1] = "thunder_star"
	var behind2: Array = [[0.0, 0.0, 0.0], [-14.0, 0.5], [-12.0, -1.0]]
	_place(at, behind2)
	game.opponent_grace_times[0] = 0.0
	game.player_grace_time = 0.0
	game._rival_use_catalog_item(1, game.player.position - game.opponents[1].position)
	_check(
		game.opponent_items[1] == "thunder_star",
		"Kinderschutz: kein zweiter Angriff in der Schutzfrist"
	)
	# KI-Reaktion: Rivale mit Schild im Knopf schützt sich vor dem anfliegenden Blitz.
	_fresh()
	_place(at, ahead)
	game.opponent_items[0] = "shield"
	_player_use("thunder_star")
	for _f in range(80):
		_place(at, ahead)
		game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, STEP)
		await _tick(STEP, at, ahead)
	_check(
		game.opponent_items[0].is_empty() and int(effect.stats.blocked) >= 1,
		"KI hebt den Schild gegen den angekündigten Blitz"
	)
	# Speichern/Fortsetzen: laufender Blitz übersteht die Sitzung.
	_fresh()
	_place(at, ahead)
	_player_use("thunder_star")
	await _tick(0.4, at, ahead)
	game.abandoned = false
	game._save_session()
	var config := ConfigFile.new()
	_check(
		config.load(game.SESSION) == OK and config.has_section_key("race", "item_ext"),
		"Sitzung speichert den Item-Zustand"
	)
	ext.clear()
	_check(effect.active.is_empty(), "Zustand geleert")
	game._restore_item_continuity(config)
	_check(
		effect.active.size() == 1 and absf(float(effect.active[0].age) - 0.4) < 0.1,
		"laufender Donnerstern nach Fortsetzen wieder da"
	)
	await _tick(1.2, at, ahead)
	_check(
		int(effect.stats.hits) >= 1 and game.opponent_grace_times[0] > 0.0,
		"fortgesetzter Blitz schlägt korrekt ein"
	)


## Unsichere Stelle (Brückendeck, offene Kante oder Rampe) auf dieser Strecke, sonst -1.
func _find_unsafe() -> float:
	var best: float = -1.0
	var d: float = 30.0
	while d < game.track_length - 30.0:
		if PASSAGES.void_at(game.world, d):
			return d
		if best < 0.0 and (game.world.open_edge_side(d) != 0.0 or game.world.ramp_height(d) > 0.05):
			best = d
		d += 3.0
	return best


func _session_roundtrip(label: String) -> void:
	game.abandoned = false
	game._save_session()
	var config := ConfigFile.new()
	_check(
		config.load(game.SESSION) == OK and config.has_section_key("race", "item_ext"),
		label + ": gespeichert"
	)
	ext.clear()
	game._restore_item_continuity(config)


# --- Frostkristall -------------------------------------------------------------------------


func _test_frost() -> void:
	var at: float = safe_d
	var ahead: Array = [[0.0, 0.0, 0.0], [18.0, 0.8]]
	var effect = ext.effect("frost_capsule")
	_fresh()
	_place(at, ahead)
	_player_use("frost_crystal")
	_check(game.item.is_empty() and effect.active.size() == 1, "Frost: Kapsel fliegt")
	var flight: float = float(effect.active[0].flight)
	_check(flight > 0.4 and flight < 0.7, "Flugzeit aus echtem Abstand (%.2f s)" % flight)
	var min_turn: float = 1.0
	var min_grip: float = 1.0
	var ice_seen: bool = false
	for _f in range(int((flight + 0.4) / STEP)):
		await _tick(STEP, at, ahead)
		min_turn = minf(min_turn, ext.turn_factor(0))
		min_grip = minf(min_grip, ext.grip_factor(0))
		if not effect.active.is_empty() and is_instance_valid(effect.active[0].get("rig")):
			ice_seen = ice_seen or (effect.active[0].rig.get_node("Ice0") as Node3D).visible
	_check(min_turn < 0.62 and min_turn > 0.5, "Lenkung erschwert, nie blockiert (%.2f)" % min_turn)
	_check(min_grip < 0.6 and min_grip > 0.45, "Räder rutschen (Haftung %.2f)" % min_grip)
	_check(ice_seen, "Eis an den Rädern sichtbar")
	var wheel_ok: bool = false
	if not effect.active.is_empty() and is_instance_valid(effect.active[0].get("rig")):
		var ice: Node3D = effect.active[0].rig.get_node("Ice0")
		var wheels: Array = ext.wheel_points(0)
		wheel_ok = wheels.size() == 4 and ice.global_position.distance_to(wheels[0]) < 0.2
	_check(wheel_ok, "Eiskruste sitzt an der echten Radnabe")
	await _tick(1.8, at, ahead)
	_check(
		is_equal_approx(ext.turn_factor(0), 1.0) and effect.active.is_empty(),
		"Eis taut vollständig ab"
	)
	_check(game.opponent_grace_times[0] > 0.0, "Frost setzt Schonzeit")
	# Schild.
	_fresh()
	game.opponent_shield_times[0] = 5.0
	_place(at, ahead)
	_player_use("frost_crystal")
	await _tick(1.0, at, ahead)
	_check(
		int(effect.stats.blocked) >= 1 and is_equal_approx(ext.turn_factor(0), 1.0),
		"Schild hält das Eis ab"
	)
	# Sturzstellen-Sperre: Ziel an Brücke/Kante/Rampe -> kein Abwurf, Item bleibt.
	var unsafe: float = _find_unsafe()
	if unsafe >= 0.0:
		_fresh()
		var on_edge: Array = [[0.0, 0.0, 0.0], [15.0, 0.0]]
		_place(unsafe - 15.0, on_edge)
		game._grant_item("frost_crystal")
		game._use_item()
		_check(
			game.item == "frost_crystal" and effect.active.is_empty(),
			"kein Frost auf Ziel an Brücke/Kante/Rampe (%.0f m)" % unsafe
		)
		# Wird das Ziel während des Flugs unsicher, verpufft der Frost harmlos.
		_fresh()
		_place(at, ahead)
		_player_use("frost_crystal")
		await _tick(0.2, at, ahead)
		var moved: Array = [[0.0, 0.0, 0.0], [unsafe - at, 0.0]]
		await _tick(1.0, at, moved)
		_check(
			int(effect.stats.fizzled) >= 1 and is_equal_approx(ext.turn_factor(0), 1.0),
			"Frost verpufft, wenn das Ziel an die Kante kommt"
		)
		# KI: nicht gegen ein Ziel an der Kante.
		_fresh()
		var rival_unsafe: Array = [[0.0, 0.0, 0.0], [-14.0, 0.0]]
		_place(unsafe, rival_unsafe)
		game.opponent_items[0] = "frost_crystal"
		game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
		_check(
			game.opponent_items[0] == "frost_crystal",
			"KI wirft keinen Frost auf das Kind an der Kante"
		)
	else:
		print("[KartItemExt] %s: keine unsichere Stelle gefunden" % track)
	# KI gegen das Kind auf sicherer Fahrbahn.
	_fresh()
	var behind: Array = [[0.0, 0.0, 0.0], [-16.0, 0.4]]
	_place(at, behind)
	game.opponent_items[0] = "frost_crystal"
	game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	_check(game.opponent_items[0].is_empty(), "KI wirft den Frostkristall auf das Kind")
	await _tick(0.15, at, behind)
	_check(game.player_warning > 0.3, "Kind wird gewarnt")
	var child_turn: float = 1.0
	for _f in range(70):
		await _tick(STEP, at, behind)
		child_turn = minf(child_turn, ext.turn_factor(-1))
	_check(
		child_turn < 0.62 and child_turn > 0.5,
		"Kind lenkt schwerer, aber lenkt (%.2f)" % child_turn
	)
	# Speichern/Fortsetzen mitten im Flug.
	_fresh()
	_place(at, ahead)
	_player_use("frost_crystal")
	await _tick(0.25, at, ahead)
	await _session_roundtrip("Frost")
	_check(
		effect.active.size() == 1 and str(effect.active[0].result).is_empty(),
		"Kapsel fliegt nach Fortsetzen weiter"
	)
	await _tick(0.6, at, ahead)
	_check(ext.turn_factor(0) < 0.9, "fortgesetzte Kapsel friert das Ziel ein")


# --- Feuermeteor ---------------------------------------------------------------------------


func _test_meteor() -> void:
	var at: float = safe_d
	var ahead: Array = [[0.0, 0.0, 0.0], [15.0, 0.6]]
	var effect = ext.effect("fire_meteor")
	_fresh()
	_place(at, ahead)
	game.speed = 18.0
	_player_use("fire_meteor")
	_check(game.item.is_empty() and effect.active.size() == 1, "Meteor fliegt")
	var slowest: float = 1.0
	for _f in range(90):
		await _tick(STEP, at, ahead)
		slowest = minf(slowest, ext.speed_factor(0))
	_check(slowest < 0.65 and slowest > 0.55, "Treffer: kurze Tempoeinbuße (%.2f)" % slowest)
	_check(
		int(effect.stats.hits) == 1 and game.opponent_grace_times[0] > 0.0,
		"ein Treffer, Schonzeit gesetzt"
	)
	await _tick(1.2, at, ahead)
	_check(is_equal_approx(ext.speed_factor(0), 1.0), "Tempo zurück")
	# Kein Treffer -> Glutfeld auf sicherer Fahrbahn, wirkt einmal, glüht aus.
	_fresh()
	var empty: Array = [
		[0.0, 0.0, 0.0], [-90.0, 2.0], [-95.0, -2.0], [-100.0, 1.0], [-105.0, -1.0], [-110.0, 0.0]
	]
	_place(at, empty)
	game.speed = 18.0
	_player_use("fire_meteor")
	await _tick(1.8, at, empty)
	var field: Dictionary = effect.active[0] if not effect.active.is_empty() else {}
	_check(str(field.get("phase", "")) == "field", "ohne Treffer bleibt ein Glutfeld liegen")
	if not field.is_empty():
		_check(ext.safe_at(float(field.progress)), "Glutfeld liegt auf sicherer Fahrbahn")
		var wall: float = game._wall_lateral_at(fposmod(float(field.progress), game.track_length))
		_check(
			absf(float(field.lateral)) + 1.4 < wall,
			"neben dem Glutfeld bleibt Platz zum Vorbeifahren"
		)
		var through: Array = [[0.0, 0.0, 0.0], [float(field.progress) - at, float(field.lateral)]]
		await _tick(0.3, at, through)
		_check(
			ext.speed_factor(0) < 0.9 and int(effect.stats.get("field_hits", 0)) == 1,
			"Fahrt durchs Glutfeld bremst kurz"
		)
		game.opponent_grace_times[0] = 0.0
		await _tick(0.5, at, through)
		_check(int(effect.stats.get("field_hits", 0)) == 1, "Glutfeld wirkt je Fahrer nur einmal")
		await _tick(3.2, at, empty)
		_check(effect.active.is_empty(), "Glutfeld glüht aus und verschwindet")
	# Unsichere Landestelle: kein Glutfeld.
	var unsafe: float = _find_unsafe()
	if unsafe >= 0.0:
		_fresh()
		var entry := {
			"owner": -1,
			"target": -99,
			"item": "fire_meteor",
			"age": 1.7,
			"phase": "fly",
			"progress": unsafe,
			"lateral": 0.0,
			"speed": 40.0,
			"result": "",
			"field_age": 0.0,
			"touched": []
		}
		effect._land(entry)
		_check(
			str(entry.phase) == "done" and str(entry.result) == "fizzled",
			"kein Glutfeld an Brücke/Kante/Rampe"
		)
	# Schild.
	_fresh()
	game.opponent_shield_times[0] = 5.0
	_place(at, ahead)
	game.speed = 18.0
	_player_use("fire_meteor")
	await _tick(1.0, at, ahead)
	_check(
		int(effect.stats.blocked) >= 1 and is_equal_approx(ext.speed_factor(0), 1.0),
		"Schild lässt den Meteor abprallen"
	)
	# KI weicht einem anfliegenden Meteor aus und setzt ihn selbst ein.
	_fresh()
	_place(at, ahead)
	game.speed = 18.0
	_player_use("fire_meteor")
	await _tick(0.1, at, ahead)
	_check(
		absf(ext.rival_lane_bias(0)) > 0.3,
		"KI lenkt vom anfliegenden Meteor weg (%.2f)" % ext.rival_lane_bias(0)
	)
	_fresh()
	var behind: Array = [[0.0, 0.0, 0.0], [-14.0, 0.2]]
	_place(at, behind)
	game.opponent_items[0] = "fire_meteor"
	game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	_check(
		game.opponent_items[0].is_empty() and ext.incoming_for(-1) < INF,
		"KI schießt den Meteor auf das Kind"
	)
	# Speichern/Fortsetzen eines liegenden Glutfelds.
	_fresh()
	_place(at, empty)
	game.speed = 18.0
	_player_use("fire_meteor")
	await _tick(2.0, at, empty)
	await _session_roundtrip("Meteor")
	_check(
		effect.active.size() == 1 and str(effect.active[0].phase) == "field",
		"Glutfeld nach Fortsetzen noch da"
	)


# --- Sternenfestung ------------------------------------------------------------------------


func _test_fortress() -> void:
	var at: float = safe_d
	var near: Array = [[0.0, 0.0, 0.0], [14.0, 0.8]]
	var effect = ext.effect("fortress")
	_fresh()
	_place(at, near)
	_player_use("star_fortress")
	_check(
		is_equal_approx(game.shield_time, 12.0) and ext.shield_total(-1) == 12.0,
		"Festung: 12 s Schutz, HUD-Ring auf 12 s"
	)
	await _tick(0.6, at, near)
	var rig: Node3D = effect.active[0].get("rig") if not effect.active.is_empty() else null
	_check(
		(
			is_instance_valid(rig)
			and (rig.get_node("Pivot/Outer") as Node3D).visible
			and game.shield_visual.visible
		),
		"Doppelkuppel sichtbar (innen cyan, außen gold)"
	)
	await _tick(3.0, at, near)
	_check(absf(game.shield_time - 8.4) < 0.1, "Schilduhr läuft (%.2f)" % game.shield_time)
	_player_use("star_fortress")
	_check(
		game.shield_time <= 12.0 + 0.001 and effect.active.size() == 1,
		"erneutes Einsammeln: höchstens 12 s, kein Stapeln"
	)
	game.item = "shield"
	game._use_item()
	await _tick(STEP, at, near)
	_check(
		game.shield_time > 11.5,
		"Sternenschild während der Festung verkürzt nicht (%.2f)" % game.shield_time
	)
	# Angriff auf die Festung wird abgewehrt.
	# Kluge KI greift einen Geschützten nicht an (rival_wants) – hier direkt ausgelöst.
	var behind: Array = [[0.0, 0.0, 0.0], [-14.0, 0.5]]
	_place(at, behind)
	_check(
		not ext.effect("lightning_strike").rival_wants(0, "thunder_star", {}),
		"KI spart sich den Blitz gegen die Festung"
	)
	ext.effect("lightning_strike").use(0, "thunder_star", CATALOG.entry("thunder_star"))
	await _tick(1.6, at, behind)
	_check(
		(
			ext.effect("lightning_strike").stats.blocked >= 1
			and is_equal_approx(ext.speed_factor(-1), 1.0)
		),
		"Festung wehrt den Blitz ab"
	)
	await _tick(11.0, at, behind)
	_check(
		game.shield_time <= 0.0 and effect.active.is_empty(), "Festung endet nach 12 s vollständig"
	)
	_check(ext.shield_total(-1) == 6.0, "danach gilt wieder der normale Schild-Ring")
	# KI: bedroht -> Festung.
	_fresh()
	_place(at, near)
	game.opponent_items[0] = "star_fortress"
	_player_use("thunder_star")
	game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	_check(
		game.opponent_items[0].is_empty() and game.opponent_shield_times[0] > 11.0,
		"KI hebt die Festung gegen einen Angriff"
	)
	# Speichern/Fortsetzen.
	_fresh()
	_place(at, near)
	_player_use("star_fortress")
	await _tick(5.0, at, near)
	await _session_roundtrip("Festung")
	game.shield_time = 0.0
	await _tick(STEP, at, near)
	_check(
		absf(game.shield_time - 7.0) < 0.1,
		"Festung läuft nach Fortsetzen mit Restzeit weiter (%.2f)" % game.shield_time
	)


# --- Wirbelwind ----------------------------------------------------------------------------


func _test_whirlwind() -> void:
	var at: float = safe_d
	var effect = ext.effect("whirlwind")
	_fresh()
	var ahead: Array = [[0.0, 0.0, 0.0], [16.0, 0.4]]
	_place(at, ahead)
	game.speed = 18.0
	var before: float = game.opponent_lanes[0]
	_player_use("whirlwind")
	_check(game.item.is_empty() and effect.active.size() == 1, "Wirbel läuft los")
	await _tick(1.6, at, ahead, true)
	var moved: float = absf(game.opponent_lanes[0] - before)
	var wall: float = game._wall_lateral_at(fposmod(game.opponent_distances[0], game.track_length))
	_check(moved > 1.0 and moved < 2.4, "Rivale seitlich versetzt (%.2f m)" % moved)
	_check(
		absf(game.opponent_lanes[0]) <= wall - 1.1,
		"bleibt im sicheren Korridor (%.2f / %.2f)" % [game.opponent_lanes[0], wall]
	)
	_check(game.opponent_grace_times[0] > 0.0, "Wirbel setzt Schonzeit")
	# Nahe der Planke: nie darüber hinaus.
	_fresh()
	var wall_here: float = game._wall_lateral_at(fposmod(at + 16.0, game.track_length))
	var edge: Array = [[0.0, 0.0, 0.0], [16.0, wall_here - 1.3]]
	_place(at, edge)
	game.lane = wall_here - 3.0
	game.player.transform = game.world.reset_transform(fposmod(at, game.track_length), game.lane)
	_player_use("whirlwind")
	await _tick(1.6, at, edge, true)
	_check(
		absf(game.opponent_lanes[0]) <= wall_here - 1.1,
		"an der Planke kein Stoß nach außen (%.2f)" % game.opponent_lanes[0]
	)
	# Sperre an Brücke/Kante/Rampe.
	var unsafe: float = _find_unsafe()
	if unsafe >= 0.0:
		_fresh()
		var on_edge: Array = [[0.0, 0.0, 0.0], [12.0, 0.3]]
		_place(unsafe - 12.0, on_edge)
		var lane_before: float = game.opponent_lanes[0]
		_player_use("whirlwind")
		await _tick(1.2, unsafe - 12.0, on_edge, true)
		_check(
			absf(game.opponent_lanes[0] - lane_before) < 0.05, "kein Versatz an Brücke/Kante/Rampe"
		)
	# Schild.
	_fresh()
	game.opponent_shield_times[0] = 5.0
	_place(at, ahead)
	before = game.opponent_lanes[0]
	_player_use("whirlwind")
	await _tick(1.6, at, ahead, true)
	_check(
		absf(game.opponent_lanes[0] - before) < 0.05 and int(effect.stats.blocked) >= 1,
		"Schild hält den Wirbel ab"
	)
	# Das Kind lenkt den Wirbel.
	_fresh()
	var far: Array = [
		[0.0, 0.0, 0.0], [-90.0, 2.0], [-95.0, -2.0], [-100.0, 1.0], [-105.0, -1.0], [-110.0, 0.0]
	]
	_place(at, far)
	_player_use("whirlwind")
	game.steering = 1.0
	await _tick(0.5, at, far)
	var steered: float = float(effect.active[0].lateral) if not effect.active.is_empty() else 0.0
	game.steering = 0.0
	_check(steered > 1.0, "Kind lenkt den Wirbel (%.2f m)" % steered)
	# KI gegen das Kind.
	_fresh()
	var behind: Array = [[0.0, 0.0, 0.0], [-14.0, 0.2]]
	_place(at, behind)
	var child_before: float = game.lane
	game.opponent_items[0] = "whirlwind"
	game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	_check(game.opponent_items[0].is_empty(), "KI schickt den Wirbel")
	await _tick(1.5, at, behind, true)
	_check(
		absf(game.lane - child_before) > 0.8,
		"Kind wird sanft versetzt (%.2f m)" % absf(game.lane - child_before)
	)
	# Speichern/Fortsetzen.
	_fresh()
	_place(at, ahead)
	_player_use("whirlwind")
	await _tick(0.2, at, ahead)
	await _session_roundtrip("Wirbel")
	_check(
		effect.active.size() == 1 and str(effect.active[0].phase) == "fly",
		"Wirbel läuft nach Fortsetzen weiter"
	)


func _run() -> void:
	var tracks: Array[String] = ["sonnenhafen", "winter_sprint", "jungle_emerald_3600"]
	for id in ALL_ITEMS:
		if CATALOG.has(id):
			items.append(id)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("tracks="):
			tracks.assign(argument.trim_prefix("tracks=").split(","))
		elif argument.begins_with("items="):
			items.assign(argument.trim_prefix("items=").split(","))
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	_test_catalog()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	if is_instance_valid(game.kart_audio):
		game.kart_audio.set_muted(true)
	for track_id in tracks:
		await _start(track_id)
		print(
			(
				"[KartItemExt] %s: sichere Teststelle bei %.0f m von %.0f m"
				% [track_id, safe_d, game.track_length]
			)
		)
		if "thunder_star" in items:
			await _test_thunder()
		if "frost_crystal" in items:
			await _test_frost()
		if "fire_meteor" in items:
			await _test_meteor()
		if "star_fortress" in items:
			await _test_fortress()
		if "whirlwind" in items:
			await _test_whirlwind()
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game.abandoned = true
	game.queue_free()
	for _frame in range(6):
		await process_frame
	if failures.is_empty():
		print("[KartItemExt] PASS: %d checks auf %s" % [checks, ", ".join(tracks)])
		quit(0)
	else:
		print("[KartItemExt] FAIL: %d von %d: %s" % [failures.size(), checks, failures])
		quit(1)
